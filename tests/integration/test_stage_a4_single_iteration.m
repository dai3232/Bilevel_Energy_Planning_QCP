function tests = test_stage_a4_single_iteration
%TEST_STAGE_A4_SINGLE_ITERATION Verify one complete A4-1 update closure.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
beforeRuns = top_level_run_inventory(projectRoot);
result = main_stage_A4_1();
afterRuns = top_level_run_inventory(projectRoot);
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.before_runs = beforeRuns;
testCase.TestData.after_runs = afterRuns;
end

function testCanonicalStateDimensionsAndStrictInterior(testCase)
result = testCase.TestData.result;
before = result.state_before;
after = result.state_after;
verifyEqual(testCase,numel(before.xi),3722);
verifyEqual(testCase,numel(before.y),618);
verifyEqual(testCase,numel(before.l),7248);
verifyEqual(testCase,numel(before.z),7248);
verifyEqual(testCase,result.linearization_before.counts.full_kkt,18836);
verifyTrue(testCase,all(isfinite([before.xi;before.y;before.l;before.z])));
verifyTrue(testCase,all(isfinite([after.xi;after.y;after.l;after.z])));
verifyGreaterThan(testCase,min(before.l),0);
verifyGreaterThan(testCase,min(before.z),0);
verifyGreaterThan(testCase,min(after.l),0);
verifyGreaterThan(testCase,min(after.z),0);
verifyEqual(testCase,before.iteration_index,0);
verifyEqual(testCase,before.state_revision,0);
verifyEqual(testCase,after.iteration_index,1);
verifyEqual(testCase,after.state_revision,1);
verifyNotEqual(testCase,result.linearization_before.identity, ...
    result.linearization_after.identity);
end

function testRecursiveDirectionPrecedesAndMatchesCompleteAudit(testCase)
result = testCase.TestData.result;
audit = result.direction_audit;
verifyLessThanOrEqual(testCase,audit.direction_relative_error,1e-10);
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual,1e-10);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase, ...
        audit.component_relative_errors.(name),1e-10);
end
verifyTrue(testCase,result.recursive.no_full_direction_fallback);
verifyFalse(testCase,result.recursive.full_direction_consumed);
verifyFalse(testCase, ...
    result.execution.full_kkt_direction_consumed_by_recursive);
verifyEqual(testCase,result.recursive.linearization_identity, ...
    result.linearization_before.identity);
verifyEqual(testCase,result.direct_audit.linearization_identity, ...
    result.linearization_before.identity);
end

function testFrozenFractionToBoundaryAndTightIndices(testCase)
result = testCase.TestData.result;
verifyGreaterThan(testCase,result.primal_step.alpha,0);
verifyLessThanOrEqual(testCase,result.primal_step.alpha,1);
verifyGreaterThan(testCase,result.dual_step.alpha,0);
verifyLessThanOrEqual(testCase,result.dual_step.alpha,1);
verifyEqual(testCase,result.primal_step.tau,0.9995,"AbsTol",0);
verifyEqual(testCase,result.dual_step.tau,0.9995,"AbsTol",0);
verify_tight_step(testCase,result.state_before.l, ...
    result.recursive.components.l,result.primal_step);
verify_tight_step(testCase,result.state_before.z, ...
    result.recursive.components.z,result.dual_step);
verifyEqual(testCase,result.state_after.xi, ...
    result.state_before.xi+result.primal_step.alpha* ...
    result.recursive.components.xi,"AbsTol",0);
verifyEqual(testCase,result.state_after.l, ...
    result.state_before.l+result.primal_step.alpha* ...
    result.recursive.components.l,"AbsTol",0);
verifyEqual(testCase,result.state_after.y, ...
    result.state_before.y+result.dual_step.alpha* ...
    result.recursive.components.y,"AbsTol",0);
verifyEqual(testCase,result.state_after.z, ...
    result.state_before.z+result.dual_step.alpha* ...
    result.recursive.components.z,"AbsTol",0);
end

