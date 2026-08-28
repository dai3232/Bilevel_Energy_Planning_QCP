function tests = test_stage_b2c_checkpoint13_joint_microborder_detection
% Historical checkpoint13 regression for automatic day/hour detection.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
sourceRoot = fullfile(root,"runs", ...
    "B2C_90DAY_ADAPTIVE_DELAYED_INEQ_FORMAL_20260820_112344");
required = [ ...
    fullfile(sourceRoot,"diagnostics","resolved_runtime_configuration.mat")
    fullfile(sourceRoot,"diagnostics","cache_summary.csv")
    fullfile(sourceRoot,"checkpoints","checkpoint_manifest.csv")];
assumeTrue(testCase,all(isfile(required)), ...
    "The checkpoint13 regression artifacts are unavailable.");
runtime = load(required(1),"config");
config = runtime.config;
cacheSummary = readtable(required(2),"TextType","string", ...
    "VariableNamingRule","preserve","Delimiter",",");
dataPath = unique(cacheSummary.path(cacheSummary.cache_type=="annual_data"));
indexPath = unique(cacheSummary.path( ...
    cacheSummary.cache_type=="canonical_index"));
assumeTrue(testCase,isscalar(dataPath) && isfile(dataPath) && ...
    isscalar(indexPath) && isfile(indexPath), ...
    "The checkpoint13 input caches are unavailable.");
dataPayload = load(dataPath,"data");
indexPayload = load(indexPath,"index");
context = struct( ...
    "checkpoints_dir",fullfile(sourceRoot,"checkpoints"), ...
    "checkpoint_manifest_path",required(3));
checkpoint = rkkt.artifacts.load_stage_b2c_checkpoint(context,13);
lin = rkkt.model.build_stage_b2c_scaled_objective_linearization( ...
    checkpoint.state,dataPayload.data,indexPayload.index,config, ...
    "CP13-JOINT-MICROBORDER-DETECTION");
reduced = rkkt.solver.eliminate_stage_b2c_all_inequality_directions(lin);
partition = rkkt.solver.partition_stage_b2c_daily_joint_system(lin,reduced);
responses = cell(numel(partition.day),1);
retained = cell(numel(partition.day),1);
for d = 1:numel(partition.day)
    [responses{d},retained{d}] = ...
        rkkt.solver.solve_stage_b2c_daily_joint_day( ...
            partition.day(d), ...
            SymmetryTolerance=config.reduced_symmetry_tolerance, ...
            ResidualTolerance=config.local_linear_solve_residual_tolerance, ...
            RefinementPasses=config.recursive_refinement_max_passes);
end
responses = vertcat(responses{:});
problemPositions = find(arrayfun(@(value) ...
    value.factor.maximum_column_relative_residual> ...
        config.local_linear_solve_residual_tolerance,responses));
candidate = rkkt.solver.detect_stage_b2c_joint_microborder( ...
    lin,partition,responses,retained,problemPositions, ...
    RelationResidualTolerance=1e-12);
preemptive = rkkt.solver.detect_stage_b2c_joint_microborder( ...
    lin,partition,repmat(struct(),0,1),cell(0,1),zeros(0,1), ...
    PreemptiveActiveSetDetection=true,DegeneracyTolerance=1e-12, ...
    RelationResidualTolerance=1e-12);
testCase.TestData.candidate = candidate;
testCase.TestData.preemptive = preemptive;
testCase.TestData.problem_positions = problemPositions;
testCase.TestData.responses = responses;
linearizationTemplate = rkkt.model.build_stage_b2c_linearization_template( ...
    lin,dataPayload.data,indexPayload.index,config);
step = rkkt.diagnostics.execute_stage_b2c_iteration( ...
    checkpoint.state,dataPayload.data,indexPayload.index,config, ...
    FullKktAuditEnabled=false,PrecomputedLinearization=lin, ...
    LinearizationTemplate=linearizationTemplate, ...
    LinearizationUpdateMode="cached_numeric");
recursive = step.recursive;
testCase.TestData.recursive = recursive;
testCase.TestData.step = step;
testCase.TestData.config = config;
end

