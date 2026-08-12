function tests = test_stage_b2c_formal_ipm
%TEST_STAGE_B2C_FORMAL_IPM Fixed B-2C gate, update, and governance tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
config = rkkt.model.load_stage_b2c_configuration(root);
data = rkkt.data.load_project_data(root);
index = rkkt.indexing.build_stage_b2c_index(data,config,"RunId","B2C_FIXED_TEST");
gate = rkkt.diagnostics.run_stage_b2c_nonzero_hessian_gate(data,index,config);
state = rkkt.model.initialize_stage_b2c_state(data,index,config);
step = rkkt.diagnostics.execute_stage_b2c_iteration(state,data,index,config);
testRoot = string(tempname(tempdir));
mkdir(testRoot); mkdir(fullfile(testRoot,"checkpoints"));
context = struct("checkpoints_dir",fullfile(testRoot,"checkpoints"), ...
    "checkpoint_manifest_path",fullfile(testRoot,"checkpoints", ...
        "checkpoint_manifest.csv"));
metadata = struct("iteration",0,"git_commit","TEST", ...
    "config_sha256",repmat('0',1,64), ...
    "input_hash_fingerprint",repmat('1',1,64));
rkkt.artifacts.write_stage_b2c_checkpoint(context,state, ...
    rkkt.model.build_stage_b2c_scaled_objective_linearization( ...
        state,data,index,config),metadata);
metadata.iteration = 1;
rkkt.artifacts.write_stage_b2c_checkpoint(context,step.state_after, ...
    step.linearization_after,metadata);
testCase.TestData.root = root;
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.gate = gate;
testCase.TestData.state = state;
testCase.TestData.step = step;
testCase.TestData.context = context;
testCase.TestData.test_root = testRoot;
end

function teardownOnce(testCase)
if isfield(testCase.TestData,"test_root")
    pathValue = testCase.TestData.test_root;
    if isfolder(pathValue), rmdir(pathValue,"s"); end
end
end

function testConfigurationFreezesFormalSevenDayScope(testCase)
c = testCase.TestData.config;
verifyEqual(testCase,c.days,14:20);
verifyEqual(testCase,c.hours,1:24);
verifyEqual(testCase,c.max_iterations,100);
verifyEqual(testCase,c.step_strategy,"independent");
verifyEqual(testCase,c.recursive_route, ...
    "all_inequality_daily_joint_final_kkt_residual_gate");
verifyEqual(testCase,c.recursive_refinement_max_passes,0);
verifyTrue(testCase,c.recursive_congruence_scaling_enabled);
verifyEqual(testCase,c.equilibration_passes,0);
verifyEqual(testCase,c.local_response_residual_policy, ...
    "diagnostic_nonblocking");
verifyEqual(testCase,c.direction_acceptance_policy, ...
    "final_reconstructed_kkt_residual");
verifyEqual(testCase,c.expected_rhs_per_day,15);
verifyEqual(testCase,c.expected_water_border_dimension_per_day,0);
verifyEqual(testCase,c.expected_daily_joint_dimensions, ...
    [617,618,617,618,618,618,618]);
end

function testNonzeroWaterHessianGatePasses(testCase)
g = testCase.TestData.gate;
verifyTrue(testCase,g.passed);
verifyEqual(testCase,g.water_hessian_nnz,672);
verifyGreaterThan(testCase,g.water_hessian_fro_norm,0);
verifyLessThanOrEqual(testCase,g.water_hessian_symmetry_relative,1e-12);
end

function testWaterHessianSupportAndSignsAreTraceable(testCase)
g = testCase.TestData.gate;
verifyTrue(testCase,g.support_audit.sign_correct);
verifyTrue(testCase,g.support_audit.support_correct);
verifyEqual(testCase,g.support_audit.expected_difference_nnz,0);
end

function testNonzeroHessianDirectionsAreEquivalent(testCase)
a = testCase.TestData.gate.comparison;
verifyLessThanOrEqual(testCase,a.direction_relative_error,1e-10);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase,a.component_relative_errors.(name),1e-10);
end
verifyLessThanOrEqual(testCase,a.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase,a.full_kkt_relative_residual,1e-10);
end

