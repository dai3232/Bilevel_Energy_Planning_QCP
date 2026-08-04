function tests = test_stage_b_daily_hydro_water
%TEST_STAGE_B_DAILY_HYDRO_WATER Verify value and analytic derivatives.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
testCase.TestData.root = root;
testCase.TestData.data = load_project_data(root);
testCase.TestData.threshold = 1e-7;
end

function testWaterValueFormula(testCase)
data = testCase.TestData.data;
for hydro = 1:4
    [a,b,c,pmax] = coefficients(data,hydro);
    points = deterministic_points(pmax);
    for point = 1:size(points,2)
        power = points(:,point);
        actual = evaluate_stage_b_daily_hydro_water(power,a,b,c);
        independentlyRebuilt = sum(a.*power.^2+b.*power+c);
        tolerance = 64*eps(max(1,abs(independentlyRebuilt)));
        verifyEqual(testCase,actual.value,independentlyRebuilt, ...
            "AbsTol",tolerance);
    end
end
end

function testConstantTermAccumulatesTwentyFourTimes(testCase)
data = testCase.TestData.data;
for hydro = 1:4
    [a,b,c] = coefficients(data,hydro);
    actual = evaluate_stage_b_daily_hydro_water(zeros(24,1),a,b,c);
    expected = 24*c;
    verifyEqual(testCase,actual.value,expected, ...
        "AbsTol",64*eps(max(1,abs(expected))));
end
end

function testAnalyticGradientMatchesIndependentCentralDifference(testCase)
data = testCase.TestData.data;
threshold = testCase.TestData.threshold;
for hydro = 1:4
    [a,b,c,pmax] = coefficients(data,hydro);
    points = deterministic_points(pmax);
    for point = 1:size(points,2)
        power = points(:,point);
        analytic = evaluate_stage_b_daily_hydro_water(power,a,b,c);
        numeric = value_central_difference(power,a,b,c,pmax);
        errorValue = relative_error(analytic.gradient,numeric);
        verifyLessThanOrEqual(testCase,errorValue,threshold, ...
            compose("hydro=%d point=%d gradient error=%.17g", ...
            hydro,point,errorValue));
    end
end
end

function testAnalyticHessianMatchesIndependentGradientDifference(testCase)
data = testCase.TestData.data;
threshold = testCase.TestData.threshold;
for hydro = 1:4
    [a,b,c,pmax] = coefficients(data,hydro);
    points = deterministic_points(pmax);
    for point = 1:size(points,2)
        power = points(:,point);
        analytic = evaluate_stage_b_daily_hydro_water(power,a,b,c);
        numeric = gradient_central_difference(power,a,b,c,pmax);
        errorValue = relative_error(full(analytic.hessian),numeric);
        verifyLessThanOrEqual(testCase,errorValue,threshold, ...
            compose("hydro=%d point=%d Hessian error=%.17g", ...
            hydro,point,errorValue));
    end
end
end

function testUpperAndLowerDerivativeSigns(testCase)
data = testCase.TestData.data;
for hydro = 1:4
    [a,b,c,pmax] = coefficients(data,hydro);
    power = deterministic_points(pmax);
    result = evaluate_stage_b_daily_hydro_water(power(:,2),a,b,c);
    verifyEqual(testCase,result.upper.gradient,result.gradient,"AbsTol",0);
    verifyEqual(testCase,result.upper.hessian,result.hessian,"AbsTol",0);
    verifyEqual(testCase,result.lower.gradient,-result.gradient,"AbsTol",0);
    verifyEqual(testCase,result.lower.hessian,-result.hessian,"AbsTol",0);
end
end

function testHessianIsSparseDiagonalWithExactCrossHourZeros(testCase)
data = testCase.TestData.data;
for hydro = 1:4
    [a,b,c,pmax] = coefficients(data,hydro);
    power = deterministic_points(pmax);
    result = evaluate_stage_b_daily_hydro_water(power(:,1),a,b,c);
    verifyTrue(testCase,issparse(result.hessian));
    verifySize(testCase,result.hessian,[24,24]);
    diagonal = diag(result.hessian);
    offDiagonal = result.hessian-spdiags(diagonal,0,24,24);
    verifyEqual(testCase,nnz(offDiagonal),0);
    verifyEqual(testCase,full(diagonal),repmat(2*a,24,1),"AbsTol",0);
end
end

function testCrossDayAndAssetEvaluationsAreIndependent(testCase)
data = testCase.TestData.data;
[audit,details] = run_stage_b1_derivative_checks(data);
required = ["day","hydro_id","test_point_id","cross_hour_zero_pass", ...
    "cross_asset_zero_pass","status"];
verifyTrue(testCase,all(ismember(required, ...
    string(audit.Properties.VariableNames))));
verifyEqual(testCase,height(audit),7*4*4);
verifyTrue(testCase,all(audit.cross_hour_zero_pass));
verifyTrue(testCase,all(audit.cross_asset_zero_pass));
verifyEqual(testCase,string(audit.status),repmat("PASS",height(audit),1));
verifyFalse(testCase,isempty(details));

