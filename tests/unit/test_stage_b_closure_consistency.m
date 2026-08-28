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
source = code_source(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","+workflows","stageB2CConfigured.m"));
catchPosition = strfind(source,"catch cause");
finalizePosition = strfind(source, ...
    "rkkt.artifacts.finalize_run_manifest(");
indexPosition = strfind(source,"rkkt.artifacts.update_run_index(");
verifyNumElements(testCase,catchPosition,1);
verifyNumElements(testCase,finalizePosition,1);
verifyNumElements(testCase,indexPosition,1);
verifyGreaterThan(testCase,finalizePosition,catchPosition);
verifyGreaterThan(testCase,indexPosition,finalizePosition);
end

function testPresetWrappersOnlyDelegateToCommonWorkflow(testCase)
files = ["stageB2C.m";"stageB2C30DayExperiment.m"; ...
    "stageB2C365DaySerialExperiment.m"];
for file = files.'
    source = code_source(fullfile(testCase.TestData.sourceRoot, ...
        "+rkkt","+workflows",file));
    verifyNumElements(testCase, ...
        strfind(source,"rkkt.workflows.stageB2CConfigured("),1,file);
    verifyFalse(testCase,contains(source,"catch cause"),file);
    verifyFalse(testCase,contains(source, ...
        "build_stage_b2c_scaled_objective_linearization"),file);
end
end

function value = code_source(pathValue)
lines = splitlines(string(fileread(pathValue)));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end
