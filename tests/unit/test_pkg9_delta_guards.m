function tests = test_pkg9_delta_guards
%TEST_PKG9_DELTA_GUARDS Guard the fixed upstream and execution boundary.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
testCase.TestData.root = root;
end

function testStableMergeHasExactImmutableSecondParent(testCase)
root = testCase.TestData.root;
mergeCommit = "6bea7051d13dfae8afd83cd134823fdd8ce787c3";
parents = split(strip(git_output(root,"show -s --format=%P "+mergeCommit)));
verifyEqual(testCase,numel(parents),2);
verifyEqual(testCase,parents(2), ...
    "90bf33cca0611154231588ac5d7ee09fd0e9c089");
end

function testUpdatedLdlPassesFixedSingleDayChainResidual(testCase)
root = testCase.TestData.root;
config = rkkt.model.load_stage_a2_configuration(root);
data = rkkt.data.load_project_data(root);
index = rkkt.indexing.build_stage_a2_index(data,"RunId","PKG9_LDL_DELTA");
state = rkkt.model.initialize_stage_a2_state(data,index,config);
linearization = rkkt.model.build_stage_a2_linearization(state,data,index,config);
reduced = rkkt.solver.eliminate_inequality_directions(linearization);
partition = rkkt.solver.partition_recursive_system(linearization,reduced, ...
    AssemblyTolerance=1e-12);
result = rkkt.solver.solve_block_thomas_ldl(partition, ...
    SymmetryTolerance=config.tolerances.symmetry_relative, ...
    ResidualRefinementMaxPasses=0, ...
    UseCongruenceScaling=true,EquilibrationPasses=8);
verifyEqual(testCase,numel(partition.hour),24);
verifyEqual(testCase,result.rhs_count,15);
verifyLessThanOrEqual(testCase, ...
    result.diagnostics.chain_relative_residual,1e-10);
verifyTrue(testCase,all([result.diagnostics.hour_block.schur_scaling_used]));
verifyEqual(testCase, ...
    [result.diagnostics.hour_block.schur_equilibration_passes], ...
    repmat(8,1,24));
end

function testA4CallerKeepsPkgFacadesAndStableNumericalRepair(testCase)
source = noncomment_source(fileread(fullfile( ...
    testCase.TestData.root,"main_stage_A4_3.m")));
required = ["rkkt.data.load";"rkkt.indexing.build"; ...
    "rkkt.ipm.solve";"rkkt.artifacts.export"; ...
    "numerical_repair_freeze";"recursive_congruence_scaling_enabled"];
for token = required.'
    verifyTrue(testCase,contains(source,token), ...
        "Missing merged A4 caller contract: "+token);
end
for legacy = ["load_project_data";"build_stage_a4_index"; ...
        "run_stage_a4_full_ipm";"export_stage_a4_result_artifacts"].'
    pattern = "(^|[^A-Za-z0-9_.])"+legacy+"\s*\(";
    verifyEmpty(testCase,regexp(source,pattern,"once"), ...
        "A4 caller restored a legacy call: "+legacy);
end
formalSource = noncomment_source(fileread(fullfile( ...
    testCase.TestData.root,"tests","integration", ...
    "test_stage_a4_3_formal_candidate.m")));
for token = ["rkkt.ipm.solve";"numerical_repair_freeze"; ...
        "UseCongruenceScaling";"1e-6"]'
    verifyTrue(testCase,contains(formalSource,token), ...
        "Missing merged formal-candidate contract: "+token);
end
end

function testB2CFilesAndProductionCallsAreAbsent(testCase)
root = testCase.TestData.root;
for relative = ["main_stage_B_2C.m";"config/stage_B_2C.yaml"; ...
        "src/+rkkt/+indexing/build_stage_b2c_index.m"; ...
        "src/+rkkt/+solver/run_stage_b2c_full_ipm.m"; ...
        "src/+rkkt/+solver/refine_stage_b2b_augmented_day_solution.m"; ...
        "src/+rkkt/+solver/refine_stage_b2b_retained_chain_solution.m"].'
    verifyFalse(testCase,isfile(fullfile(root,replace(relative,"/",filesep))), ...
        "Forbidden B-2C file is present: "+relative);