index = build_canonical_index_framework(data,14:20,1:24,[], ...
    "B1_HYDRO_INDEX_TEST");
variables = index.variable_index;
hydroRows = variables(string(variables.variable_name)=="PH" & ...
    string(variables.asset_type)=="hydro",:);
verifyEqual(testCase,height(hydroRows),7*24*4);
for day = 14:20
    for hydro = 1:4
        rows = hydroRows(hydroRows.day==day & ...
            hydroRows.asset_id==hydro,:);
        verifyEqual(testCase,height(rows),24);
        verifyEqual(testCase,rows.hour,(1:24).');
        verifyEqual(testCase,numel(unique(rows.global_index_start)),24);
    end
end
end

function testInputShapeFiniteAndRealGuards(testCase)
data = testCase.TestData.data;
[a,b,c,pmax] = coefficients(data,1);
valid = deterministic_points(pmax);
valid = valid(:,1);
invalid = {valid.',valid(1:23),[valid,valid], ...
    replace_element(valid,1,NaN),replace_element(valid,2,Inf), ...
    complex(valid,ones(24,1))};
for k = 1:numel(invalid)
    verify_rejected(testCase,@()evaluate_stage_b_daily_hydro_water( ...
        invalid{k},a,b,c));
end
end

function testDeterministicRepeatIsBitwiseIdentical(testCase)
data = testCase.TestData.data;
[a,b,c,pmax] = coefficients(data,3);
points = deterministic_points(pmax);
first = evaluate_stage_b_daily_hydro_water(points(:,2),a,b,c);
second = evaluate_stage_b_daily_hydro_water(points(:,2),a,b,c);
verifyTrue(testCase,isequaln(first,second));
[firstAudit,firstDetails] = run_stage_b1_derivative_checks(data);
[secondAudit,secondDetails] = run_stage_b1_derivative_checks(data);
verifyTrue(testCase,isequaln(firstAudit,secondAudit));
verifyTrue(testCase,isequaln(firstDetails,secondDetails));
end

function [a,b,c,pmax] = coefficients(data,hydro)
a = data.base.hydro.waterA(hydro);
b = data.base.hydro.waterB(hydro);
c = data.base.hydro.waterC(hydro);
pmax = data.base.hydro.maxOutputMW(hydro);
end

function points = deterministic_points(pmax)
hour = (0:23).';
internal = pmax.*(0.15+0.70.*hour./23);
nonuniform = pmax.*(0.10+0.80.*mod(7.*hour,24)./23);
nearZero = pmax.*(0.010+0.005.*hour./23);
nearMaximum = pmax.*(0.990-0.005.*hour./23);
points = [internal,nonuniform,nearZero,nearMaximum];
assert(all(points>=0 & points<=pmax,"all"));
end

function gradient = value_central_difference(power,a,b,c,pmax)
gradient = zeros(24,1);
steps = eps^(1/3).*max(1,pmax).*ones(24,1);
for hour = 1:24
    plus = power;
    minus = power;
    plus(hour) = plus(hour)+steps(hour);
    minus(hour) = minus(hour)-steps(hour);
    plusValue = independent_scalar_value(plus,a,b,c);
    minusValue = independent_scalar_value(minus,a,b,c);
    gradient(hour) = (plusValue-minusValue)/(2*steps(hour));
end
end

function hessian = gradient_central_difference(power,a,b,c,pmax)
hessian = zeros(24,24);
steps = 5e-3.*max(1,pmax).*ones(24,1);
innerSteps = 1e-3.*max(1,pmax).*ones(24,1);
for hour = 1:24
    plus = power;
    minus = power;
    plus(hour) = plus(hour)+steps(hour);
    minus(hour) = minus(hour)-steps(hour);
    plusGradient = independent_numeric_gradient(plus,a,b,c,innerSteps);
    minusGradient = independent_numeric_gradient(minus,a,b,c,innerSteps);
    hessian(:,hour) = (plusGradient-minusGradient)/(2*steps(hour));
end
end

function gradient = independent_numeric_gradient(power,a,b,c,steps)
gradient = zeros(24,1);
for hour = 1:24
    plus = power;
    minus = power;
    plus(hour) = plus(hour)+steps(hour);
    minus(hour) = minus(hour)-steps(hour);
    gradient(hour) = (independent_scalar_value(plus,a,b,c)- ...
        independent_scalar_value(minus,a,b,c))/(2*steps(hour));
end
end

function value = independent_scalar_value(power,a,b,c)
value = 0;
for hour = 1:24
    value = value+a*power(hour)*power(hour)+b*power(hour)+c;
end
end

function value = relative_error(left,right)
denominator = max([norm(left,"fro"),norm(right,"fro"),eps]);
value = norm(left-right,"fro")/denominator;
end

function value = replace_element(value,index,replacement)
value(index) = replacement;
end

function verify_rejected(testCase,operation)
thrown = false;
identifier = "";
try
    operation();
catch cause
    thrown = true;
    identifier = string(cause.identifier);
end
verifyTrue(testCase,thrown,"Invalid power input was accepted.");
verifyNotEmpty(testCase,identifier, ...
    "Invalid power input must raise an identified error.");
end
