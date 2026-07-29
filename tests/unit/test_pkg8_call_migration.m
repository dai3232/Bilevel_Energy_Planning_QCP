function tests = test_pkg8_call_migration
%TEST_PKG8_CALL_MIGRATION Fixed PKG-8 migration and closure checks.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot,"src");
baseline = "91d31035ec6edd928a84a4c50b0bdaa23838a632";
originalPath = path;
testCase.addTeardown(@()path(originalPath));
addpath(genpath(sourceRoot));

runsBefore = runs_inventory(repositoryRoot);
originalBefore = original_worktree_identity();
[inputBefore,inputBeforePass] = verify_input_hashes(repositoryRoot);

data = rkkt.data.load(repositoryRoot);
[indexFacts,indexForFixture] = compare_index_entries( ...
    repositoryRoot,data);

temporaryProject = string(tempname(tempdir));
mkdir(temporaryProject);
testCase.addTeardown(@()remove_tree(temporaryProject));
[artifactFacts,reportFacts] = facade_io_facts( ...
    repositoryRoot,temporaryProject,data,indexForFixture);

stepPath = fullfile(sourceRoot,"+rkkt","+ipm","+validation", ...
    "IPM单步输出.mat");
solvePath = fullfile(sourceRoot,"+rkkt","+ipm","+validation", ...
    "IPM受控轨迹输出.mat");
stepDisk = load(stepPath,"moduleResult");
solveDisk = load(solvePath,"moduleResult");
stepModule = stepDisk.moduleResult;
solveModule = solveDisk.moduleResult;
[stepReferencesValid,stepReferenceCount] = ...
    artifact_references_valid(stepModule.input);
[solveReferencesValid,solveReferenceCount] = ...
    artifact_references_valid(solveModule.input);
pkg7HashesValid = stepReferencesValid && solveReferencesValid && ...
    stepReferenceCount>=5 && solveReferenceCount>=1;

runsAfter = runs_inventory(repositoryRoot);
originalAfter = original_worktree_identity();
[inputAfter,inputAfterPass] = verify_input_hashes(repositoryRoot);

testCase.TestData = struct( ...
    "repositoryRoot",repositoryRoot, ...
    "sourceRoot",sourceRoot, ...
    "baseline",baseline, ...
    "indexFacts",indexFacts, ...
    "artifactFacts",artifactFacts, ...
    "reportFacts",reportFacts, ...
    "stepModule",stepModule, ...
    "solveModule",solveModule, ...
    "pkg7HashesValid",pkg7HashesValid, ...
    "runsBefore",runsBefore, ...
    "runsAfter",runsAfter, ...
    "originalBefore",originalBefore, ...
    "originalAfter",originalAfter, ...
    "inputBefore",inputBefore, ...
    "inputAfter",inputAfter, ...
    "inputBeforePass",inputBeforePass, ...
    "inputAfterPass",inputAfterPass);
end

function testBranchBaselineAndWorktreeIdentity(testCase)
root = testCase.TestData.repositoryRoot;
[branchStatus,branch] = git(root,"branch --show-current");
[rootStatus,actualRoot] = git(root,"rev-parse --show-toplevel");
[ancestorStatus,~] = git(root,"merge-base --is-ancestor "+ ...
    testCase.TestData.baseline+" HEAD");
verifyEqual(testCase,branchStatus,0);
verifyEqual(testCase,strip(branch),"refactor/pkg-interface");
verifyEqual(testCase,rootStatus,0);
verifyTrue(testCase,same_path(strip(actualRoot),root));
verifyEqual(testCase,ancestorStatus,0);
end

function testFormalEntryUsesFourRequiredPackageInterfaces(testCase)
source = formal_entry_source(testCase);
required = [ ...
    "rkkt.data.load"
    "rkkt.indexing.build"
    "rkkt.ipm.solve"
    "rkkt.artifacts.export"];
for name = required.'
    verifyEqual(testCase,call_count(source,name),1,name);
end
end

function testFormalEntryNoLongerCallsFourLegacyFunctions(testCase)
source = formal_entry_source(testCase);
legacy = [ ...
    "load_project_data"
    "build_stage_a4_index"
    "run_stage_a4_full_ipm"
    "export_stage_a4_result_artifacts"];
for name = legacy.'
    verifyEqual(testCase,call_count(source,name),0,name);
end
end

function testCreateRunContextRemainsAllowedInfrastructure(testCase)
source = formal_entry_source(testCase);
verifyEqual(testCase,call_count(source,"create_run_context"),1);
inventory = legacy_inventory(testCase);
rows = inventory(inventory.legacy_function=="create_run_context",:);
verifyGreaterThanOrEqual(testCase,height(rows),1);
verifyTrue(testCase,all(contains(rows.package_interface, ...
    "允许保留基础设施")));
