function tests = test_stage_b_closure_consistency
%TEST_STAGE_B_CLOSURE_CONSISTENCY Verify terminal-state and evidence wiring.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
testCase.TestData.root = root;
testCase.TestData.sourceRoot = fullfile(root,"src");
end

function testTerminalIndexSyncIsOutsideNumericalCatch(testCase)
files = [ ...
    "+rkkt/+workflows/stageB2C.m"
    "+rkkt/+workflows/stageB2C30DayExperiment.m"];
for relative = files.'
    source = code_source(fullfile(testCase.TestData.sourceRoot, ...
        replace(relative,"/",filesep)));
    catchPosition = strfind(source,"catch cause");
    finalizePosition = strfind(source, ...
        "rkkt.artifacts.finalize_run_manifest(");
    indexPosition = strfind(source,"rkkt.artifacts.update_run_index(");
    verifyNumElements(testCase,catchPosition,1,relative);
    verifyNumElements(testCase,finalizePosition,1,relative);
    verifyNumElements(testCase,indexPosition,1,relative);
    verifyGreaterThan(testCase,finalizePosition,catchPosition,relative);
    verifyGreaterThan(testCase,indexPosition,finalizePosition,relative);
end
end

function testAcceptanceConsumesFiniteDifferenceEvidence(testCase)
source = code_source(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","+workflows","stageB2C.m"));
suitePosition = strfind(source, ...
    "suites=run_test_and_static_evidence(context,root)");
acceptancePosition = strfind(source,"acceptance=make_acceptance(");
suitePosition = suitePosition(suitePosition<acceptancePosition(1));
verifyNumElements(testCase,suitePosition,1);
verifyNumElements(testCase,acceptancePosition,1);
verifyLessThan(testCase,suitePosition,acceptancePosition);
verifyTrue(testCase,contains(source, ...
    "derivativePass=suites.derivative_finite_difference_pass"));
verifyTrue(testCase,contains(source, ...
    "test_stage_b_daily_hydro_water/testAnalyticGradientMatchesIndependentCentralDifference"));
verifyTrue(testCase,contains(source, ...
    "test_stage_b_daily_hydro_water/testAnalyticHessianMatchesIndependentGradientDifference"));
verifyTrue(testCase,contains(source, ...
    "test_stage_b2c_formal_ipm/testWaterStationarityFiniteDifferenceMatchesCurrentHessian"));
end

function value = code_source(pathValue)
lines = splitlines(string(fileread(pathValue)));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end
