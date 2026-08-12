function tests = test_package_hard_cut
%TEST_PACKAGE_HARD_CUT Verify the package-only production architecture.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(root,"src");
addpath(sourceRoot);
data = rkkt.data.load(root);
config = rkkt.model.load_stage_a4_3_configuration(root);
index = rkkt.indexing.build(data,config);
state = rkkt.model.initialize(data,index,config);
testCase.TestData.root = root;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.data = data;
testCase.TestData.config = config;
testCase.TestData.index = index;
testCase.TestData.state = state;
testCase.TestData.pathCleanup = onCleanup(@()rmpath(sourceRoot));
end

function testSingleClickEntryIsTheOnlyTopLevelProductionChain(testCase)
source = code_source(fullfile(testCase.TestData.root,"RUN_PROJECT.m"));
verifyTrue(testCase,contains(source, ...
    'addpath(fullfile(projectRoot,"src"))'));
verifyEqual(testCase,count(source,"projectResult = rkkt.run()"),1);
verifyFalse(testCase,contains(source,"main_stage_"));
verifyEmpty(testCase,regexp(source,'(?m)^\s*(try|catch)\b',"once"));
end

function testPipelineUsesExplicitObjectsInOrder(testCase)
source = code_source(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","run.m"));
calls = ["rkkt.workflows.stageA4("; ...
    "rkkt.workflows.completePackageClosureA4(numerical)"];
positions = zeros(numel(calls),1);
for k = 1:numel(calls)
    hit = strfind(source,calls(k));
    verifyNumElements(testCase,hit,1);
    positions(k) = hit;
end
verifyGreaterThan(testCase,diff(positions),zeros(numel(calls)-1,1));
verifyEmpty(testCase,regexp(source,'(?m)^\s*(try|catch)\b',"once"));

workflow = code_source(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","+workflows","stageA4.m"));
workflowCalls = ["rkkt.data.load(projectRoot)"; ...
    "rkkt.indexing.build("; ...
    "rkkt.ipm.run_stage_a4_full_ipm("];
workflowPositions = zeros(numel(workflowCalls),1);
for k = 1:numel(workflowCalls)
    hit = strfind(workflow,workflowCalls(k));
    verifyNumElements(testCase,hit,1);
    workflowPositions(k) = hit;
end
verifyGreaterThan(testCase,diff(workflowPositions), ...
    zeros(numel(workflowCalls)-1,1));
end

function testProductionAlgorithmsLiveOnlyUnderRkkt(testCase)
oldDirectories = ["data";"indexing";"model";"solver"; ...
    "artifacts";"diagnostics";"reporting";"testing"; ...
    "ipm";"linearization"];
for name = oldDirectories.'
    verifyFalse(testCase,isfolder(fullfile( ...
        testCase.TestData.sourceRoot,name)));
end
required = [ ...
    "+data/load_project_data.m"
    "+indexing/build_stage_a_multiday_index.m"
    "+model/build_stage_a_multiday_linearization.m"
    "+solver/solve_stage_a_multiday_recursive_direction.m"
    "+ipm/execute_stage_a4_iteration.m"];
for relative = required.'
    verifyTrue(testCase,isfile(fullfile(testCase.TestData.sourceRoot, ...
        "+rkkt",replace(relative,"/",filesep))));
end
verifyFalse(testCase,isfile(fullfile(testCase.TestData.root, ...
    "main_stage_B_1.m")));
verifyFalse(testCase,isfile(fullfile(testCase.TestData.root, ...
    "main_stage_B_2A.m")));
verifyFalse(testCase,isfile(fullfile(testCase.TestData.root, ...
    "main_stage_B_2B.m")));
verifyFalse(testCase,isfile(fullfile(testCase.TestData.root, ...
    "main_stage_A4_3.m")));
verifyTrue(testCase,isfile(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","+workflows","stageA4.m")));
end

function testPackageContainsNoCompatibilityDispatchOrClasses(testCase)
files = dir(fullfile(testCase.TestData.sourceRoot,"+rkkt","**","*.m"));
for k = 1:numel(files)
    pathValue = fullfile(files(k).folder,files(k).name);
    source = code_source(pathValue);
    forbidden = ["classdef";"which(";"str2func("; ...
        "production_location";"ProductionFunctionShadowed"; ...
        "addpath(""-begin""";"rmpath("];
    for token = forbidden.'
        verifyFalse(testCase,contains(source,token), ...
            pathValue+" contains forbidden compatibility token "+token);
    end
end
end

function testPublicPipelineFunctionsHaveNoFallbackBranch(testCase)
files = [ ...
    "+rkkt/run.m"
    "+rkkt/+data/load.m"
    "+rkkt/+indexing/build.m"
    "+rkkt/+model/initialize.m"
    "+rkkt/+model/linearize.m"
    "+rkkt/+ipm/solve.m"
    "+rkkt/+ipm/step.m"];
for relative = files.'
    source = code_source(fullfile(testCase.TestData.sourceRoot, ...
        replace(relative,"/",filesep)));
    verifyEmpty(testCase,regexp(source, ...
        '(?m)^\s*(try|catch)\b|\b(which|str2func|addpath|rmpath)\s*\(', ...
        "once"),relative);
end
end

function testPackageMetadataDeclaresHardCut(testCase)
value = rkkt.info();
verifyEqual(testCase,value.package_version,"1.0.0");
verifyEqual(testCase,value.pkg_stage,"PACKAGE-HARD-CUT");
verifyTrue(testCase,value.production_callers_migrated);
verifyTrue(testCase,value.production_algorithm_migrated);
verifyFalse(testCase,value.legacy_source_directories_present);
verifyFalse(testCase,value.compatibility_dispatch_present);
verifyFalse(testCase,value.fallback_dispatch_present);
verifyEqual(testCase,value.class_count,0);
verifyEqual(testCase,value.single_click_entry,"RUN_PROJECT.m");
verifyFalse(testCase,value.single_click_executes_full_ipm);
verifyFalse(testCase,value.single_click_creates_formal_run);
verifyEqual(testCase,value.single_click_stage,"stage_B");
verifyFalse(testCase,value.single_click_is_current_stage_entry);
verifyEqual(testCase,value.single_click_block_reason, ...
    "current_stage_is_stage_D1");
verifyTrue(testCase,value.immutable_run_history);
verifyEqual(testCase,value.compact_run_index,"runs/运行索引.csv");
end

function testRunIndexHandlesRunningNullAndRepeat(testCase)
root = testCase.TestData.root;
temporaryRoot = string(tempname(tempdir));
mkdir(temporaryRoot);
cleanup = onCleanup(@()remove_tree(temporaryRoot));
runsRoot = fullfile(temporaryRoot,"runs");
mkdir(runsRoot);
configPath = fullfile(temporaryRoot,"effective_config.yaml");
copyfile(fullfile(root,"config","stage_A4_3.yaml"),configPath);

runRoot = fullfile(runsRoot,"R1");
mkdir(runRoot);
context = struct( ...
    "project_root",char(root), ...
    "runs_root",char(runsRoot), ...
    "root",char(runRoot), ...
    "run_id","R1", ...
    "stage_id","stage_A4", ...
    "effective_config_path",char(configPath));
inputs = struct( ...
    "base_parameters",repmat('a',1,64), ...
    "timeseries",repmat('b',1,64));
manifest = struct( ...
    "run_id","R1", ...
    "stage_id","stage_A4", ...
    "status","RUNNING", ...
    "started_at","2026-08-05T00:00:00+08:00", ...
    "ended_at",[], ...
    "git_commit",repmat('1',1,40), ...
    "input_hashes",inputs);
running = rkkt.artifacts.update_run_index(context,manifest);
verifyEqual(testCase,running.ended_at,"");
verifyEqual(testCase,running.repeat_class,"ORIGINAL");

manifest.status = "PASS";
manifest.ended_at = "2026-08-05T00:01:00+08:00";
manifest.iteration_count = 1;
manifest.elapsed_seconds = 1;
original = rkkt.artifacts.update_run_index(context,manifest);
verifyEqual(testCase,original.repeat_class,"ORIGINAL");

runRoot = fullfile(runsRoot,"R2");
mkdir(runRoot);
context.root = char(runRoot);
context.run_id = "R2";
manifest.run_id = "R2";
manifest.git_commit = repmat('2',1,40);
manifest.started_at = "2026-08-05T00:02:00+08:00";
manifest.ended_at = "2026-08-05T00:03:00+08:00";
repeat = rkkt.artifacts.update_run_index(context,manifest);
verifyEqual(testCase,repeat.repeat_class,"REPEAT");
verifyEqual(testCase,repeat.repeat_of_run_id,"R1");
pointer = jsondecode(fileread(fullfile( ...
    runsRoot,"LATEST_PASS.json")));
verifyEqual(testCase,string(pointer.run_id),"R2");
history = rkkt.diagnostics.snapshot_stage_a4_historical_runs( ...
    temporaryRoot);
verifyFalse(testCase,any(history.relativePath=="运行索引.csv"));
verifyFalse(testCase,any(history.relativePath=="LATEST_PASS.json"));
verifyTrue(testCase,all(ismember(["R1";"R2"],history.relativePath)));
clear cleanup
end

function testProjectRootIsDeterministic(testCase)
verifyEqual(testCase,canonical_path(rkkt.projectRoot()), ...
    canonical_path(testCase.TestData.root));
end

function testDataIndexAndStateCloseExactly(testCase)
index = testCase.TestData.index;
state = testCase.TestData.state;
verifyEqual(testCase,index.counts.variables,3722);
verifyEqual(testCase,index.counts.equalities,618);
verifyEqual(testCase,index.counts.inequalities,7248);
verifyEqual(testCase,numel(state.xi),index.counts.variables);
verifyEqual(testCase,numel(state.y),index.counts.equalities);
verifyEqual(testCase,numel(state.l),index.counts.inequalities);
verifyEqual(testCase,numel(state.z),index.counts.inequalities);
verifyTrue(testCase,all(state.l>0) && all(state.z>0));
end

function testOneBoundedIterationUsesThePackageSolver(testCase)
data = testCase.TestData.data;
config = testCase.TestData.config;
config.a4_3.max_iterations = 1;
index = testCase.TestData.index;
state = testCase.TestData.state;
result = rkkt.ipm.solve(state,data,index,config);
verifyEqual(testCase,result.status,"MAX_ITERATIONS");
verifyEqual(testCase,result.iteration_count,1);
verifyEqual(testCase,result.final_state.state_revision,1);
verifyTrue(testCase,result.last_step.all_pass);
verifyLessThanOrEqual(testCase, ...
    result.last_step.direction_audit.direction_relative_error,1e-10);
verifyLessThanOrEqual(testCase, ...
    result.last_step.direction_audit.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase, ...
    result.last_step.direction_audit.full_kkt_relative_residual,1e-10);
verifyTrue(testCase, ...
    result.last_step.recursive.no_full_direction_fallback);
verifyFalse(testCase,result.last_step.recursive.full_direction_consumed);
end

function value = code_source(pathValue)
lines = splitlines(string(fileread(pathValue)));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end

function remove_tree(pathValue)
if isfolder(pathValue)
    rmdir(pathValue,"s");
end
end
