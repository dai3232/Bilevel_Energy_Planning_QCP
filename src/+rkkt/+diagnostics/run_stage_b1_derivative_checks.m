function [checks,details] = run_stage_b1_derivative_checks(data)
%RUN_STAGE_B1_DERIVATIVE_CHECKS Deterministic independent B-1 checks.
%   Four deterministic points are checked for every day 14:20 and plant
%   1:4. Numerical references use a local scalar loop implementation and
%   central differences; no random values or production analytic formulas
%   are used to construct the numerical derivative references.

validate_input_data(data);

days = (14:20).';
hydroIds = (1:4).';
pointIds = ["internal";"nonuniform";"near_zero";"near_pmax"];
sampleCount = numel(days)*numel(hydroIds)*numel(pointIds);
threshold = 1e-7;
valueThreshold = 64*eps;

day = zeros(sampleCount,1);
hydro_id = zeros(sampleCount,1);
test_point_id = strings(sampleCount,1);
finite_difference_step_min = zeros(sampleCount,1);
finite_difference_step_max = zeros(sampleCount,1);
analytic_value = zeros(sampleCount,1);
independently_rebuilt_value = zeros(sampleCount,1);
gradient_max_absolute_error = zeros(sampleCount,1);
gradient_relative_error = zeros(sampleCount,1);
hessian_max_absolute_error = zeros(sampleCount,1);
hessian_relative_error = zeros(sampleCount,1);
upper_sign_pass = false(sampleCount,1);
lower_sign_pass = false(sampleCount,1);
cross_hour_zero_pass = false(sampleCount,1);
cross_asset_zero_pass = false(sampleCount,1);
threshold_column = repmat(threshold,sampleCount,1);
status = repmat("FAIL",sampleCount,1);
value_relative_error = zeros(sampleCount,1);
gradient_step_min = zeros(sampleCount,1);
gradient_step_max = zeros(sampleCount,1);
hessian_step_min = zeros(sampleCount,1);
hessian_step_max = zeros(sampleCount,1);
numeric_hessian_offdiagonal_max_abs = zeros(sampleCount,1);
cross_asset_mixed_max_abs = zeros(sampleCount,1);

powerMW = zeros(24,sampleCount);
analyticGradient = zeros(24,sampleCount);
numericGradient = zeros(24,sampleCount);
analyticHessian = zeros(24,24,sampleCount);
numericHessian = zeros(24,24,sampleCount);
gradientSteps = zeros(24,sampleCount);
hessianSteps = zeros(24,sampleCount);
productionHessianNnz = zeros(sampleCount,1);

