function tests = test_pkg7_ipm_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot,"src");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(genpath(sourceRoot));

runsBefore = runs_inventory(repositoryRoot);
stepModule = rkkt.ipm.validation.runStep( ...
    Interactive=false,WriteArtifacts=true);
solveModule = rkkt.ipm.validation.runSolve( ...
    Interactive=false,WriteArtifacts=true);
runsAfter = runs_inventory(repositoryRoot);

stepDisk = load(stepModule.meta.output_file,"moduleResult");
solveDisk = load(solveModule.meta.output_file,"moduleResult");
recoveryDisk = load( ...
    stepModule.input.recoveryArtifact.path,"moduleResult");

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.stepModule = stepModule;
testCase.TestData.solveModule = solveModule;
testCase.TestData.stepDisk = stepDisk.moduleResult;
testCase.TestData.solveDisk = solveDisk.moduleResult;
testCase.TestData.recovery = ...
    recoveryDisk.moduleResult.output.recovery;
testCase.TestData.runsBefore = runsBefore;
testCase.TestData.runsAfter = runsAfter;
end

function testPkg6DayResponseUpstreamMappingIsCorrected(testCase)
mappingPath = fullfile(testCase.TestData.repositoryRoot,"docs", ...
    "PKG-01_现有模块到包接口映射_v1.0.csv");
mapping = readtable(mappingPath,"TextType","string", ...
    "VariableNamingRule","preserve");
rows = mapping(mapping.module_id=="DAY_RESPONSE",:);
verifyEqual(testCase,height(rows),1);
verifyEqual(testCase,rows.("固定上一级输入"), ...
    "小时链求解模块输出.mat");
end

function testStepFacadeOnlyDelegatesAndMirrorsOptions(testCase)
source = facade_source(testCase,"step");
verifyLessThanOrEqual(testCase,source_line_count(source),70);
verifyEqual(testCase,numel(regexp(source, ...
    '(?<![A-Za-z0-9_])execute_stage_a4_iteration\s*\(', ...
    "match")),1);
verifyEmpty(testCase,regexp(source, ...
    '(?<![A-Za-z0-9_])run_stage_a4_full_ipm\s*\(',"once"));

requiredOptions = [ ...
    "StepStrategy";"ObjectiveScaleMode"; ...
    "DiagnosticObjectiveChainId"; ...
    "EqualityResidualReferenceScale"; ...
    "DualResidualReferenceScale"; ...
    "RecursiveRefinementMaxPasses"];
for name = requiredOptions.'
    verifyGreaterThanOrEqual(testCase,count(source,"options."+name),2);
end
verifyNotEmpty(testCase,regexp(source, ...
    'StepStrategy[\s\S]*?=\s*"independent"',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'ObjectiveScaleMode[\s\S]*?=\s*"unscaled"',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'DiagnosticObjectiveChainId[^\r\n]*=\s*""',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'EqualityResidualReferenceScale[^\r\n]*=\s*NaN',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'DualResidualReferenceScale[^\r\n]*=\s*NaN',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'RecursiveRefinementMaxPasses[\s\S]*?=\s*0',"once"));

info = rkkt.info();
verifyEqual(testCase,string(info.package_version),"1.0.0");
verifyEqual(testCase,string(info.pkg_stage),"PACKAGE-HARD-CUT");
verifyTrue(testCase,ismember("rkkt.ipm.step", ...
    string(info.implemented_public_interfaces)));
end

function testDefaultStepDeterministicFieldsMatchLegacyWithoutTiming( ...
        testCase)
module = testCase.TestData.stepModule;
verifyTrue(testCase, ...
    module.diagnostics.default_deterministic_fields_exact);
verifyTrue(testCase, ...
    module.diagnostics.default_timing_finite_nonnegative);