end
files = dir(fullfile(root,"src","**","*.m"));
files = files(~[files.isdir]);
for k = 1:numel(files)
    source = noncomment_source(fileread(fullfile( ...
        string(files(k).folder),string(files(k).name))));
    verifyEmpty(testCase,regexp(lower(source), ...
        '(^|[^a-z0-9_])(?:main_stage_b_2c|run_stage_b2c|build_stage_b2c|initialize_stage_b2c)\s*\(', ...
        "once"),"B-2C production call leaked into "+string(files(k).name));
end
end

function testNewPackageCodeHasNoForbiddenDenseInverseOrFallback(testCase)
root = testCase.TestData.root;
files = dir(fullfile(root,"src","+rkkt","**","*StageB*.m"));
files = files(~[files.isdir]);
verifyGreaterThan(testCase,numel(files),0);
for k = 1:numel(files)
    pathValue = fullfile(string(files(k).folder),string(files(k).name));
    source = noncomment_source(fileread(pathValue));
    verifyEmpty(testCase,regexp(source, ...
        '(^|[^A-Za-z0-9_])(inv|pinv|lsqminnorm)\s*\(',"once"), ...
        "Forbidden numerical operation in "+pathValue);
    verifyFalse(testCase,contains(source,"run_stage_b2c_full_ipm"));
    verifyFalse(testCase,contains(source,"rkkt.ipm.solve"));
end
end

function testDeltaInventoryCoversBothSourcesAndAllRequiredRows(testCase)
pathValue = fullfile(testCase.TestData.root,"tests", ...
    "PKG_9_delta_inventory.csv");
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
inventory = readtable(pathValue,options);
expectedVariables = ["inventory_id","path","origin_class", ...
    "change_kind","scope_role","required_test","reused_evidence", ...
    "coverage_test","coverage_status","notes"];
verifyEqual(testCase,string(inventory.Properties.VariableNames), ...
    expectedVariables);
verifyEqual(testCase,nnz(inventory.origin_class=="package_only"),111);
% The stable side has 118 non-overlap paths; the LDL path is reclassified
% as the higher-priority uncommitted_user_change row, leaving 117 here.
verifyEqual(testCase,nnz(inventory.origin_class=="upstream_only"),117);
verifyEqual(testCase,nnz(inventory.origin_class=="overlap"),2);
verifyEqual(testCase, ...
    nnz(inventory.origin_class=="uncommitted_user_change"),1);
verifyTrue(testCase,all(inventory.coverage_status=="COVERED"));
verifyEqual(testCase,numel(unique(inventory.inventory_id)),height(inventory));
verifyEqual(testCase,numel(unique(inventory.path)),height(inventory));
required = logical_values(inventory.required_test);
verifyTrue(testCase,all(strlength(inventory.coverage_test(required))>0));
for path = ["main_stage_A4_3.m"; ...
        "tests/integration/test_stage_a4_3_formal_candidate.m"; ...
        "src/+rkkt/+solver/solve_block_thomas_ldl.m"; ...
        "src/+rkkt/+workflows/stageB2B.m"; ...
        "src/+rkkt/+solver/+validation/runStageB2B.m"; ...
        "PKG_REFACTOR_STAGE.md"].'
    verifyEqual(testCase,nnz(inventory.path==path),1, ...
        "Missing or duplicate delta inventory path: "+path);
end
end

function testCurrentStageRemainsStageBReadyAndNotStageC1(testCase)
source = string(fileread(fullfile(testCase.TestData.root, ...
    "CURRENT_STAGE.md")));
verifyTrue(testCase,contains(source,"`stage_id`: `stage_B`"));
verifyTrue(testCase,contains(source,"`status`: `READY`"));
verifyFalse(testCase,contains(source,"`stage_id`: `stage_C1`"));
end

function value = git_output(root,arguments)
safeRoot = replace(root,"\","/");
command = "git -c safe.directory="+safeRoot+" -C "+root+" "+arguments;
[status,output] = system(char(command));
assert(status==0,"pkg9:test:GitCommand", ...
    "Git command failed: %s",command);
value = strip(string(output));
end

function value = noncomment_source(inputValue)
lines = splitlines(string(inputValue));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end

function values = logical_values(values)
if islogical(values)
    return
end
if isnumeric(values)
    values = logical(values);
    return
end
values = lower(strip(string(values)))=="true";
end