function testSingleStepUsesIndependentPrimalAndDualUpdates(testCase)
s = testCase.TestData.step;
verifyLessThanOrEqual(testCase,max(s.update_relative_errors),16*eps);
verifyLessThanOrEqual(testCase, ...
    max(s.ordinary_state_update_relative_errors),16*eps);
ordinary = rkkt.solver.update_primal_dual_state(s.state_before, ...
    s.recursive.components,s.primal_step.alpha,s.dual_step.alpha);
waterRows = s.water_slack_second_order_correction.water_rows;
nonwater = true(numel(s.state_after.l),1); nonwater(waterRows)=false;
verifyEqual(testCase,s.state_after.xi,s.state_before.xi+ ...
    s.primal_step.alpha*s.recursive.components.xi,"AbsTol",0);
verifyEqual(testCase,s.state_after.l(nonwater),ordinary.l(nonwater), ...
    "AbsTol",0);
verifyEqual(testCase,s.state_after.l(waterRows),ordinary.l(waterRows)- ...
    s.water_slack_second_order_correction.correction_fraction* ...
    s.water_slack_second_order_correction.second_order_remainder, ...
    "AbsTol",0);
verifyEqual(testCase,s.state_after.y,s.state_before.y+ ...
    s.dual_step.alpha*s.recursive.components.y,"AbsTol",0);
verifyEqual(testCase,s.state_after.z,s.state_before.z+ ...
    s.dual_step.alpha*s.recursive.components.z,"AbsTol",0);
verifyTrue(testCase,s.water_slack_second_order_correction_applied);
verifyEqual(testCase,s.water_slack_second_order_correction_scope_count,56);
verifyTrue(testCase,s.only_water_slacks_corrected);
verifyGreaterThan(testCase, ...
    s.water_slack_second_order_correction.correction_fraction,0);
verifyLessThan(testCase, ...
    s.water_slack_second_order_correction.correction_fraction,1);
verifyTrue(testCase, ...
    s.water_slack_second_order_correction.correction_fraction_limited);
verifyFalse(testCase, ...
    s.water_slack_second_order_correction. ...
        full_correction_centrality_safe);
verifyFalse(testCase, ...
    s.water_slack_second_order_correction.full_correction_feasible);
verifyLessThan(testCase, ...
    s.water_slack_second_order_correction. ...
        minimum_full_correction_candidate_l,0);
verifyGreaterThan(testCase, ...
    s.water_slack_second_order_correction.minimum_corrected_l,0);
verifyGreaterThanOrEqual(testCase, ...
    s.water_slack_second_order_correction. ...
        minimum_corrected_to_trial_slack_ratio, ...
    testCase.TestData.config.centering_sigma);
verifyLessThanOrEqual(testCase,s.water_residual_rebuild_closure,1e-10);
end

function testWaterHessianIsRebuiltFromCurrentMultiplier(testCase)
state = testCase.TestData.state;
index = testCase.TestData.index;
data = testCase.TestData.data;
config = testCase.TestData.config;
base = rkkt.model.build_stage_b2c_multiday_linearization(state,data,index,config);
row = index.water_constraint_index.inequality_position(1);
record = base.constraints.water.constraint_hessians(1);
changed = state; changed.z(row)=changed.z(row)+0.25;
rebuilt = rkkt.model.build_stage_b2c_multiday_linearization( ...
    changed,data,index,config);
verifyEqual(testCase,rebuilt.H-base.H, ...
    0.25*record.global_hessian,"AbsTol",0);
end

function testEachRecursivePassUsesOnePivotedDayFactor(testCase)
r = testCase.TestData.step.recursive.responses;
verifyEqual(testCase,numel(r),7);
for d = 1:7
    verifyEqual(testCase,r(d).rhs_count,15);
    verifyEqual(testCase,r(d).factor.factorization_count,1);
    verifyEqual(testCase,r(d).factor.method,"sparse_pivoted_ldl");
    verifyFalse(testCase,r(d).factor.warning_present);
    verifyTrue(testCase,r(d).factor.solution_finite);
    verifyEqual(testCase,r(d).factor.acceptance_scope, ...
        "final_reconstructed_kkt_residual");
    verifyEqual(testCase,r(d).response_contract, ...
        "u_day=a-U*[delta_q;delta_rho]");