facts = module.diagnostics.objective_facts;
verifyTrue(testCase,facts.default_deterministic_exact);
verifyTrue(testCase,facts.default_timing_valid);
verifyTrue(testCase,facts.state_before_exact);
verifyTrue(testCase,facts.linearization_identity_exact);
verifyTrue(testCase,facts.all_checks_pass);
verifyTrue(testCase,module.output.all_pass);
verifyTrue(testCase,all(structfun( ...
    @(value)isequal(value,true),module.output.checks)));
end

function testDefaultStepDirectionAndIdentityMatchPkg6Recovery(testCase)
module = testCase.TestData.stepModule;
direction = module.output.official_recursive_direction;
recovery = testCase.TestData.recovery;
for name = ["xi","y","l","z"]
    verifyEqual(testCase,direction.(name), ...
        recovery.components.(name),"AbsTol",0);
end
verifyEqual(testCase,direction.linearization_identity, ...
    string(recovery.linearization_identity));
verifyEqual(testCase,module.output.linearization_identity_before, ...
    string(recovery.linearization_identity));
verifyTrue(testCase,direction.is_official);
verifyTrue(testCase,direction.no_full_direction_fallback);
verifyFalse(testCase,direction.full_direction_consumed);
verifyTrue(testCase,module.diagnostics.pkg6_direction_exact);
end

function testFormalA43OptionStepMatchesLegacyWithoutTiming(testCase)
module = testCase.TestData.stepModule;
formal = module.output.formal_option_comparison;
verifyTrue(testCase, ...
    module.diagnostics.formal_option_deterministic_fields_exact);
verifyTrue(testCase,module.diagnostics.formal_timing_finite_nonnegative);
verifyTrue(testCase,formal.deterministic_fields_exact);
verifyTrue(testCase,formal.timing_finite_nonnegative);
verifyEqual(testCase,formal.step_strategy,"independent");
verifyEqual(testCase,formal.objective_scale_mode, ...
    "positive_scalar_unitization");
verifyEqual(testCase,formal.diagnostic_objective_chain_id, ...
    "A4-3-FORMAL-CANDIDATE");
verifyEqual(testCase,formal.recursive_refinement_max_passes,3);
verifyGreaterThanOrEqual(testCase, ...
    formal.equality_residual_reference_scale,1);
verifyGreaterThanOrEqual(testCase, ...
    formal.dual_residual_reference_scale,1);
verifyTrue(testCase,all(isfinite([ ...
    formal.equality_residual_reference_scale; ...
    formal.dual_residual_reference_scale])));
verifyNotEqual(testCase,formal.linearization_identity_before, ...
    formal.linearization_identity_after);
verifyTrue(testCase,formal.all_pass);
verifyTrue(testCase,formal.no_full_direction_fallback);
verifyFalse(testCase,formal.full_direction_consumed);
end

function testIndependentPrimalDualStateUpdateFormulaIsExact(testCase)
output = testCase.TestData.stepModule.output;
before = output.state_before;
after = output.state_after;
direction = output.official_recursive_direction;
alphaPrimal = output.applied_step.applied_alpha_primal;
alphaDual = output.applied_step.applied_alpha_dual;

verifyEqual(testCase,after.xi, ...
    before.xi+alphaPrimal*direction.xi,"AbsTol",0);
verifyEqual(testCase,after.l, ...
    before.l+alphaPrimal*direction.l,"AbsTol",0);
verifyEqual(testCase,after.y, ...
    before.y+alphaDual*direction.y,"AbsTol",0);
verifyEqual(testCase,after.z, ...
    before.z+alphaDual*direction.z,"AbsTol",0);
verifyEqual(testCase,alphaPrimal,output.primal_step.alpha,"AbsTol",0);
verifyEqual(testCase,alphaDual,output.dual_step.alpha,"AbsTol",0);
verifyEqual(testCase,output.applied_step.strategy,"independent");
verifyFalse(testCase,output.applied_step.experimental);
verifyFalse(testCase, ...
    output.applied_step.all_four_groups_use_common_step);