verifyFalse(testCase,any(logical_values( ...
    rows.package_backend_dependency)));
mainRow = rows(rows.caller_path=="main_stage_A4_3.m",:);
verifyEqual(testCase,height(mainRow),1);
verifyEqual(testCase,mainRow.caller_category, ...
    "active_formal_orchestration");
verifyEqual(testCase,mainRow.migration_status, ...
    "allowed_infrastructure_retained");
end

function testIndexDefaultMatchesLegacyExactly(testCase)
facts = testCase.TestData.indexFacts;
verifyTrue(testCase,facts.default_exact);
verifyEqual(testCase,facts.default_run_id,"STAGE_A4_INDEX");
end

function testIndexExplicitRunIdMatchesLegacyExactly(testCase)
facts = testCase.TestData.indexFacts;
verifyTrue(testCase,facts.explicit_run_id_exact);
verifyEqual(testCase,facts.explicit_run_id,"PKG8_EXPLICIT_RUN");
end

function testIndexExplicitConfigAndRunIdMatchesLegacyExactly(testCase)
facts = testCase.TestData.indexFacts;
verifyTrue(testCase,facts.explicit_config_run_id_exact);
verifyTrue(testCase,facts.all_run_id_columns_preserved);
verifyEqual(testCase,facts.config_run_id,"PKG8_CONFIG_RUN");
verifyEqual(testCase,facts.config_path,fullfile( ...
    testCase.TestData.repositoryRoot,"config","stage_A4.yaml"));
end

function testArtifactsFacadeMatchesLegacyOnSafeTemporaryFixture(testCase)
facts = testCase.TestData.artifactFacts;
verifyTrue(testCase,facts.facade_is_direct_delegate);
verifyTrue(testCase,facts.normalized_output_exact);
verifyTrue(testCase,facts.persisted_payload_exact);
verifyTrue(testCase,facts.all_facade_targets_exist);
verifyTrue(testCase,facts.temporary_only);
verifyFalse(testCase,facts.formal_run_context_created);
end

function testReportingFacadeMatchesLegacyOnSafeTemporaryFixture(testCase)
facts = testCase.TestData.reportFacts;
verifyTrue(testCase,facts.facade_is_direct_delegate);
verifyTrue(testCase,facts.report_paths_exact);
verifyTrue(testCase,facts.validation_without_container_hash_exact);
verifyTrue(testCase,facts.document_xml_exact);
verifyTrue(testCase,facts.all_facade_targets_exist);
verifyTrue(testCase,facts.temporary_only);
verifyFalse(testCase,facts.formal_run_context_created);
end

function testFormalEntryResumeRecoveryAndReturnContractAreUnchanged( ...
        testCase)
root = testCase.TestData.repositoryRoot;
current = normalize_newlines(fileread(fullfile(root,"main_stage_A4_3.m")));
[status,baselineSource] = git(root,"show "+ ...
    testCase.TestData.baseline+":main_stage_A4_3.m");
verifyEqual(testCase,status,0);
baselineSource = normalize_newlines(baselineSource);
restored = replace(current, ...
    ["rkkt.data.load";"rkkt.indexing.build"; ...
    "rkkt.ipm.solve";"rkkt.artifacts.export"], ...
    ["load_project_data";"build_stage_a4_index"; ...
    "run_stage_a4_full_ipm";"export_stage_a4_result_artifacts"]);
