function tests = test_pkg9_workflow_facades
%TEST_PKG9_WORKFLOW_FACADES Static package-owned workflow contracts.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
testCase.TestData.root = root;
testCase.TestData.workflowDirectory = fullfile( ...
    root,"src","+rkkt","+workflows");
end

function testThreeWorkflowImplementationsArePackageOwned(testCase)
names = ["stageB1","build_stage_b1_water_input_audit"; ...
    "stageB2A","assemble_stage_b_multiday_full_kkt"; ...
    "stageB2B","solve_stage_b2b_recursive_direction"];
for k = 1:size(names,1)
    source = noncomment_source(fileread(fullfile( ...
        testCase.TestData.workflowDirectory,names(k,1)+".m")));
    verifyTrue(testCase,contains(source,names(k,2)));
    verifyFalse(testCase,contains(source,"which("));
    verifyFalse(testCase,contains(source,"ProductionFunctionShadowed"));
    verifyFalse(testCase,contains(source,"main_stage_B_"));
end
end

function testWorkflowOptionsArePassedThroughWithoutStageGuessing(testCase)
for name = ["stageB1","stageB2A","stageB2B"]
    source = noncomment_source(fileread(fullfile( ...
        testCase.TestData.workflowDirectory,name+".m")));
    verifyTrue(testCase,contains(source,"options.ProjectRoot"));
    verifyTrue(testCase,contains(source,"options.RunId"));
    verifyEmpty(testCase,regexp(source, ...
        'isfield\s*\([^\)]*(stage|milestone)',"once"));
    verifyFalse(testCase,contains(source,"rkkt.ipm.solve"));
end
end

function testWorkflowFilesContainRealImplementations(testCase)
for name = ["stageB1","stageB2A","stageB2B"]
    pathValue = fullfile(testCase.TestData.workflowDirectory,name+".m");
    source = noncomment_source(fileread(pathValue));
    verifyGreaterThan(testCase,numel(splitlines(source)),100);
    verifyTrue(testCase,contains(source,"rkkt.artifacts.create_run_context"));
    verifyEmpty(testCase,regexp(source, ...
        '(^|[^A-Za-z0-9_])(inv|pinv|full)\s*\(',"once"));
end
end

function testDeltaRunnerNeverExecutesWorkflowEntrypoints(testCase)
source = noncomment_source(fileread(fullfile( ...
    testCase.TestData.root,"tests","run_PKG_9_delta_tests.m")));
verifyFalse(testCase,contains(source,"rkkt.workflows.stageB"));
verifyFalse(testCase,contains(source,"main_stage_B_"));
end

function testExistingGenericFacadesHaveNoImplicitStageBDispatch(testCase)
root = testCase.TestData.root;
paths = ["src/+rkkt/+data/load.m"; ...
    "src/+rkkt/+indexing/build.m"; ...
    "src/+rkkt/+model/initialize.m"; ...
    "src/+rkkt/+model/linearize.m"; ...
    "src/+rkkt/+solver/assembleFullKKT.m"; ...
    "src/+rkkt/+solver/verifyEquivalence.m"];
for relative = paths.'
    source = noncomment_source(fileread(fullfile( ...
        root,replace(relative,"/",filesep))));
    verifyFalse(testCase,contains(lower(source),"stageb"), ...
        "Implicit Stage-B dispatch leaked into "+relative);
    verifyFalse(testCase,contains(source,"milestone_id"), ...
        "Milestone guessing leaked into "+relative);
end
end

function value = noncomment_source(inputValue)
lines = splitlines(string(inputValue));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end