verifyEqual(testCase,output.primal_step.tau,0.9995,"AbsTol",0);
verifyEqual(testCase,output.dual_step.tau,0.9995,"AbsTol",0);
verifyEqual(testCase,output.residuals.before.mu, ...
    0.1*output.residuals.before.complementarity_gap,"AbsTol",0);
end

function testUpdatedStateRemainsInteriorAndCountersAdvance(testCase)
output = testCase.TestData.stepModule.output;
before = output.state_before;
after = output.state_after;
verifyTrue(testCase,all(isfinite([ ...
    after.xi;after.y;after.l;after.z])));
verifyGreaterThan(testCase,min(after.l),0);
verifyGreaterThan(testCase,min(after.z),0);
verifyEqual(testCase,after.iteration_index, ...
    before.iteration_index+1);
verifyEqual(testCase,after.state_revision, ...
    before.state_revision+1);
verifyEqual(testCase,after.newton_direction_number, ...
    before.newton_direction_number+1);
verifyEqual(testCase,after.completed_newton_direction_count, ...
    before.completed_newton_direction_count+1);
verifyNotEqual(testCase,output.linearization_identity_before, ...
    output.linearization_identity_after);
verifyTrue(testCase, ...
    testCase.TestData.stepModule.diagnostics. ...
        objective_facts.counters_increment_once);
end

function testFixedZeroSocPermutationAndDirectionIsolationRemainExact( ...
        testCase)
output = testCase.TestData.stepModule.output;
verifyEqual(testCase,output.fixed_zero.count,422);
verifyTrue(testCase,output.fixed_zero.values_exact_zero_before);
verifyTrue(testCase,output.fixed_zero.values_exact_zero_after);
verifyTrue(testCase,output.fixed_zero.directions_exact_zero);
verifyEqual(testCase,output.fixed_zero.maximum_absolute_value_after,0);
verifyEqual(testCase,output.fixed_zero.maximum_absolute_direction,0);

verifyTrue(testCase,output.soc.passed);
verifyEqual(testCase,output.soc.initial_half_energy_link_count,14);
verifyEqual(testCase,output.soc.terminal_half_energy_link_count,14);
verifyEqual(testCase, ...
    output.soc.cross_day_or_nonadjacent_link_count,0);
verifyEqual(testCase,output.permutation.dimension,4340);
verifyTrue(testCase,output.permutation.is_bijection);
verifyTrue(testCase,output.permutation.is_nonidentity);
verifyTrue(testCase, ...
    output.checks.recursive_no_full_direction_fallback);
verifyTrue(testCase,output.official_recursive_direction.is_official);
verifyTrue(testCase, ...
    output.official_recursive_direction.no_full_direction_fallback);
verifyFalse(testCase, ...
    output.official_recursive_direction.full_direction_consumed);
end

function testThreeRoundControlledTrajectoryMatchesLegacyRoundByRound( ...
        testCase)