end
s = testCase.TestData.step.recursive;
verifyEqual(testCase,s.core.dimension,16);
verifyEqual(testCase,s.core.factor.factorization_count,1);
verifyFalse(testCase,s.core.factor.warning_present);
verifyTrue(testCase,s.core.factor.solution_finite);
verifyEqual(testCase,s.partition.water_eta_dimension,0);
verifyTrue(testCase,s.partition.full_inequality_elimination);
verifyEqual(testCase,s.diagnostics.daily_dimensions, ...
    testCase.TestData.config.expected_daily_joint_dimensions);
verifyTrue(testCase,s.diagnostics.final_kkt_residual_gate_passed);
verifyFalse(testCase,s.diagnostics.local_response_residual_is_blocking);
end

function testNoFactorOrLinearizationReuseAcrossIterations(testCase)
s = testCase.TestData.step;
verifyNotEqual(testCase,string(s.linearization_before.identity), ...
    string(s.linearization_after.identity));
verifyFalse(testCase,s.factor_reused_across_iterations);
verifyEqual(testCase,s.factorization_scope_identity, ...
    s.linearization_before.identity);
end

function testStrictSlackAndMultiplierPositivity(testCase)
s = testCase.TestData.step;
verifyGreaterThan(testCase,min(s.state_before.l),0);
verifyGreaterThan(testCase,min(s.state_before.z),0);
verifyGreaterThan(testCase,min(s.state_after.l),0);
verifyGreaterThan(testCase,min(s.state_after.z),0);
end

function testExactlyFourStoppingCriteria(testCase)
c = testCase.TestData.config;
m = struct("primal_equality_inf",1e-6, ...
    "primal_inequality_inf",1e-6,"dual_scaled_inf",1e-6, ...
    "mean_lz_scaled",1e-6);
verifyTrue(testCase,rkkt.diagnostics.stage_b2c_convergence_passed(m,c));
for name = string(fieldnames(m)).'
    changed=m; changed.(name)=1.0000001e-6;
    verifyFalse(testCase,rkkt.diagnostics.stage_b2c_convergence_passed(changed,c));
end
end

function testMaximumIterationLimitIsFrozen(testCase)
c = testCase.TestData.config;
verifyEqual(testCase,c.max_iterations,100);
verifyEqual(testCase,c.primal_equality_inf_tolerance,1e-6);
verifyEqual(testCase,c.primal_inequality_inf_tolerance,1e-6);
verifyEqual(testCase,c.dual_scaled_inf_tolerance,1e-6);
verifyEqual(testCase,c.mean_lz_scaled_tolerance,1e-6);
end

function testCheckpointChainAndReplayAreDeterministic(testCase)
context = testCase.TestData.context;
[initial,record0] = rkkt.artifacts.load_stage_b2c_checkpoint(context,0);
[accepted,record1] = rkkt.artifacts.load_stage_b2c_checkpoint(context,1);
verifyEqual(testCase,string(record1.previous_checkpoint_sha256), ...
    string(record0.sha256));
replayed = rkkt.diagnostics.execute_stage_b2c_iteration(initial.state, ...
    testCase.TestData.data,testCase.TestData.index,testCase.TestData.config);
verifyTrue(testCase,isequaln(replayed.state_after,accepted.state));
verifyTrue(testCase,isequaln(replayed.state_after, ...
    testCase.TestData.step.state_after));
end

function testFinalPhysicalAuditHasTwentyEightIndependentRows(testCase)
s = testCase.TestData.step;
history = table(s.fixed_zero.maximum_absolute_direction, ...
    'VariableNames',{'fixed_zero_maximum_absolute_direction'});
fake = struct("convergence_achieved",true, ...
    "run_terminal_state","CONVERGED","final_state",s.state_after, ...
    "final_linearization",s.linearization_after, ...
    "iteration_history",history);
a = rkkt.diagnostics.evaluate_stage_b2c_physical_audit(fake,testCase.TestData.index, ...
    testCase.TestData.data,testCase.TestData.config);