sample = 0;
for dayValue = reshape(days,1,[])
    for hydroId = reshape(hydroIds,1,[])
        maximumMW = double(data.base.hydro.maxOutputMW(hydroId));
        a = double(data.base.hydro.waterA(hydroId));
        b = double(data.base.hydro.waterB(hydroId));
        c = double(data.base.hydro.waterC(hydroId));
        points = deterministic_points(maximumMW);
        for pointIndex = 1:numel(pointIds)
            sample = sample + 1;
            point = points(:,pointIndex);
            analytic = rkkt.model.evaluate_stage_b_daily_hydro_water(point,a,b,c);
            rebuilt = independent_scalar_value(point,a,b,c);
            gradStep = centered_steps(point,maximumMW,1e-3,0.25);
            numericGrad = independent_numeric_gradient( ...
                point,a,b,c,maximumMW,gradStep);
            % Use a larger outer step so the Hessian response is not lost
            % in cancellation near either physical bound.  The boundary
            % fraction still keeps both centered points in [0,Pmax].
            hessStep = centered_steps(point,maximumMW,8e-3,0.48);
            numericHess = independent_numeric_hessian( ...
                point,a,b,c,maximumMW,hessStep);
            analyticHess = full(analytic.hessian);

            gradAbs = max(abs(analytic.gradient-numericGrad));
            gradRel = relative_max_error(analytic.gradient,numericGrad);
            hessAbs = max(abs(analyticHess-numericHess),[],"all");
            hessRel = relative_max_error(analyticHess,numericHess);
            valueRel = abs(analytic.value-rebuilt)/ ...
                max([1,abs(analytic.value),abs(rebuilt)]);
            analyticOffDiagonal = analyticHess- ...
                diag(diag(analyticHess));
            numericOffDiagonal = numericHess-diag(diag(numericHess));
            upperPass = analytic.upper.water_coefficient==1 && ...
                analytic.upper.value_without_bound==analytic.value && ...
                isequal(analytic.upper.gradient,analytic.gradient) && ...
                isequal(analytic.upper.hessian,analytic.hessian);
            lowerPass = analytic.lower.water_coefficient==-1 && ...
                analytic.lower.value_without_bound==-analytic.value && ...
                isequal(analytic.lower.gradient,-analytic.gradient) && ...
                isequal(analytic.lower.hessian,-analytic.hessian);
            crossHourPass = nnz(analyticOffDiagonal)==0;
            [crossAssetPass,crossAssetMixedMax] = ...
                cross_asset_joint_response_is_zero( ...
                data,hydroId,point,a,b,c,maximumMW);

            day(sample) = dayValue;
            hydro_id(sample) = hydroId;
            test_point_id(sample) = pointIds(pointIndex);
            finite_difference_step_min(sample) = ...
                min([gradStep;hessStep]);
            finite_difference_step_max(sample) = ...
                max([gradStep;hessStep]);
            analytic_value(sample) = analytic.value;
            independently_rebuilt_value(sample) = rebuilt;
            gradient_max_absolute_error(sample) = gradAbs;
            gradient_relative_error(sample) = gradRel;
            hessian_max_absolute_error(sample) = hessAbs;
            hessian_relative_error(sample) = hessRel;
            upper_sign_pass(sample) = upperPass;
            lower_sign_pass(sample) = lowerPass;
            cross_hour_zero_pass(sample) = crossHourPass;
            cross_asset_zero_pass(sample) = crossAssetPass;
            value_relative_error(sample) = valueRel;
            gradient_step_min(sample) = min(gradStep);
            gradient_step_max(sample) = max(gradStep);
            hessian_step_min(sample) = min(hessStep);
            hessian_step_max(sample) = max(hessStep);
            numeric_hessian_offdiagonal_max_abs(sample) = ...
                max(abs(numericOffDiagonal),[],"all");
            cross_asset_mixed_max_abs(sample) = crossAssetMixedMax;
            if valueRel<=valueThreshold && gradRel<=threshold && ...
                    hessRel<=threshold && upperPass && lowerPass && ...
                    crossHourPass && crossAssetPass
                status(sample) = "PASS";
            end

            powerMW(:,sample) = point;
            analyticGradient(:,sample) = analytic.gradient;
            numericGradient(:,sample) = numericGrad;
            analyticHessian(:,:,sample) = analyticHess;
            numericHessian(:,:,sample) = numericHess;
            gradientSteps(:,sample) = gradStep;
            hessianSteps(:,sample) = hessStep;
            productionHessianNnz(sample) = nnz(analytic.hessian);
        end
    end
end

checks = table(day,hydro_id,test_point_id, ...
    finite_difference_step_min,finite_difference_step_max, ...
    analytic_value,independently_rebuilt_value, ...
    gradient_max_absolute_error,gradient_relative_error, ...
    hessian_max_absolute_error,hessian_relative_error, ...
    upper_sign_pass,lower_sign_pass,cross_hour_zero_pass, ...
    cross_asset_zero_pass,threshold_column,status, ...
    value_relative_error,gradient_step_min,gradient_step_max, ...
    hessian_step_min,hessian_step_max, ...
    numeric_hessian_offdiagonal_max_abs,cross_asset_mixed_max_abs, ...
    'VariableNames',cellstr([ ...
    "day","hydro_id","test_point_id", ...
    "finite_difference_step_min","finite_difference_step_max", ...
    "analytic_value","independently_rebuilt_value", ...
    "gradient_max_absolute_error","gradient_relative_error", ...
    "hessian_max_absolute_error","hessian_relative_error", ...
    "upper_sign_pass","lower_sign_pass","cross_hour_zero_pass", ...
    "cross_asset_zero_pass","threshold","status", ...
    "value_relative_error","gradient_step_min","gradient_step_max", ...
    "hessian_step_min","hessian_step_max", ...
    "numeric_hessian_offdiagonal_max_abs", ...
    "cross_asset_mixed_max_abs"]));

