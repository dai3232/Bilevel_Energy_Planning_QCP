function tests = test_pkg9_workflow_facades
%TEST_PKG9_WORKFLOW_FACADES Static-only workflow delegation contracts.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
testCase.TestData.root = root;
testCase.TestData.workflowDirectory = fullfile( ...
    root,"src","+rkkt","+workflows");
end

function testThreeWorkflowFacadesTargetExactStableEntrypoints(testCase)
names = ["stageB1","main_stage_B_1"; ...
    "stageB2A","main_stage_B_2A"; ...
    "stageB2B","main_stage_B_2B"];
for k = 1:size(names,1)
    source = noncomment_source(fileread(fullfile( ...
        testCase.TestData.workflowDirectory,names(k,1)+".m")));
    verifyTrue(testCase,contains(source,names(k,2)));
    verifyTrue(testCase,contains(source,"which("));
    verifyTrue(testCase,contains(source,"ProductionFunctionShadowed"));
    verifyTrue(testCase,contains(source,"same_path("));
    for other = setdiff(names(:,2),names(k,2)).'
        verifyFalse(testCase,contains(source,other));
    end
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

function testWorkflowFacadesRemainThinSingleDelegates(testCase)
targets = ["stageB1","main_stage_B_1"; ...
    "stageB2A","main_stage_B_2A"; ...
    "stageB2B","main_stage_B_2B"];
for k = 1:size(targets,1)
    pathValue = fullfile(testCase.TestData.workflowDirectory, ...
        targets(k,1)+".m");
    lines = splitlines(string(fileread(pathValue)));
    verifyLessThanOrEqual(testCase,numel(lines),90);
    source = noncomment_source(strjoin(lines,newline));
    callPattern = "(^|[^A-Za-z0-9_])"+targets(k,2)+"\s*\(";
    verifyEqual(testCase,numel(regexp(source,callPattern)),1, ...
        "Workflow must delegate exactly once: "+targets(k,1));
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