verifyEqual(testCase,height(a.water),28);
verifyEqual(testCase,a.water.day,repelem((14:20).',4));
verifyTrue(testCase,all(a.water.physical_source=="final_unscaled_PH"));
verifyTrue(testCase,a.no_cross_day_water_accumulation);
end

function testFullDirectionIsAuditOnlyAndNeverConsumed(testCase)
s = testCase.TestData.step;
verifyTrue(testCase,s.recursive_direction_is_formal);
verifyTrue(testCase,s.no_full_direction_fallback);
verifyFalse(testCase,s.full_direction_consumed_by_recursive);
verifyEqual(testCase,s.recursive.linearization_identity, ...
    s.full_audit.linearization_identity);
verifyEqual(testCase,s.full_audit.method, ...
    "independent_global_saddle_extended_refinement_audit_only");
verifyTrue(testCase, ...
    s.full_audit.diagnostics.equation_preserving_scaling_used);
verifyFalse(testCase,s.full_audit.diagnostics. ...
    independent_reduced_audit.recursive_partition_consumed);
end

function testForbiddenAlgorithmFactorsRemainDisabled(testCase)
c = testCase.TestData.config;
verifyFalse(testCase,c.common_step_enabled);
verifyFalse(testCase,c.dynamic_sigma_enabled);
verifyFalse(testCase,c.predictor_corrector_enabled);
verifyFalse(testCase,c.line_search_enabled);
verifyFalse(testCase,c.regularization_enabled);
verifyFalse(testCase,c.automatic_symmetrization_enabled);
verifyFalse(testCase,c.parallel_enabled);
verifyFalse(testCase,c.full_kkt_direction_fallback_enabled);
end

function testStageAndExecutionBoundariesRemainFrozen(testCase)
c = testCase.TestData.config;
verifyFalse(testCase,c.annual_scope_enabled);
verifyFalse(testCase,c.thermal_second_pass_enabled);
verifyFalse(testCase,c.stage_c1_implemented);
verifyTrue(testCase,c.water_constraints_enabled);
verifyEqual(testCase,string(c.current_stage.stage_id),"stage_B");
verifyEqual(testCase,string(c.current_stage.status),"READY");
end

function testWaterStationarityFiniteDifferenceMatchesCurrentHessian(testCase)
g = testCase.TestData.gate;
state = g.state; index=testCase.TestData.index;
variables=index.variable_index;
mask=string(variables.asset_type)=="hydro" & variables.hour>0;
direction=zeros(size(state.xi));
direction(mask)=sin((1:nnz(mask)).')/sqrt(nnz(mask));
h=1e-4; plus=state; minus=state;
plus.xi=state.xi+h*direction; minus.xi=state.xi-h*direction;
lp=rkkt.model.build_stage_b2c_scaled_objective_linearization(plus, ...
    testCase.TestData.data,index,testCase.TestData.config,"FD_PLUS");
lm=rkkt.model.build_stage_b2c_scaled_objective_linearization(minus, ...
    testCase.TestData.data,index,testCase.TestData.config,"FD_MINUS");
finite=(lp.r_dual-lm.r_dual)/(2*h);
analytic=g.linearization.H*direction;
relative=norm(finite-analytic,2)/max(1,norm(analytic,2));
verifyLessThanOrEqual(testCase,relative, ...
    testCase.TestData.config.stationarity_finite_difference_tolerance);
end

function testPivotedDayFactorSolvesAllColumnsJointly(testCase)
r = testCase.TestData.step.recursive.responses;
for d = 1:7
    verifyEqual(testCase,r(d).factor.rhs_count,15);
    verifyEqual(testCase,r(d).factor.factorization_count,1);
    verifyTrue(testCase,isfinite( ...
        r(d).factor.maximum_column_relative_residual));
    verifyEqual(testCase,r(d).factor.local_residual_target_met, ...
        r(d).factor.maximum_column_relative_residual<= ...
        testCase.TestData.config.recursive_full_kkt_residual_tolerance);
end
verifyLessThanOrEqual(testCase, ...
    testCase.TestData.step.recursive.diagnostics. ...
        candidate_kkt_relative_residual, ...
    testCase.TestData.config.recursive_full_kkt_residual_tolerance);
verifyLessThanOrEqual(testCase, ...
    testCase.TestData.step.direction_audit.recursive_kkt_relative_residual, ...
    testCase.TestData.config.recursive_full_kkt_residual_tolerance);
end