controlled = testCase.TestData.solveModule.output.controlledTrajectory;
trajectory = controlled.rounds;
verifyEqual(testCase,controlled.controlled_preview_iteration_count,3);
verifyEqual(testCase,height(trajectory),3);
verifyEqual(testCase,trajectory.previewIteration,(1:3).');
verifyEqual(testCase,trajectory.iterationIndexBefore,(1:3).');
verifyEqual(testCase,trajectory.iterationIndexAfter,(2:4).');
verifyEqual(testCase,trajectory.stateRevisionBefore,(1:3).');
verifyEqual(testCase,trajectory.stateRevisionAfter,(2:4).');
verifyEqual(testCase,trajectory.stateAfterFingerprint(1:2), ...
    trajectory.stateBeforeFingerprint(2:3));

booleanColumns = [ ...
    "deterministicFieldsExact";"stateBeforeExact"; ...
    "stateAfterExact";"stateFingerprintExact"; ...
    "recursiveDirectionExact";"alphaExact"; ...
    "residualSummaryExact";"complementarityGapExact"; ...
    "directionAuditExact";"counterTrajectoryExact"; ...
    "strictPositivity";"noFullDirectionFallback"; ...
    "fullKktAuditOnly";"allPass"; ...
    "timingFiniteNonnegative"];
for name = booleanColumns.'
    verifyTrue(testCase,all(trajectory.(name)));
end
verifyTrue(testCase,controlled.state_trajectory_legacy_exact);
verifyTrue(testCase,all(isfinite([ ...
    trajectory.alphaPrimal;trajectory.alphaDual; ...
    trajectory.gapBefore;trajectory.gapAfter])));
verifyGreaterThan(testCase,min(trajectory.alphaPrimal),0);
verifyGreaterThan(testCase,min(trajectory.alphaDual),0);
verifyLessThanOrEqual(testCase,max(trajectory.alphaPrimal),1);
verifyLessThanOrEqual(testCase,max(trajectory.alphaDual),1);
verifyGreaterThan(testCase,min(trajectory.gapBefore),0);
verifyGreaterThan(testCase,min(trajectory.gapAfter),0);
verifyGreaterThan(testCase,min(trajectory.minimumL),0);
verifyGreaterThan(testCase,min(trajectory.minimumZ),0);
end

function testSolveFacadeOnlyDelegatesFormalProductionEntry(testCase)
source = facade_source(testCase,"solve");
verifyLessThanOrEqual(testCase,source_line_count(source),70);
verifyEqual(testCase,numel(regexp(source, ...
    '(?<![A-Za-z0-9_])run_stage_a4_full_ipm\s*\(', ...
    "match")),1);
verifyEmpty(testCase,regexp(source, ...
    '(?<![A-Za-z0-9_])execute_stage_a4_iteration\s*\(',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'options\.Resume[^\r\n]*logical\s*=\s*false',"once"));
verifyNotEmpty(testCase,regexp(source, ...
    'Resume\s*=\s*options\.Resume',"once"));
for pattern = { ...
        '(?m)^\s*(?:for|while|parfor)\b', ...
        '(?m)^\s*(?:try|catch)\b', ...
        'create_run_context\s*\(', ...
        '\bconfig(?:\.[A-Za-z]\w*)+\s*=(?!=)', ...
        '(?i)\bfallback\b', ...
        '(?i)\b(?:converged|convergence_achieved|terminal_state)\b', ...
        '(?<![A-Za-z0-9_])(?:save|writetable|mkdir)\s*\('}
    verifyEmpty(testCase,regexp(source,pattern{1},"once"));
end
info = rkkt.info();
verifyTrue(testCase,ismember("rkkt.ipm.solve", ...
    string(info.implemented_public_interfaces)));
end

function testInvalidRunContextErrorsMatchAndWriteNothing(testCase)
module = testCase.TestData.solveModule;
diagnostics = module.diagnostics;
contract = module.output.solveContract;
verifyEqual(testCase,diagnostics.legacy_solve_error_identifier, ...
    "stageA4:a43:RunContext");
verifyEqual(testCase,diagnostics.facade_solve_error_identifier, ...
    diagnostics.legacy_solve_error_identifier);
verifyTrue(testCase,diagnostics.solve_error_identifier_exact);
verifyTrue(testCase,diagnostics.runs_snapshot_unchanged);
verifyTrue(testCase,contract.legacy_facade_error_identifier_exact);
verifyTrue(testCase,contract.runs_snapshot_unchanged);
verifyEqual(testCase,contract.full_ipm_iteration_count,0);
verifyEqual(testCase,testCase.TestData.runsAfter, ...
    testCase.TestData.runsBefore);
end

function testValidationEntriesWriteFixedDeduplicatedArtifacts(testCase)
step = testCase.TestData.stepModule;
solve = testCase.TestData.solveModule;
rkkt.contracts.validateModuleResult(step);
rkkt.contracts.validateModuleResult(solve);
verifyEqual(testCase,testCase.TestData.stepDisk,step);
verifyEqual(testCase,testCase.TestData.solveDisk,solve);

matFiles = [string(step.meta.output_file); ...
    string(solve.meta.output_file)];
tableFiles = [step.tableFiles;solve.tableFiles];
figureFiles = [step.figureFiles;solve.figureFiles];
verifyTrue(testCase,all(isfile(matFiles)));
verifyTrue(testCase,all(isfile(tableFiles)));
verifyTrue(testCase,all(isfile(figureFiles)));
verifyEqual(testCase,artifact_names(matFiles),[ ...
    "IPM单步输出.mat";"IPM受控轨迹输出.mat"]);
verifyEqual(testCase,artifact_names(tableFiles),[ ...
    "IPM单步状态变化.csv";"IPM单步残差与步长.csv"; ...
    "IPM受控轨迹.csv";"IPM完整求解接口合同.csv"]);
verifyEqual(testCase,artifact_names(figureFiles),[ ...
    "IPM单步状态更新.fig";"IPM单步状态更新.png"; ...
    "IPM受控轨迹.fig";"IPM受控轨迹.png"]);
for pathValue = matFiles.'
    verifyEqual(testCase,string(who("-file",pathValue)),"moduleResult");
end

expectedStepFields = [ ...
    "state_before";"state_after";"state_before_fingerprint"; ...
    "state_after_fingerprint";"linearization_identity_before"; ...
    "linearization_identity_after";"official_recursive_direction"; ...
    "primal_step";"dual_step";"applied_step";"residuals"; ...
    "direction_audit";"fixed_zero";"soc";"permutation"; ...
    "checks";"all_pass";"formal_option_comparison"];
verifyEqual(testCase,sort(string(fieldnames(step.output))), ...
    sort(expectedStepFields));
verifyEqual(testCase,sort(string(fieldnames(solve.output))), ...
    sort(["controlledTrajectory";"solveContract"]));
verifyEqual(testCase,sort(string(fieldnames( ...
    step.output.official_recursive_direction))),sort([ ...
    "linearization_identity";"xi";"y";"l";"z";"is_official"; ...
    "no_full_direction_fallback";"full_direction_consumed"]));

forbidden = [ ...
    "linearization";"linearization_before";"linearization_after"; ...
    "recursive";"recursiveResult";"direct_audit";"fullResult"; ...
    "kkt";"assembly";"reduced";"partition";"dailyThomas"; ...
    "dailyResponses";"aggregation";"core";"projectData"; ...
    "data";"index";"config";"H";"A";"G";"saddle"];
verifyFalse(testCase,contains_forbidden_field(step,forbidden));
verifyFalse(testCase,contains_forbidden_field(solve,forbidden));
end

function testOutputsExplicitlyDeferFullSolveAndConvergence(testCase)
module = testCase.TestData.solveModule;
contract = module.output.solveContract;
verifyEqual(testCase,contract.controlled_preview_iteration_count,3);
verifyFalse(testCase,contract.full_ipm_executed);
verifyEqual(testCase,contract.full_ipm_iteration_count,0);
verifyFalse(testCase,contract.formal_run_context_created);
verifyFalse(testCase,contract.convergence_evaluated);
verifyFalse(testCase,contract.convergence_claimed);
verifyEqual(testCase,contract.solve_runtime_status, ...
    "DEFERRED_UNTIL_FORMAL_RUN");

contractPath = module.tableFiles(2);
tableValue = readtable(contractPath,"TextType","string", ...
    "VariableNamingRule","preserve");
verifyTrue(testCase,all(tableValue.runtimeStatus== ...
    "DEFERRED_UNTIL_FORMAL_RUN"));
verifyEqual(testCase,contract_text(tableValue, ...
    "controlled_preview_iteration_count"),"3");
verifyEqual(testCase,contract_text(tableValue, ...
    "full_ipm_executed"),"false");
verifyEqual(testCase,contract_text(tableValue, ...
    "formal_run_context_created"),"false");
verifyEqual(testCase,contract_text(tableValue, ...
    "convergence_evaluated"),"false");
verifyEqual(testCase,contract_text(tableValue, ...
    "convergence_claimed"),"false");
verifyEqual(testCase,contract_text(tableValue, ...
    "solve_runtime_status"),"DEFERRED_UNTIL_FORMAL_RUN");
verifyEqual(testCase,str2double(contract_text( ...
    tableValue,"max_iterations")),100);
verifyEqual(testCase,contract_text(tableValue, ...
    "convergence_coordinate"),"positive_scalar_unitized_kkt");
for field = [ ...
        "primal_equality_inf_tolerance"; ...
        "primal_inequality_inf_tolerance"; ...
        "dual_scaled_inf_tolerance"; ...
        "mean_lz_scaled_tolerance"; ...
        "physical_violation_tolerance"].'
    verifyEqual(testCase,str2double(contract_text( ...
        tableValue,field)),1e-8,"AbsTol",0);
end
verifyEqual(testCase,str2double(contract_text( ...
    tableValue,"centering_sigma")),0.1,"AbsTol",0);
verifyEqual(testCase,str2double(contract_text( ...
    tableValue,"fraction_to_boundary")),0.9995,"AbsTol",0);
verifyEqual(testCase,contract_text(tableValue,"step_strategy"), ...
    "independent");
verifyEqual(testCase,str2double(contract_text(tableValue, ...
    "recursive_refinement_max_passes")),3);
verifyEqual(testCase,contract_text(tableValue,"full_kkt_role"), ...
    "audit_only");
verifyEqual(testCase,contract_text(tableValue,"parallel_mode"),"off");
end

function testPkg7SourcesHaveNoCopiedAlgorithmsRunsOrFallbacks( ...
        testCase)
sourceRoot = testCase.TestData.sourceRoot;
facadeFiles = fullfile(sourceRoot,"+rkkt","+ipm", ...
    ["step.m";"solve.m"]);
validationFiles = fullfile(sourceRoot,"+rkkt","+ipm", ...
    "+validation",["ValidationSupport.m";"runStep.m";"runSolve.m"]);
allFiles = [facadeFiles;validationFiles];
forbiddenCalls = { ...
    '(?<![A-Za-z0-9_])initialize_stage_a4_state\s*\(', ...
    '(?<![A-Za-z0-9_])build_stage_a4_linearization\s*\(', ...
    '(?<![A-Za-z0-9_])solve_stage_a_multiday_recursive_direction\s*\(', ...
    '(?<![A-Za-z0-9_])solve_stage_a_multiday_full_kkt_direction\s*\(', ...
    '(?<![A-Za-z0-9_])verify_stage_a_multiday_direction_equivalence\s*\(', ...
    '(?<![A-Za-z0-9_])compute_fraction_to_boundary_step\s*\(', ...
    '(?<![A-Za-z0-9_])update_primal_dual_state\s*\(', ...
    '(?<![A-Za-z0-9_])(?:inv|pinv|lsqminnorm|full|mldivide|linsolve|ldl|decomposition)\s*\(', ...
    '(?m)^\s*parfor\b', ...
    '(?<![A-Za-z0-9_])(?:parpool|parfeval)\s*\(', ...
    '(?<![A-Za-z0-9_])create_run_context\s*\(', ...
    '(?<![A-Za-z0-9_])(?:mkdir|tempname|tempdir)\s*\(', ...
    '(?<![A-Za-z0-9_])(?:load_project_data|read_project_data|readmatrix|xlsread|spreadsheetDatastore)\s*\(', ...
    '(?<![A-Za-z0-9_])(?:generate_stage_a4_reports|create_run_manifest)\s*\(', ...
    '\bconfig(?:\.[A-Za-z]\w*)+\s*=(?!=)'};
for file = allFiles.'
    source = fileread(file);
    for pattern = forbiddenCalls
        verifyEmpty(testCase,regexp(source,pattern{1},"once"), ...
            "Forbidden source pattern in "+file+": "+pattern{1});
    end
end

stepSource = fileread(facadeFiles(1));
solveSource = fileread(facadeFiles(2));
verifyEqual(testCase,numel(regexp(stepSource, ...
    '(?<![A-Za-z0-9_])execute_stage_a4_iteration\s*\(',"match")),1);
verifyEqual(testCase,numel(regexp(solveSource, ...
    '(?<![A-Za-z0-9_])run_stage_a4_full_ipm\s*\(',"match")),1);
verifyEmpty(testCase,regexp(solveSource, ...
    '(?m)^\s*(?:for|while|parfor)\b',"once"));
verifyEmpty(testCase,regexp(solveSource, ...
    '(?m)^\s*(?:try|catch)\b',"once"));
verifyEmpty(testCase,regexp(solveSource,'(?i)\bfallback\b',"once"));
runSolveSource = fileread(validationFiles(3));
verifyNotEmpty(testCase,regexp(runSolveSource, ...
    '(?m)^\s*count\s*=\s*3\s*;',"once"));
verifyEmpty(testCase,regexp(runSolveSource, ...
    '(?m)^\s*(?:for|while)\b[^\r\n]*(?:max_iterations|1\s*:\s*100)', ...
    "once"));
end

function source = facade_source(testCase,name)
source = fileread(fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt","+ipm",string(name)+".m"));
end

function value = source_line_count(source)
value = numel(regexp(strtrim(source),'\r\n|\n|\r','split'));
end

function value = artifact_names(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    [~,name,extension] = fileparts(paths(k));
    value(k) = string(name)+string(extension);
end
end

function found = contains_forbidden_field(value,forbidden)
found = false;
if isstruct(value)
    names = string(fieldnames(value));
    if any(ismember(names,forbidden))
        found = true;
        return
    end
    for element = 1:numel(value)
        for name = names.'
            if contains_forbidden_field(value(element).(name),forbidden)
                found = true;
                return
            end
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        if contains_forbidden_field(value{k},forbidden)
            found = true;
            return
        end
    end
elseif istable(value)
    names = string(value.Properties.VariableNames);
    for name = names
        if contains_forbidden_field(value.(name),forbidden)
            found = true;
            return
        end
    end
end
end

function value = contract_text(tableValue,field)
row = tableValue(tableValue.contractField==field,:);
assert(height(row)==1, ...
    "PKG7:test:ContractField", ...
    "Expected one contract row for %s.",field);
value = string(row.contractValue);
end

function inventory = runs_inventory(repositoryRoot)
runsRoot = fullfile(repositoryRoot,"runs");
if ~isfolder(runsRoot)
    inventory = table(strings(0,1),false(0,1),zeros(0,1), ...
        zeros(0,1),'VariableNames', ...
        {'relativePath','isDirectory','bytes','modifiedTime'});
    return
end
listing = dir(fullfile(runsRoot,"**","*"));
countValue = numel(listing);
relativePath = strings(countValue,1);
isDirectory = false(countValue,1);
bytes = zeros(countValue,1);
modifiedTime = zeros(countValue,1);
prefix = string(runsRoot)+filesep;
for k = 1:countValue
    absolutePath = fullfile(string(listing(k).folder), ...
        string(listing(k).name));
    relativePath(k) = erase(absolutePath,prefix);
    isDirectory(k) = listing(k).isdir;
    bytes(k) = listing(k).bytes;
    modifiedTime(k) = listing(k).datenum;
end
inventory = sortrows(table(relativePath,isDirectory,bytes, ...
    modifiedTime),["relativePath";"isDirectory"]);
end