function testPreemptiveDetectorAvoidsASecondProblemDayFactor(testCase)
candidate = testCase.TestData.preemptive;
verifyTrue(testCase,candidate.used);
verifyEqual(testCase,candidate.day_id,62);
verifyEqual(testCase,candidate.relation_hours,(1:5).');
verifyEqual(testCase,candidate.candidate_count_below_tolerance,1);
verifyLessThanOrEqual(testCase,candidate.normalized_joint_d,1e-12);
verifyLessThanOrEqual(testCase,candidate.relation_residual,1e-12);
verifyEqual(testCase,candidate.detection_method,"active_set_joint_d");
end

function testFormalDirectionUsesOneFactorPerDayAndPasses(testCase)
r = testCase.TestData.recursive;
config = testCase.TestData.config;
verifyTrue(testCase,r.diagnostics.joint_microborder_used);
verifyEqual(testCase,r.diagnostics.joint_microborder_day_ids,62);
verifyFalse(testCase, ...
    r.diagnostics.adaptive_delayed_inequality_elimination_used);
verifyEqual(testCase,r.core.dimension,17);
verifyEqual(testCase,r.core.factor.method,"vpa50_small_core_backslash");
requiredCoreFactorFields = ["object_type","dimension","rhs_count", ...
    "minimum_absolute_pivot_eigenvalue","pivot_tolerance", ...
    "inertia_zero","maximum_column_relative_residual", ...
    "initial_maximum_column_relative_residual","refinement_enabled", ...
    "refinement_triggered","refinement_maximum_passes", ...
    "refinement_passes_applied","warning_continued"];
verifyTrue(testCase,all(isfield(r.core.factor,cellstr(requiredCoreFactorFields))));
verifyEqual(testCase,r.core.factor.object_type,"joint_microborder_core_17");
verifyEqual(testCase,r.core.factor.dimension,17);
verifyEqual(testCase,size(r.core.matrix_high),[17,17]);
verifyEqual(testCase,size(r.core.matrix_low),[17,17]);
problemPosition = find([r.responses.day_id]==62,1);
verifyNotEmpty(testCase,problemPosition);
problem = r.responses(problemPosition);
verifyEqual(testCase,size(problem.U,2),16);
verifyEqual(testCase,size(problem.border_response),[problem.dimension,1]);
verifyEqual(testCase,problem.core_solution_dimension,17);
verifyEqual(testCase,problem.recovery_contract, ...
    "u_day=a-U*core_solution(1:16)-border_response*core_solution(17); " + ...
    "retained_LDL_corrects_only_if_residual_fails");
verifyEqual(testCase,r.diagnostics.daily_factorization_counts, ...
    ones(size(r.diagnostics.daily_factorization_counts)));
verifyTrue(testCase,r.diagnostics.daily_affine_response_recovery_used);
verifyEqual(testCase, ...
    r.diagnostics.daily_recovery_additional_factorization_count,0);
verifyLessThanOrEqual(testCase, ...
    r.diagnostics.daily_recovery_maximum_relative_residual, ...
    config.local_linear_solve_residual_tolerance);
verifyLessThanOrEqual(testCase, ...
    r.diagnostics.candidate_kkt_relative_residual, ...
    config.recursive_full_kkt_residual_tolerance);
verifyTrue(testCase,r.core.direct_daily_correction.both_targets_met);
verifyFalse(testCase,r.regularization_used);
verifyFalse(testCase,r.pseudoinverse_used);
verifyTrue(testCase,r.no_full_direction_fallback);
verifyFalse(testCase,r.full_direction_consumed);
step = testCase.TestData.step;
verifyTrue(testCase,step.high_low_state_update_required);
verifyTrue(testCase,step.high_low_state_update_used);
verifyTrue(testCase,step.state_update_audit.high_low_direction_consumed);
verifyTrue(testCase,step.primal_step.high_low_direction_consumed);
verifyTrue(testCase,step.dual_step.high_low_direction_consumed);
verifyTrue(testCase, ...
    step.water_slack_second_order_correction. ...
        accepted_primal_displacement_used);
verifyEqual(testCase,step.water_slack_second_order_correction. ...
    linear_increment_source,"accepted_state_displacement_high_low");
verifyTrue(testCase,step.fixed_linearization_structure_reused);
verifyEqual(testCase,step.state_after.state_revision,14);
verifyGreaterThan(testCase,min(step.state_after.l),0);
verifyGreaterThan(testCase,min(step.state_after.z),0);
end

function testHistoricalProblemDayAndWindowAreInferred(testCase)
candidate = testCase.TestData.candidate;
verifyTrue(testCase,candidate.used);
verifyEqual(testCase,numel(testCase.TestData.problem_positions),1);
verifyEqual(testCase,candidate.day_id,62);
verifyEqual(testCase,candidate.relation_hours,(1:5).');
verifyLessThanOrEqual(testCase,candidate.primal_fraction,1e-8);
verifyGreaterThanOrEqual(testCase,candidate.mode_alignment,1-1e-6);
verifyLessThanOrEqual(testCase,candidate.relation_residual,1e-12);
verifyFalse(testCase,candidate.rank_truncation_used);
verifyFalse(testCase,candidate.model_changed);
end