details = struct();
details.schema_version = "stage-B1-derivative-check-v1.0";
details.days = days;
details.hydro_ids = hydroIds;
details.test_point_ids = pointIds;
details.threshold = threshold;
details.value_rebuild_threshold = valueThreshold;
details.power_mw = powerMW;
details.analytic_gradient = analyticGradient;
details.numeric_gradient = numericGradient;
details.analytic_hessian = analyticHessian;
details.numeric_hessian = numericHessian;
details.gradient_steps = gradientSteps;
details.hessian_steps = hessianSteps;
details.production_hessian_nnz = productionHessianNnz;
details.cross_asset_mixed_max_abs = cross_asset_mixed_max_abs;
details.checks = checks;
details.summary = struct( ...
    "sample_count",height(checks), ...
    "passed_count",sum(checks.status=="PASS"), ...
    "failed_count",sum(checks.status~="PASS"), ...
    "maximum_gradient_relative_error", ...
        max(checks.gradient_relative_error), ...
    "maximum_hessian_relative_error", ...
        max(checks.hessian_relative_error), ...
    "maximum_value_relative_error", ...
        max(checks.value_relative_error), ...
    "all_pass",all(checks.status=="PASS"));

assert(height(checks)==112, ...
    "stageB1:derivatives:UnexpectedSampleCount", ...
    "Derivative diagnostics must contain exactly 112 samples.");
end

function validate_input_data(data)
audit = rkkt.diagnostics.build_stage_b1_water_input_audit(data,"B1_DERIVATIVE_CHECK");
if height(audit)~=28 || any(audit.status~="PASS")
    error("stageB1:derivatives:InvalidWaterInput", ...
        "The authoritative 28-row water input audit must pass first.");
end
end

function points = deterministic_points(maximumMW)
hourFraction = (0:23).'/23;
points = zeros(24,4);
points(:,1) = 0.5*maximumMW;
points(:,2) = maximumMW.*(0.15 + 0.70.*hourFraction);
points(:,3) = maximumMW.*(0.010 + 0.005.*hourFraction);
points(:,4) = maximumMW.*(0.990 - 0.005.*hourFraction);
assert(all(points>=0 & points<=maximumMW,"all"), ...
    "stageB1:derivatives:TestPointOutOfRange", ...
    "Every deterministic test point must lie in [0,Pmax].");
end

function steps = centered_steps(point,maximumMW,relativeScale,boundaryFraction)
nominal = relativeScale*max(1,maximumMW);
distance = min(point,maximumMW-point);
steps = min(repmat(nominal,24,1),boundaryFraction.*distance);
if any(~isfinite(steps) | steps<=0)
    error("stageB1:derivatives:InvalidFiniteDifferenceStep", ...
        "Centered finite-difference steps must be finite and positive.");
end
end

function value = independent_scalar_value(powerMW,a,b,c)
value = 0;
correction = 0;
for hour = 1:24
    hourlyPower = powerMW(hour);
    term = a*hourlyPower*hourlyPower + b*hourlyPower + c;
    adjusted = term-correction;
    updated = value+adjusted;
    correction = (updated-value)-adjusted;
    value = updated;
end
end

function gradient = independent_numeric_gradient( ...
        point,a,b,c,maximumMW,steps)
gradient = zeros(24,1);
for variable = 1:24
    step = steps(variable);
    plus = point;
    minus = point;
    plus(variable) = plus(variable)+step;
    minus(variable) = minus(variable)-step;
    assert(plus(variable)<=maximumMW && minus(variable)>=0, ...
        "stageB1:derivatives:CenteredStepOutOfRange", ...
        "Centered gradient perturbations must stay in [0,Pmax].");
    gradient(variable) = ( ...
        independent_scalar_value(plus,a,b,c)- ...
        independent_scalar_value(minus,a,b,c))/(2*step);