function testResidualDefinitionsAndExplicitSlackAreExact(testCase)
result = testCase.TestData.result;
for lin = [result.linearization_before,result.linearization_after]
    verifyEqual(testCase,lin.r_eq, ...
        lin.A*lin.state.xi+lin.constraints.eq_offset,"AbsTol",0);
    inequalityFunction = lin.G*lin.state.xi+lin.constraints.ineq_offset;
    verifyEqual(testCase,lin.r_ineq,inequalityFunction+lin.state.l, ...
        "AbsTol",0);
    verifyEqual(testCase,lin.r_dual,lin.objective.gradient+ ...
        lin.A.'*lin.state.y+lin.G.'*lin.state.z,"AbsTol",0);
    verifyEqual(testCase,lin.r_comp,lin.state.l.*lin.state.z-lin.mu, ...
        "AbsTol",0);
    impliedSlack = -inequalityFunction;
    verifyEqual(testCase,lin.state.l-impliedSlack,lin.r_ineq, ...
        "AbsTol",0);
end
before = result.residuals.before;
after = result.residuals.after;
verifyEqual(testCase,before.complementarity_gap, ...
    mean(result.state_before.l.*result.state_before.z),"AbsTol",0);
verifyEqual(testCase,before.raw_complementarity, ...
    result.state_before.l.'*result.state_before.z,"AbsTol",0);
verifyEqual(testCase,before.mu,0.1*before.complementarity_gap,"AbsTol",0);
verifyEqual(testCase,after.complementarity_gap, ...
    mean(result.state_after.l.*result.state_after.z),"AbsTol",0);
verifyEqual(testCase,after.raw_complementarity, ...
    result.state_after.l.'*result.state_after.z,"AbsTol",0);
verifyEqual(testCase,after.mu,0.1*after.complementarity_gap,"AbsTol",0);
verifyGreaterThan(testCase,after.complementarity_gap,0);
verifyTrue(testCase,isfinite(after.complementarity_gap));
end

function testRebuiltLinearizationClosesOneUpdate(testCase)
closure = testCase.TestData.result.residuals.closure;
after = testCase.TestData.result.residuals.after;
verifyLessThanOrEqual(testCase,closure.slack_residual_scaled,256*eps);
verifyLessThanOrEqual(testCase, ...
    closure.equality_linear_update_relative_error,256*eps);
verifyLessThanOrEqual(testCase, ...
    closure.slack_linear_update_relative_error,2048*eps);
verifyLessThanOrEqual(testCase, ...
    closure.dual_linear_update_relative_error,256*eps);
verifyLessThanOrEqual(testCase, ...
    closure.equality_contraction_relative_error,256*eps);
verifyLessThanOrEqual(testCase, ...
    closure.dual_contraction_relative_error,256*eps);
verifyLessThanOrEqual(testCase, ...
    closure.slack_state_consistency_inf,16*eps);
verifyTrue(testCase,closure.model_matrices_unchanged);
verifyLessThanOrEqual(testCase,after.physical_inequality_violation, ...
    256*eps*after.physical_inequality_scale);
end

function testFormalDailySocAndFixedZerosRemainExact(testCase)
result = testCase.TestData.result;
verifyTrue(testCase,result.soc.passed);
verifyEqual(testCase,result.soc.initial_half_energy_link_count,14);
verifyEqual(testCase,result.soc.terminal_half_energy_link_count,14);
verifyEqual(testCase,result.soc.cross_day_or_nonadjacent_link_count,0);

before = result.linearization_before;
after = result.linearization_after;
variables = after.index.variable_index;
equalities = after.index.constraint_index( ...
    string(after.index.constraint_index.constraint_type)=="equality",:);
socColumns = variables.global_index_start( ...
    string(variables.variable_name)=="SOC");
verifyFalse(testCase,any(variables.hour==0 & ...
    string(variables.variable_name)=="SOC"));
verifyEqual(testCase,after.A,before.A);
for dayPosition = 1:numel(result.config.days)
    day = result.config.days(dayPosition);
    for storage = 1:2
        startRow = find(equalities.day==day & equalities.hour==1 & ...
            string(equalities.constraint_name)=="soc_dynamics" & ...
            equalities.asset_id==storage);
        terminalRow = find(equalities.day==day & equalities.hour==24 & ...
            string(equalities.constraint_name)=="terminal_soc" & ...
            equalities.asset_id==storage);
        verifyEqual(testCase,numel(startRow),1);
        verifyEqual(testCase,numel(terminalRow),1);

        qEnergy = after.maps.q_day(12+storage,dayPosition);
        pch = locate_state_variable(variables,day,1, ...
            "storage",storage,"Pch");
        pdis = locate_state_variable(variables,day,1, ...
            "storage",storage,"Pdis");
        soc1 = locate_state_variable(variables,day,1, ...
            "storage",storage,"SOC");
        soc24 = locate_state_variable(variables,day,24, ...
            "storage",storage,"SOC");
        expectedStart = [1, ...
            -after.capacity_parameters.charge_efficiency(storage), ...
            1/after.capacity_parameters.discharge_efficiency(storage), ...
            -0.5];
        verifyEqual(testCase,full(after.A(startRow, ...
            [soc1,pch,pdis,qEnergy])),expectedStart,"AbsTol",0);
        verifyEqual(testCase,full(after.A(terminalRow, ...
            [soc24,qEnergy])),[1,-0.5],"AbsTol",0);

        startSocColumns = socColumns( ...
            full(after.A(startRow,socColumns))~=0);
        terminalSocColumns = socColumns( ...
            full(after.A(terminalRow,socColumns))~=0);
        verifyEqual(testCase,startSocColumns,soc1);
        verifyEqual(testCase,terminalSocColumns,soc24);

        verify_soc_boundary_row_update(testCase,before,after,startRow, ...
            result.recursive.components.xi,result.primal_step.alpha);
        verify_soc_boundary_row_update(testCase,before,after,terminalRow, ...
            result.recursive.components.xi,result.primal_step.alpha);

        terminalExpression = after.state.xi(soc24) - ...
            0.5*after.state.xi(qEnergy);
        terminalScale = max([1,abs(after.state.xi(soc24)), ...
            0.5*abs(after.state.xi(qEnergy))]);
        verifyLessThanOrEqual(testCase, ...
            abs(terminalExpression-after.r_eq(terminalRow)), ...
            16*eps*terminalScale);
        verifyLessThanOrEqual(testCase,abs(after.r_eq(terminalRow)), ...
            512*eps*terminalScale);
    end
end

verifyEqual(testCase,result.fixed_zero.count,422);
verifyTrue(testCase,result.fixed_zero.values_exact_zero_before);
verifyTrue(testCase,result.fixed_zero.values_exact_zero_after);
verifyTrue(testCase,result.fixed_zero.directions_exact_zero);
verifyEqual(testCase,result.fixed_zero.maximum_absolute_value_after,0);
verifyEqual(testCase,result.fixed_zero.maximum_absolute_direction,0);
end

function testRecursivePermutationRemains4340NonidentityBijection(testCase)
permutation = testCase.TestData.result.permutation;
verifyEqual(testCase,permutation.dimension,4340);
verifyTrue(testCase,permutation.is_bijection);
verifyTrue(testCase,permutation.is_nonidentity);
verifyTrue(testCase,permutation.forward_inverse_composition_exact);
verifyTrue(testCase,permutation.inverse_forward_composition_exact);
end

function testMilestoneDoesNotCreateFormalRunOrAdvanceStage(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyEqual(testCase,result.milestone_status,"PASS");
verifyEqual(testCase,result.execution.newton_direction_count,1);
verifyEqual(testCase,result.execution.state_update_count,1);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyEqual(testCase,testCase.TestData.after_runs, ...
    testCase.TestData.before_runs);
currentStage = fileread(fullfile(testCase.TestData.project_root, ...
    "CURRENT_STAGE.md"));
verifyTrue(testCase,contains(currentStage,"`stage_id`: `stage_A4`"));
verifyTrue(testCase,contains(currentStage,"`status`: `READY`"));
end

function testForbiddenOptionsRemainDisabled(testCase)
config = testCase.TestData.result.config;
verifyFalse(testCase,config.linear_algebra.explicit_inverse);
verifyFalse(testCase,config.linear_algebra.pseudoinverse);
verifyFalse(testCase,config.linear_algebra.least_norm_fallback);
verifyFalse(testCase,config.linear_algebra.recursive_fallback_to_full_kkt);
verifyFalse(testCase,config.linear_algebra.automatic_regularization);
verifyFalse(testCase,config.linear_algebra.automatic_symmetrization);
verifyFalse(testCase,config.water_constraints_enabled);
verifyFalse(testCase,config.thermal_second_pass_enabled);
verifyFalse(testCase,config.annual_multiobjective_enabled);
verifyEqual(testCase,config.parallel_mode,"off");

audit = scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,config);
expectedCheckIds = [ ...
    "NO-INV"
    "NO-PINV"
    "NO-LSQMINNORM"
    "NO-NEGATIVE-MATRIX-POWER"
    "NO-RANDOM"
    "NO-PARALLEL-CALL"
    "NO-DYNAMIC-INVOCATION"
    "NO-FILESYSTEM-MUTATION"
    "NO-LINE-SEARCH"
    "NO-REGULARIZATION-HELPER"
    "NO-SYMMETRIZATION-HELPER"
    "NO-LARGE-FULL-CONVERSION"
    "NO-PREDICTOR-CORRECTOR"
    "NO-A42B-ADDITIONAL-DENSE-CONDITION-NUMBER"
    "NO-A42C-ADDITIONAL-DENSE-CONDITION-NUMBER"
    "NO-A42D1-ADDITIONAL-DENSE-CONDITION-NUMBER"
    "NO-A42D2A-ADDITIONAL-DENSE-CONDITION-NUMBER"
    "NO-A42D1-AUDIT-SOLVER-OR-STATE-UPDATE"
    "NO-A42D1R-REFACTOR-DIRECT-SOLVE-OR-STATE-UPDATE"
    "NO-A42D1-STAGE-B-DEPENDENCY"
    "NO-A42D2A-STAGE-B-DEPENDENCY"
    "A42D2A-OBJECTIVE-SCALE-DEFAULT-OFF"
    "NO-RECURSIVE-FULL-DIRECTION-FALLBACK"
    "AUTOMATIC-REGULARIZATION-DISABLED"
    "AUTOMATIC-SYMMETRIZATION-DISABLED"
    "PARALLEL-MODE-OFF"];
verifyEqual(testCase,string(audit.check_id),expectedCheckIds);
verifyEqual(testCase,string(audit.status), ...
    repmat("PASS",numel(expectedCheckIds),1), ...
    evalc('disp(audit(audit.status~="PASS",:))'));
verifyGreaterThan(testCase,min(audit.files_scanned),0);
verifyFalse(testCase,any(contains(lower(audit.matched_files), ...
    ["tests/","runs/"])));
end

function verify_tight_step(testCase,values,direction,step)
negative = find(direction<0);
verifyNotEmpty(testCase,negative);
[raw,local] = min(-values(negative)./direction(negative));
verifyEqual(testCase,step.raw_boundary_step,raw,"AbsTol",0);
verifyEqual(testCase,step.limiting_index,negative(local));
verifyEqual(testCase,step.alpha,min(1,step.tau*raw),"AbsTol",0);
end

function globalIndex = locate_state_variable(variables,day,hour, ...
        assetType,assetId,variableName)
mask = variables.day==day & variables.hour==hour & ...
    string(variables.asset_type)==string(assetType) & ...
    variables.asset_id==assetId & ...
    string(variables.variable_name)==string(variableName);
assert(nnz(mask)==1, ...
    "stageA4:test:SocVariableLookup", ...
    "Expected one %s variable for day %d hour %d storage %d.", ...
    variableName,day,hour,assetId);
globalIndex = variables.global_index_start(mask);
end

function verify_soc_boundary_row_update(testCase,before,after,row, ...
        direction,alphaPrimal)
expectedLinear = before.r_eq(row) + ...
    alphaPrimal*(before.A(row,:)*direction);
expectedContraction = (1-alphaPrimal)*before.r_eq(row);
scale = max([1,abs(after.r_eq(row)),abs(expectedLinear), ...
    abs(expectedContraction)]);
verifyLessThanOrEqual(testCase, ...
    abs(after.r_eq(row)-expectedLinear),512*eps*scale);
verifyLessThanOrEqual(testCase, ...
    abs(after.r_eq(row)-expectedContraction),512*eps*scale);
end

function inventory = top_level_run_inventory(projectRoot)
entries = dir(fullfile(projectRoot,"runs"));
entries = entries(~ismember(string({entries.name}),[".",".."])) ;
names = string({entries.name}).';
isDirectory = [entries.isdir].';
bytes = [entries.bytes].';
[names,order] = sort(names);
inventory = table(names,isDirectory(order),bytes(order), ...
    'VariableNames',{'name','is_directory','bytes'});
end