verifyEqual(testCase,restored,baselineSource);
verifyTrue(testCase,contains(current, ...
    "options.ResumeRunId (1,1) string = """""));
verifyTrue(testCase,contains(current,"resume_command"));
requiredReturnFields = [ ...
    """run_id"""
    """run_path"""
    """manifest_status"""
    """run_terminal_state"""
    """convergence_achieved"""
    """iteration_count"""
    """final_metrics"""
    """execution_audit"""
    """reports_generated"""
    """tests_executed"""
    """stage_status"""
    """stage_b_entered"""];
for field = requiredReturnFields.'
    verifyTrue(testCase,contains(current,field),field);
end
end

function testPkg7DefaultStepDeterministicFieldsRemainExact(testCase)
module = testCase.TestData.stepModule;
verifyTrue(testCase,testCase.TestData.pkg7HashesValid);
verifyTrue(testCase, ...
    module.diagnostics.default_deterministic_fields_exact);
verifyTrue(testCase, ...
    module.diagnostics.default_timing_finite_nonnegative);
verifyTrue(testCase, ...
    module.diagnostics.objective_facts.default_deterministic_exact);
verifyTrue(testCase,module.output.all_pass);
end

function testPkg7FormalStepDeterministicFieldsRemainExact(testCase)
module = testCase.TestData.stepModule;
formal = module.output.formal_option_comparison;
verifyTrue(testCase, ...
    module.diagnostics.formal_option_deterministic_fields_exact);
verifyTrue(testCase,module.diagnostics.formal_timing_finite_nonnegative);
verifyTrue(testCase,formal.deterministic_fields_exact);
verifyTrue(testCase,formal.timing_finite_nonnegative);
verifyTrue(testCase,formal.all_pass);
end

function testPkg7ThreeRoundTrajectoryRemainsExact(testCase)
controlled = testCase.TestData.solveModule.output.controlledTrajectory;
rounds = controlled.rounds;
verifyEqual(testCase,controlled.controlled_preview_iteration_count,3);
verifyEqual(testCase,height(rounds),3);
verifyTrue(testCase,controlled.state_trajectory_legacy_exact);
required = [ ...
    "deterministicFieldsExact"
    "stateBeforeExact"
    "stateAfterExact"
    "stateFingerprintExact"
    "recursiveDirectionExact"
    "alphaExact"
    "residualSummaryExact"
    "complementarityGapExact"
    "directionAuditExact"
    "counterTrajectoryExact"
    "allPass"];
for name = required.'
    verifyTrue(testCase,all(rounds.(name)),name);
end
end

function testPkg7InteriorPositivityRemainsExact(testCase)
rounds = testCase.TestData.solveModule.output. ...
    controlledTrajectory.rounds;
verifyTrue(testCase,all(rounds.strictPositivity));
verifyGreaterThan(testCase,min(rounds.minimumL),0);
verifyGreaterThan(testCase,min(rounds.minimumZ),0);
verifyTrue(testCase,all(isfinite([ ...
    rounds.minimumL;rounds.minimumZ])));
end

function testPkg7RecursiveDirectionRemainsOfficialWithoutFallback( ...
        testCase)
step = testCase.TestData.stepModule.output;
rounds = testCase.TestData.solveModule.output. ...
    controlledTrajectory.rounds;
verifyTrue(testCase,step.official_recursive_direction.is_official);
verifyTrue(testCase, ...
    step.official_recursive_direction.no_full_direction_fallback);
verifyFalse(testCase, ...
    step.official_recursive_direction.full_direction_consumed);
verifyTrue(testCase,all(rounds.noFullDirectionFallback));
verifyTrue(testCase,all(rounds.fullKktAuditOnly));
end

function testPkg8NeverExecutesFullIpm(testCase)
contract = testCase.TestData.solveModule.output.solveContract;
verifyFalse(testCase,contract.full_ipm_executed);
verifyEqual(testCase,contract.full_ipm_iteration_count,0);
verifyFalse(testCase,contract.formal_run_context_created);
verifyEqual(testCase,contract.solve_runtime_status, ...
    "DEFERRED_UNTIL_FORMAL_RUN");
source = unit_source(testCase);
verifyEmpty(testCase,regexp(source, ...
    '(?<![A-Za-z0-9_.])rkkt\.ipm\.solve\s*\(',"once"));
end

function testPackageDependenciesAreAcyclicAndAvoidValidation( ...
        testCase)
[adjacency,validationCalls] = package_dependency_facts( ...
    testCase.TestData.repositoryRoot);
closure = adjacency;
for k = 1:size(closure,1)
    closure = closure | (closure(:,k) & closure(k,:));
end
verifyFalse(testCase,any(diag(closure)));
verifyEmpty(testCase,validationCalls);
end

function testLegacyBackendsRemainUnmodifiedAndUncopied(testCase)
root = testCase.TestData.repositoryRoot;
inventory = legacy_inventory(testCase);
verifyEqual(testCase,string(inventory.Properties.VariableNames),[ ...
    "legacy_function","package_interface","caller_path", ...
    "caller_category","migration_status","retention_reason", ...
    "package_backend_dependency","deletion_eligible", ...
    "unexpected_caller"]);
verifyFalse(testCase,any(logical_values(inventory.unexpected_caller)));
verifyFalse(testCase,any(logical_values(inventory.deletion_eligible)));
allowedCategories = [ ...
    "active_formal_orchestration"
    "package_compatibility_backend"
    "historical_stage_or_diagnostic"
    "regression_test"
    "deletion_candidate"];
verifyTrue(testCase,all(ismember( ...
    inventory.caller_category,allowedCategories)));

legacyFunctions = unique(inventory.legacy_function,"stable");
for name = legacyFunctions.'
    relativePath = legacy_file(root,name);
    verifyNotEqual(testCase,relativePath,"",name);
    gitPath = replace(relativePath,"\","/");
    [expectedStatus,~] = git(root,"cat-file -e "+ ...
        testCase.TestData.baseline+":"""+gitPath+"""");
    [diffStatus,~] = git(root,"diff --quiet "+ ...
        testCase.TestData.baseline+" -- """+relativePath+"""");
    verifyEqual(testCase,expectedStatus,0,name);
    verifyEqual(testCase,diffStatus,0,name);
end

facades = [ ...
    "src/+rkkt/+data/load.m","load_project_data"
    "src/+rkkt/+indexing/build.m","build_stage_a4_index"
    "src/+rkkt/+ipm/solve.m","run_stage_a4_full_ipm"
    "src/+rkkt/+artifacts/export.m", ...
        "export_stage_a4_result_artifacts"
    "src/+rkkt/+reporting/generate.m","generate_stage_a4_reports"];
for row = 1:size(facades,1)
    source = string(fileread(fullfile(root, ...
        replace(facades(row,1),"/",filesep))));
    verifyEqual(testCase,call_count(source,facades(row,2)),1, ...
        facades(row,1));
end
end

function testRunsInventoryIsUnchanged(testCase)
verifyEqual(testCase,testCase.TestData.runsAfter, ...
    testCase.TestData.runsBefore);
end

function testCurrentStageContentAndHashAreUnchanged(testCase)
root = testCase.TestData.repositoryRoot;
stagePath = fullfile(root,"CURRENT_STAGE.md");
[diffStatus,~] = git(root,"diff --quiet "+ ...
    testCase.TestData.baseline+" -- ""CURRENT_STAGE.md""");
verifyEqual(testCase,diffStatus,0);
verifyEqual(testCase,lower(string(compute_sha256_file(stagePath))), ...
    "b1e39ca150759631b524cb2dc98158296db581757355b47b97f8f912b2fad5b7");
source = string(fileread(stagePath));
verifyNotEmpty(testCase,regexp(source, ...
    '`stage_id`:\s*`stage_A4`',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    '`status`:\s*`READY`',"once"));
end

function testOriginalWorktreeAndControlledInputsAreUnchanged(testCase)
verifyEqual(testCase,testCase.TestData.originalAfter, ...
    testCase.TestData.originalBefore);
verifyTrue(testCase,testCase.TestData.originalAfter.exists);
verifyEqual(testCase, ...
    testCase.TestData.originalAfter.head_status,0);
verifyEqual(testCase, ...
    testCase.TestData.originalAfter.worktree_status,0);
verifyTrue(testCase,testCase.TestData.inputBeforePass);
verifyTrue(testCase,testCase.TestData.inputAfterPass);
verifyEqual(testCase,testCase.TestData.inputAfter, ...
    testCase.TestData.inputBefore);
verifyEqual(testCase,height(testCase.TestData.inputAfter),2);
verifyEqual(testCase,sort(testCase.TestData.inputAfter.fileName), ...
    sort(["基础参数.xlsx";"输入数据.xlsx"]));
verifyTrue(testCase,all(testCase.TestData.inputAfter.hashMatch));
end

function testDeferredOutputFlagsAreExplicit(testCase)
contract = testCase.TestData.solveModule.output.solveContract;
verifyFalse(testCase,contract.full_ipm_executed);
verifyFalse(testCase,contract.formal_run_context_created);
verifyFalse(testCase,contract.convergence_evaluated);
verifyFalse(testCase,contract.convergence_claimed);
contractTable = readtable( ...
    testCase.TestData.solveModule.tableFiles(2), ...
    "TextType","string","VariableNamingRule","preserve");
verifyEqual(testCase,contract_value(contractTable, ...
    "full_ipm_executed"),"false");
verifyEqual(testCase,contract_value(contractTable, ...
    "formal_run_context_created"),"false");
verifyEqual(testCase,contract_value(contractTable, ...
    "convergence_evaluated"),"false");
verifyEqual(testCase,contract_value(contractTable, ...
    "convergence_claimed"),"false");
end

function [facts,indexForFixture] = compare_index_entries(root,data)
legacyDefault = build_stage_a4_index(data);
facadeDefault = rkkt.indexing.build(data);
facts.default_exact = isequaln(facadeDefault,legacyDefault);
facts.default_run_id = unique_run_id(facadeDefault);

runId = "PKG8_EXPLICIT_RUN";
legacyRun = build_stage_a4_index(data,RunId=runId);
facadeRun = rkkt.indexing.build(data,RunId=runId);
facts.explicit_run_id_exact = isequaln(facadeRun,legacyRun);
facts.explicit_run_id = unique_run_id(facadeRun);

configPath = fullfile(root,"config","stage_A4.yaml");
configRunId = "PKG8_CONFIG_RUN";
legacyConfig = build_stage_a4_index(data, ...
    ConfigPath=configPath,RunId=configRunId);
facadeConfig = rkkt.indexing.build(data, ...
    ConfigPath=configPath,RunId=configRunId);
facts.explicit_config_run_id_exact = ...
    isequaln(facadeConfig,legacyConfig);
facts.config_run_id = unique_run_id(facadeConfig);
facts.config_path = configPath;
facts.all_run_id_columns_preserved = all_index_run_ids( ...
    facadeConfig,configRunId);
indexForFixture = facadeConfig;
end

function value = unique_run_id(index)
tables = ["variable_index","constraint_index","block_index", ...
    "fixed_zero_map","permutation_map","soc_link_map"];
values = strings(0,1);
for name = tables
    values = [values;string(index.(name).run_id)]; %#ok<AGROW>
end
uniqueValues = unique(values);
assert(isscalar(uniqueValues), ...
    "pkg8:test:IndexRunId","Index run_id is not unique.");
value = uniqueValues;
end

function value = all_index_run_ids(index,expected)
tables = ["variable_index","constraint_index","block_index", ...
    "fixed_zero_map","permutation_map","soc_link_map"];
value = true;
for name = tables
    value = value && all(string(index.(name).run_id)==expected);
end
end

function [artifactFacts,reportFacts] = facade_io_facts( ...
        repositoryRoot,temporaryProject,data,index)
config = load_stage_a4_configuration(repositoryRoot);
state = rkkt.model.initialize(data,index,config);
runRoot = fullfile(temporaryProject,"safe_run");
acceptanceDirectory = fullfile(runRoot,"acceptance");
mkdir(acceptanceDirectory);
manifestPath = fullfile(runRoot,"run_manifest.json");
write_json_file(manifestPath,struct( ...
    "run_id","PKG8_SAFE_FIXTURE", ...
    "stage_id","stage_A4","status","RUNNING"));
context = struct( ...
    "root",char(runRoot), ...
    "project_root",char(temporaryProject), ...
    "run_id","PKG8_SAFE_FIXTURE", ...
    "stage_id","stage_A4", ...
    "acceptance_dir",char(acceptanceDirectory), ...
    "run_manifest_path",char(manifestPath));
audit = physical_audit_fixture();

legacy = export_stage_a4_result_artifacts( ...
    context,data,index,state,audit, ...
    SolvePass="pkg8_safe",PhysicalTolerance=1.0e-8);
legacyPayload = load(legacy.paths.physical_results_mat);
delete_export_targets(legacy.paths);
facade = rkkt.artifacts.export( ...
    context,data,index,state,audit, ...
    SolvePass="pkg8_safe",PhysicalTolerance=1.0e-8);
facadePayload = load(facade.paths.physical_results_mat);
artifactFacts = struct( ...
    "facade_is_direct_delegate",direct_delegate_source( ...
        fullfile(repositoryRoot,"src","+rkkt","+artifacts","export.m"), ...
        "exported","export_stage_a4_result_artifacts"), ...
    "normalized_output_exact",isequaln( ...
        normalize_artifact_output(facade), ...
        normalize_artifact_output(legacy)), ...
    "persisted_payload_exact",isequaln(facadePayload,legacyPayload), ...
    "all_facade_targets_exist",all(isfile(string( ...
        struct2cell(facade.paths)))), ...
    "temporary_only",is_within(facade.paths.capacity_results, ...
        temporaryProject), ...
    "formal_run_context_created",false);

write_safe_report_evidence(context);
outputDirectory = fullfile(temporaryProject,"report_compare");
[legacyPaths,legacyValidation] = generate_stage_a4_reports( ...
    context,OutputDirectory=outputDirectory, ...
    FinalStatusCandidate="FAIL_RETRYABLE",ReportGateMode="preflight");
legacyXml = report_xml(legacyPaths);
remove_tree(outputDirectory);
[facadePaths,facadeValidation] = rkkt.reporting.generate( ...
    context,OutputDirectory=outputDirectory, ...
    FinalStatusCandidate="FAIL_RETRYABLE",ReportGateMode="preflight");
facadeXml = report_xml(facadePaths);
reportFacts = struct( ...
    "facade_is_direct_delegate",direct_delegate_source( ...
        fullfile(repositoryRoot,"src","+rkkt","+reporting", ...
        "generate.m"),"reportPaths,validation", ...
        "generate_stage_a4_reports"), ...
    "report_paths_exact",isequaln(facadePaths,legacyPaths), ...
    "validation_without_container_hash_exact",isequaln( ...
        removevars(facadeValidation,"sha256"), ...
        removevars(legacyValidation,"sha256")), ...
    "document_xml_exact",isequaln(facadeXml,legacyXml), ...
    "all_facade_targets_exist",all(isfile(string( ...
        struct2cell(facadePaths)))), ...
    "temporary_only",all(arrayfun( ...
        @(value)is_within(value,temporaryProject), ...
        string(struct2cell(facadePaths)))), ...
    "formal_run_context_created",false);
end

function value = normalize_artifact_output(value)
hashes = value.artifact_hashes;
matRows = hashes.artifact_type=="mat";
hashes.sha256(matRows) = "<container-hash>";
hashes.bytes(matRows) = 0;
value.artifact_hashes = hashes;
end

function delete_export_targets(paths)
targets = string(struct2cell(paths));
for target = targets.'
    if isfile(target)
        delete(target);
    end
end
end

function audit = physical_audit_fixture()
audit_id = ["POWER_BALANCE";"SOC_DYNAMICS";"SOC_BOUNDARIES"; ...
    "CAPACITY_BOUNDS";"OUTPUT_BOUNDS";"FIXED_ZERO"];
requirement = ["小时功率平衡";"SOC逐小时递推";"每日初末0.5E"; ...
    "容量上下界";"物理出力上下界";"固定零精确恢复"];
actual_value = zeros(6,1);
threshold = repmat(1.0e-8,6,1);
status = repmat("NOT_APPLICABLE",6,1);
evidence_path = repmat("temporary PKG-8 facade fixture",6,1);
audit = table(audit_id,requirement,actual_value,threshold,status, ...
    evidence_path);
end

function write_safe_report_evidence(context)
root = string(context.root);
for folder = ["issues","iterations","matrices","checkpoints","tests"]
    pathValue = fullfile(root,folder);
    if ~isfolder(pathValue)
        mkdir(pathValue);
    end
end
manifest = struct( ...
    "run_id",string(context.run_id), ...
    "stage_id","stage_A4", ...
    "status","RUNNING", ...
    "git_commit","PKG8_TEMPORARY_FIXTURE", ...
    "thermal_pass","pass_1", ...
    "day_ids",14:20, ...
    "optimization_executed",false, ...
    "full_ipm_executed",false, ...
    "parallel_executed",false, ...
    "physical_dispatch_interpretation",false, ...
    "capacity_planning_interpretation",false, ...
    "newton_direction_count",0, ...
    "enabled_components","NONE_TEMPORARY_INTERFACE_FIXTURE", ...
    "disabled_components",["FORMAL_IPM","CONVERGENCE_CLAIM"]);
write_json_file(fullfile(root,"run_manifest.json"),manifest);

environment = table("MATLAB_VERSION",false,"NOT_RUN", ...
    'VariableNames',{'check_id','blocking','status'});
write_table_csv_17g(fullfile(root,"environment.csv"),environment);
sha = [string(repmat('a',1,64));string(repmat('b',1,64))];
inputHashes = table(["基础参数.xlsx";"输入数据.xlsx"], ...
    sha,sha,repmat("PASS",2,1), ...
    'VariableNames',{'file_name','expectedSHA256', ...
    'actualSHA256','status'});
write_table_csv_17g(fullfile(root,"input_hashes.csv"),inputHashes);

testId = ["SA4-CONV-001";"SA4-CONV-002";"SA4-CONV-003"; ...
    "SA4-CONV-004";"SA4-EQ-001";"SA4-PHY-001";"SA4-RPT-001"];
acceptance = table(testId,repmat("temporary interface fixture",7,1), ...
    repmat("NOT_EXECUTED",7,1),repmat("NOT_EVALUATED",7,1), ...
    repmat("NOT_RUN",7,1),true(7,1), ...
    repmat("temporary PKG-8 fixture",7,1), ...
    'VariableNames',{'test_id','requirement','actual_value', ...
    'threshold','status','blocking','evidence_path'});
write_table_csv_17g(fullfile(root,"acceptance", ...
    "acceptance_results.csv"),acceptance);

issues = table(strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    'VariableNames',{'issue_id','test_id','symptom','root_cause', ...
    'implemented_change','regression_test','status'});
write_table_csv_17g(fullfile(root,"issues","issue_log.csv"),issues);

iteration = table(1,1,0,0,1,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,false, ...
    'VariableNames',{'iteration','state_revision','objective_scaled', ...
    'objective_original','r_eq_inf','r_ineq_inf', ...
    'physical_inequality_violation','r_dual_scaled_inf', ...
    'r_dual_original_mapped_inf','r_comp_scaled_inf', ...
    'mean_lz_scaled','ltz_scaled','gap_original_mapped', ...
    'eta_eq','eta_dual','eta_gap','candidate_alpha_primal', ...
    'applied_alpha_primal','candidate_alpha_dual', ...
    'applied_alpha_dual','min_l','min_z','convergence_passed'});
write_table_csv_17g(fullfile(root,"iterations", ...
    "iteration_summary.csv"),iteration);

direction = table(1,0,0,0,0,0,0,0,true,false,false, ...
    'VariableNames',{'iteration','direction_relative_error', ...
    'xi_relative_error','y_relative_error','l_relative_error', ...
    'z_relative_error','recursive_full_kkt_relative_residual', ...
    'full_kkt_relative_residual','no_full_direction_fallback', ...
    'full_kkt_audit_only','recursive_direction_is_official'});
write_table_csv_17g(fullfile(root,"iterations", ...
    "direction_audit.csv"),direction);

matrices = table(strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    'VariableNames',{'matrix_name','rows','columns','nnz'});
write_table_csv_17g(fullfile(root,"matrices", ...
    "matrix_manifest.csv"),matrices);
checkpoints = table(strings(0,1),strings(0,1),zeros(0,1), ...
    strings(0,1),strings(0,1), ...
    'VariableNames',{'run_id','stage_id','iteration','path','sha256'});
write_table_csv_17g(fullfile(root,"checkpoints", ...
    "checkpoint_manifest.csv"),checkpoints);
write_json_file(fullfile(root,"tests","test_summary.json"),struct( ...
    "test_total",0,"test_passed",0,"test_failed",0, ...
    "test_incomplete",0));
end

function values = report_xml(paths)
names = ["model_report","issue_report","run_summary"];
values = strings(numel(names),1);
for k = 1:numel(names)
    [valid,details] = validate_docx_package(paths.(names(k)));
    assert(valid,"pkg8:test:ReportFixture", ...
        "Temporary report fixture is invalid.");
    values(k) = string(details.document_xml);
end
end

function value = direct_delegate_source(pathValue,outputs,backend)
source = string(fileread(pathValue));
if outputs=="exported"
    assignment = "exported = "+backend+"(";
else
    assignment = "[reportPaths,validation] = "+backend+"(";
end
value = contains(source,assignment) && ...
    call_count(source,backend)==1;
end

function source = formal_entry_source(testCase)
source = string(fileread(fullfile( ...
    testCase.TestData.repositoryRoot,"main_stage_A4_3.m")));
end

function source = unit_source(testCase)
source = string(fileread(fullfile(testCase.TestData.repositoryRoot, ...
    "tests","unit","test_pkg8_call_migration.m")));
end

function countValue = call_count(source,name)
escaped = regexptranslate("escape",name);
pattern = "(?<![A-Za-z0-9_.])"+escaped+"\s*\(";
countValue = numel(regexp(char(source),char(pattern),"match"));
end

function inventory = legacy_inventory(testCase)
pathValue = fullfile(testCase.TestData.repositoryRoot,"docs", ...
    "PKG-08_旧入口调用与处置清单_v1.0.csv");
inventory = readtable(pathValue,"TextType","string", ...
    "VariableNamingRule","preserve");
end

function relativePath = legacy_file(root,functionName)
matches = dir(fullfile(root,"src","**",functionName+".m"));
matches = matches(~[matches.isdir]);
if numel(matches)~=1
    relativePath = "";
    return
end
absolute = fullfile(string(matches.folder),string(matches.name));
prefix = canonical_path(root)+filesep;
absolute = canonical_path(absolute);
relativePath = extractAfter(absolute,strlength(prefix));
end

function [adjacency,validationCalls] = package_dependency_facts(root)
modules = ["contracts","data","indexing","model","solver", ...
    "ipm","workflows","artifacts","reporting"];
adjacency = false(numel(modules),numel(modules));
validationCalls = strings(0,1);
files = dir(fullfile(root,"src","+rkkt","**","*.m"));
files = files(~[files.isdir]);
for k = 1:numel(files)
    pathValue = fullfile(string(files(k).folder),string(files(k).name));
    normalized = replace(pathValue,"\","/");
    if contains(normalized,"/+validation/") || ...
            string(files(k).name)=="Contents.m"
        continue
    end
    sourceModule = package_module(normalized);
    if sourceModule==""
        continue
    end
    source = noncomment_source(string(fileread(pathValue)));
    if ~isempty(regexp(source, ...
            'rkkt\.[A-Za-z]\w*\.validation(?:\.|\s*\()', "once"))
        validationCalls(end+1,1) = normalized; %#ok<AGROW>
    end
    tokens = regexp(source, ...
        'rkkt\.([A-Za-z]\w*)\.[A-Za-z]\w*', ...
        "tokens");
    for token = tokens
        target = string(token{1}{1});
        sourceRow = find(modules==sourceModule,1);
        targetColumn = find(modules==target,1);
        if ~isempty(sourceRow) && ~isempty(targetColumn) && ...
                sourceRow~=targetColumn
            adjacency(sourceRow,targetColumn) = true;
        end
    end
end
validationCalls = unique(validationCalls);
end

function value = package_module(pathValue)
token = regexp(pathValue,'/\+rkkt/\+([^/]+)/','tokens','once');
if isempty(token)
    value = "";
else
    value = string(token{1});
end
end

function value = noncomment_source(source)
lines = splitlines(source);
keep = ~startsWith(strip(lines),"%");
value = strjoin(lines(keep),newline);
end

function [value,countValue] = artifact_references_valid(inputValue)
value = true;
countValue = 0;
if isstruct(inputValue)
    for element = 1:numel(inputValue)
        current = inputValue(element);
        if isfield(current,"path") && isfield(current,"sha256") && ...
                is_text_scalar(current.path) && ...
                is_text_scalar(current.sha256)
            pathValue = string(current.path);
            expected = lower(string(current.sha256));
            countValue = countValue+1;
            value = value && isfile(pathValue) && ...
                strlength(expected)==64 && ...
                lower(string(compute_sha256_file(pathValue)))==expected;
        end
        names = fieldnames(current);
        for k = 1:numel(names)
            child = current.(names{k});
            if isstruct(child)
                [childValid,childCount] = artifact_references_valid(child);
                value = value && childValid;
                countValue = countValue+childCount;
            end
        end
    end
end
end

function value = is_text_scalar(inputValue)
value = (isstring(inputValue)&&isscalar(inputValue)) || ...
    (ischar(inputValue)&&isrow(inputValue));
end

function value = runs_inventory(root)
runsRoot = fullfile(root,"runs");
if ~isfolder(runsRoot)
    value = table(strings(0,1),false(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'relative_path','is_directory','bytes','datenum'});
    return
end
entries = dir(fullfile(runsRoot,"**","*"));
entries = entries(~ismember({entries.name},{'.','..'}));
n = numel(entries);
relativePath = strings(n,1);
isDirectory = false(n,1);
bytes = zeros(n,1);
dateNumber = zeros(n,1);
prefix = canonical_path(runsRoot)+filesep;
for k = 1:n
    absolute = canonical_path(fullfile( ...
        string(entries(k).folder),string(entries(k).name)));
    relativePath(k) = replace( ...
        extractAfter(absolute,strlength(prefix)),"\","/");
    isDirectory(k) = entries(k).isdir;
    bytes(k) = entries(k).bytes;
    dateNumber(k) = entries(k).datenum;
end
value = table(relativePath,isDirectory,bytes,dateNumber, ...
    'VariableNames',{'relative_path','is_directory','bytes','datenum'});
value = sortrows(value,"relative_path");
end

function value = original_worktree_identity()
root = "H:\Reproduction\Hourly_Recursive_KKT";
if ~isfolder(root)
    value = struct("exists",false,"head","","status","", ...
        "input_hashes",strings(0,1));
    return
end
[headStatus,head] = git(root,"rev-parse HEAD");
[worktreeStatus,status] = git(root, ...
    "status --porcelain=v1 --untracked-files=all");
hashes = strings(2,1);
names = ["基础参数.xlsx";"输入数据.xlsx"];
for k = 1:2
    pathValue = fullfile(root,"inputs","raw",names(k));
    if isfile(pathValue)
        hashes(k) = compute_sha256_file(pathValue);
    end
end
value = struct("exists",true, ...
    "head_status",headStatus,"head",strip(head), ...
    "worktree_status",worktreeStatus,"status",status, ...
    "input_hashes",hashes);
end

function [status,output] = git(root,arguments)
safeRoot = replace(string(root),"\","/");
command = "git -c safe.directory="""+safeRoot+""" -C """+root+ ...
    """ "+arguments;
[status,raw] = system(char(command));
output = string(raw);
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end

function value = same_path(left,right)
left = replace(canonical_path(left),"/","\");
right = replace(canonical_path(right),"/","\");
if ispc
    value = strcmpi(left,right);
else
    value = strcmp(left,right);
end
end

function value = is_within(pathValue,parent)
pathValue = lower(replace(canonical_path(pathValue),"/","\"));
parent = lower(replace(canonical_path(parent),"/","\"));
value = startsWith(pathValue,parent+"\");
end

function value = normalize_newlines(value)
crlf = string(char([13,10]));
value = replace(string(value),crlf,string(newline));
value = replace(value,string(char(13)),string(newline));
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

function value = contract_value(tableValue,fieldName)
rows = tableValue.contractField==fieldName;
assert(nnz(rows)==1,"pkg8:test:ContractField", ...
    "Expected exactly one contract row for %s.",fieldName);
value = tableValue.contractValue(rows);
end

function remove_tree(pathValue)
if isfolder(pathValue)
    rmdir(pathValue,"s");
end
end