end
end

function hessian = independent_numeric_hessian( ...
        point,a,b,c,maximumMW,outerSteps)
hessian = zeros(24,24);
for variable = 1:24
    step = outerSteps(variable);
    plus = point;
    minus = point;
    plus(variable) = plus(variable)+step;
    minus(variable) = minus(variable)-step;
    assert(plus(variable)<=maximumMW && minus(variable)>=0, ...
        "stageB1:derivatives:CenteredStepOutOfRange", ...
        "Centered Hessian perturbations must stay in [0,Pmax].");
    % A slightly wider inner centered difference provides enough signal
    % for differentiating the independently rebuilt numerical gradient,
    % while the boundary fraction keeps every perturbation physical.
    plusSteps = centered_steps(plus,maximumMW,2e-3,0.45);
    minusSteps = centered_steps(minus,maximumMW,2e-3,0.45);
    plusGradient = independent_numeric_gradient( ...
        plus,a,b,c,maximumMW,plusSteps);
    minusGradient = independent_numeric_gradient( ...
        minus,a,b,c,maximumMW,minusSteps);
    hessian(:,variable) = (plusGradient-minusGradient)/(2*step);
end
end

function errorValue = relative_max_error(expected,actual)
maximumExpected = max(abs(expected),[],"all");
maximumActual = max(abs(actual),[],"all");
denominator = max([maximumExpected,maximumActual,realmin]);
errorValue = max(abs(expected-actual),[],"all")/denominator;
end

function [pass,mixedMaximum] = cross_asset_joint_response_is_zero( ...
        data,hydroId,point,a,b,c,maximumMW)
% Evaluate mixed derivatives of a genuinely two-asset scalar response.
% The joint scalar is assembled from two independent daily water terms;
% every target/other-hour pair is checked with a centered mixed difference.
otherId = mod(hydroId,4)+1;
otherMaximum = double(data.base.hydro.maxOutputMW(otherId));
otherA = double(data.base.hydro.waterA(otherId));
otherB = double(data.base.hydro.waterB(otherId));
otherC = double(data.base.hydro.waterC(otherId));
otherPoint = 0.37*otherMaximum*ones(24,1);
targetSteps = centered_steps(point,maximumMW,2e-3,0.20);
otherSteps = centered_steps(otherPoint,otherMaximum,2e-3,0.20);
mixedMaximum = 0;
for targetHour = 1:24
    for otherHour = 1:24
        targetPlus = point;
        targetMinus = point;
        otherPlus = otherPoint;
        otherMinus = otherPoint;
        targetPlus(targetHour) = targetPlus(targetHour)+targetSteps(targetHour);
        targetMinus(targetHour) = targetMinus(targetHour)-targetSteps(targetHour);
        otherPlus(otherHour) = otherPlus(otherHour)+otherSteps(otherHour);
        otherMinus(otherHour) = otherMinus(otherHour)-otherSteps(otherHour);
        fPP = independent_joint_scalar_value(targetPlus,otherPlus, ...
            a,b,c,otherA,otherB,otherC);
        fPM = independent_joint_scalar_value(targetPlus,otherMinus, ...
            a,b,c,otherA,otherB,otherC);
        fMP = independent_joint_scalar_value(targetMinus,otherPlus, ...
            a,b,c,otherA,otherB,otherC);
        fMM = independent_joint_scalar_value(targetMinus,otherMinus, ...
            a,b,c,otherA,otherB,otherC);
        mixed = (fPP-fPM-fMP+fMM)/( ...
            4*targetSteps(targetHour)*otherSteps(otherHour));
        mixedMaximum = max(mixedMaximum,abs(mixed));
    end
end
pass = mixedMaximum<=1e-7;
end

function value = independent_joint_scalar_value( ...
        target,other,a,b,c,otherA,otherB,otherC)
value = independent_scalar_value(target,a,b,c) + ...
    independent_scalar_value(other,otherA,otherB,otherC);
end
