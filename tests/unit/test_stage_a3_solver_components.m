function tests = test_stage_a3_solver_components
%TEST_STAGE_A3_SOLVER_COMPONENTS Audit seven serial daily responses.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a3_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a3_index(data,"RunId","A3_SOLVER_COMPONENT_TEST");
state = initialize_stage_a3_state(data,index,config);
linearization = build_stage_a3_linearization(state,data,index,config);
recursive = solve_stage_a3_recursive_direction(linearization, ...
    AssemblyTolerance=1e-12, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
testCase.TestData.project_root = projectRoot;
testCase.TestData.config = config;
testCase.TestData.linearization = linearization;
testCase.TestData.recursive = recursive;
end

function testReducedSystemAndSevenDayPartition(testCase)
lin = testCase.TestData.linearization;
recursive = testCase.TestData.recursive;
verifyEqual(testCase,lin.counts.primal,3722);
verifyEqual(testCase,lin.counts.equalities,618);
verifyEqual(testCase,lin.counts.inequalities,7248);
verifyEqual(testCase,lin.counts.full_kkt,18836);
verifyEqual(testCase,size(recursive.reduced.W),[3722 3722]);
verifyEqual(testCase,size(recursive.reduced.saddle),[4340 4340]);
verifyEqual(testCase,numel(recursive.daily_partitions),7);
verifyEqual(testCase,[recursive.daily_partitions.day_id],14:20);
verifyTrue(testCase,recursive.partition.assembly_audit.passed);
verifyEqual(testCase, ...
    recursive.partition.assembly_audit.matrix_difference_nnz,0);
verifyEqual(testCase, ...
    recursive.partition.assembly_audit.cross_day_hourly_equality_nnz,0);
verifyTrue(testCase, ...
    recursive.partition.assembly_audit.no_cross_day_soc_coupling);
end

function testRecursivePermutationIsAuditableNonidentityBijection(testCase)
recursive = testCase.TestData.recursive;
permutation = recursive.partition.permutation;
map = permutation.map;
n = size(recursive.reduced.saddle,1);
identityOrder = (1:n).';
requiredColumns = ["run_id","recursive_solver_index", ...
    "canonical_reduced_index","forward_recursive_to_canonical", ...
    "inverse_source_canonical_index","inverse_canonical_to_recursive", ...
    "inverse_for_mapped_canonical", ...
    "space_name", ...
    "canonical_local_index","semantic_role","object_scope", ...
    "object_key","object_local_index","day","hour", ...
    "asset_type","asset_id","canonical_object_id", ...
    "is_identity_position"];

verifyEqual(testCase,n,4340);
verifyEqual(testCase,height(map),4340);
verifyTrue(testCase,all(ismember(requiredColumns, ...
    string(map.Properties.VariableNames))));
verifyEqual(testCase,map.recursive_solver_index,identityOrder);
verifyEqual(testCase,sort(map.canonical_reduced_index),identityOrder);
verifyEqual(testCase,sort(permutation.forward_recursive_to_canonical), ...
    identityOrder);
verifyEqual(testCase,sort(permutation.inverse_canonical_to_recursive), ...
    identityOrder);
verifyTrue(testCase,permutation.is_bijection);
verifyTrue(testCase,permutation.is_nonidentity);
verifyTrue(testCase,any(~map.is_identity_position));
verifyEqual(testCase,nnz(map.object_scope=="annual_core"),16);
verifyEqual(testCase,unique(map.day(map.object_scope=="daily_chain")), ...
    (14:20).');
verifyEqual(testCase,height(permutation.assembly_map),8);
verifyEqual(testCase,permutation.assembly_map.dimension, ...
    [16;617;618;617;618;618;618;618]);

forward = permutation.forward_recursive_to_canonical;
inverse = permutation.inverse_canonical_to_recursive;
verifyEqual(testCase,inverse(forward),identityOrder);
verifyEqual(testCase,forward(inverse),identityOrder);
verifyTrue(testCase,permutation.forward_inverse_composition_exact);
verifyTrue(testCase,permutation.inverse_forward_composition_exact);
end

function testRecursivePermutationReconstructsCanonicalReducedSystem(testCase)
recursive = testCase.TestData.recursive;
permutation = recursive.partition.permutation;
assembly = recursive.partition.assembly_audit;
forward = permutation.forward_recursive_to_canonical;
inverse = permutation.inverse_canonical_to_recursive;

verifyEqual(testCase,recursive.reduced.saddle(forward,forward), ...
    assembly.expected_recursive_matrix);
verifyEqual(testCase,recursive.reduced.rhs(forward),assembly.expected_rhs);
verifyEqual(testCase, ...
    assembly.expected_recursive_matrix(inverse,inverse), ...
    recursive.reduced.saddle);
verifyEqual(testCase,assembly.expected_rhs(inverse),recursive.reduced.rhs);
verifyEqual(testCase,assembly.reconstructed_canonical_matrix, ...
    recursive.reduced.saddle);
verifyEqual(testCase,assembly.reconstructed_canonical_rhs, ...
    recursive.reduced.rhs);
verifyEqual(testCase,assembly.canonical_matrix_difference_nnz,0);
verifyEqual(testCase,assembly.canonical_rhs_difference_nnz,0);
verifyEqual(testCase,assembly.canonical_matrix_relative_error,0);
verifyEqual(testCase,assembly.canonical_rhs_relative_error,0);
verifyTrue(testCase,assembly.passed);
end

function testDailyChainsRetainNaturalDimensions(testCase)
recursive = testCase.TestData.recursive;
expected = testCase.TestData.config.expected_daily_hourly_chain_dimensions;
actual = arrayfun(@(day)size(day.M,1),recursive.daily_partitions).';
verifyEqual(testCase,actual,expected);
verifyEqual(testCase,sum(actual),4128);
for d = 1:7
    day = recursive.daily_partitions(d);
    verifyEqual(testCase,numel(day.hour),24);
    verifyEqual(testCase,size(day.B),[expected(d),14]);
    verifyEqual(testCase,numel(day.r_v),expected(d));
    verifyEqual(testCase,size(day.hour(1).E),[0 0]);
    for t = 2:24
        verifyEqual(testCase,nnz(day.hour(t).E),2, ...
            sprintf("Day %d hour %d needs two internal SOC links.", ...
            day.day_id,t));
    end
    verifyEqual(testCase,day.hour(24).n_equalities,5);
end
end

function testEachDayUsesOneFactorPerHourAndFifteenRhs(testCase)
recursive = testCase.TestData.recursive;
for d = 1:7
    thomas = recursive.daily_thomas(d);
    verifyEqual(testCase,thomas.rhs_count,15);
    verifyEqual(testCase,numel(thomas.factors),24);
    verifyEqual(testCase,numel(thomas.diagnostics.hour_block),24);
    verifyLessThanOrEqual(testCase, ...
        thomas.diagnostics.chain_relative_residual,1e-10);
    verifyEqual(testCase, ...
        [thomas.diagnostics.hour_block.rhs_count],repmat(15,1,24));
    verifyEqual(testCase, ...
        [thomas.diagnostics.hour_block.schur_inertia_zero],zeros(1,24));
end
end

function testDailyResponseQuantitiesFollowDistinctContracts(testCase)
recursive = testCase.TestData.recursive;
verifyEqual(testCase,numel(recursive.daily_responses),7);
for d = 1:7
    day = recursive.daily_partitions(d);
    response = recursive.daily_responses(d);
    verifyEqual(testCase,response.day_id,day.day_id);
    verifyEqual(testCase,size(response.S),[14 14]);
    verifyEqual(testCase,size(response.c),[14 1]);
    verifyEqual(testCase,size(response.beta),[14 1]);
    verifyEqual(testCase,size(response.gamma),[14 1]);
    verifyLessThanOrEqual(testCase, ...
        norm(day.M*response.a-day.r_v,2)/max(1,norm(day.r_v,2)),1e-10);
    verifyLessThanOrEqual(testCase, ...
        norm(day.M*response.U-day.B,"fro")/max(1,norm(day.B,"fro")),1e-10);
    verifyLessThanOrEqual(testCase, ...
        norm(response.S-(day.C-day.B.'*response.U),"fro")/ ...
        max(1,norm(response.S,"fro")),1e-14);
    verifyLessThanOrEqual(testCase, ...
        norm(response.c-(day.r_q_day-day.B.'*response.a),2)/ ...
        max(1,norm(response.c,2)),1e-14);
    verifyLessThanOrEqual(testCase, ...
        norm(response.gamma-(response.c-response.S*response.beta),2)/ ...
        max(1,norm(response.gamma,2)),1e-14);
    verifyTrue(testCase,response.diagnostics.c_gamma_distinct_formula);
end
end

function testDayResponseFunctionHasNoGlobalSideEffects(testCase)
path = fullfile(testCase.TestData.project_root,"src","solver", ...
    "form_stage_a3_day_response.m");
source = string(fileread(path));
for forbidden = ["global ","persistent ","assignin(","evalin(", ...
        "save(","writetable(","fopen("]
    verifyFalse(testCase,contains(lower(source),lower(forbidden)), ...
        sprintf("Side-effect token found: %s",forbidden));
end
day = testCase.TestData.recursive.daily_partitions(1);
thomas = testCase.TestData.recursive.daily_thomas(1);
first = form_stage_a3_day_response(day,thomas);
second = form_stage_a3_day_response(day,thomas);
verifyEqual(testCase,first.S,second.S);
verifyEqual(testCase,first.gamma,second.gamma);
end

function testShuffledResponsesAreSortedBeforeExactAggregation(testCase)
responses = testCase.TestData.recursive.daily_responses;
shuffled = responses([7,3,1,6,2,5,4]);
aggregation = aggregate_stage_a3_day_responses(shuffled,14:20);
reference = testCase.TestData.recursive.aggregation;
verifyEqual(testCase,aggregation.day_ids_sorted,14:20);
verifyNotEqual(testCase,aggregation.input_order,14:20);
verifyEqual(testCase,aggregation.S_sum,reference.S_sum);
verifyEqual(testCase,aggregation.gamma_sum,reference.gamma_sum);
verifyEqual(testCase,aggregation.order_invariant_S_relative_error,0);
verifyEqual(testCase,aggregation.order_invariant_gamma_relative_error,0);
verifyTrue(testCase,aggregation.order_invariant_passed);
end

function testGlobalCoreIsTheOnlySixteenDimensionalBorder(testCase)
recursive = testCase.TestData.recursive;
core = recursive.core;
globalPart = recursive.partition.global;
aggregation = recursive.aggregation;
verifyEqual(testCase,size(core.matrix),[16 16]);
verifyEqual(testCase,size(core.rhs),[16 1]);
verifyEqual(testCase,size(core.delta_q),[14 1]);
verifyEqual(testCase,size(core.delta_rho),[2 1]);
verifyEqual(testCase,core.matrix, ...
    [globalPart.Q+aggregation.S_sum,globalPart.R.'; ...
    globalPart.R,sparse(2,2)]);
verifyEqual(testCase,core.rhs, ...
    [globalPart.b_q+aggregation.gamma_sum;-globalPart.r_duration]);
verifyLessThanOrEqual(testCase,core.diagnostics.relative_residual,1e-10);
verifyEqual(testCase,core.factor.inertia_zero,0);
end

function testStrictReverseRecoveryIncludesEveryCanonicalComponent(testCase)
recursive = testCase.TestData.recursive;
verifyEqual(testCase,numel(recursive.direction),18836);
verifyEqual(testCase,numel(recursive.components.xi),3722);
verifyEqual(testCase,numel(recursive.components.y),618);
verifyEqual(testCase,numel(recursive.components.l),7248);
verifyEqual(testCase,numel(recursive.components.z),7248);
verifyEqual(testCase,size(recursive.components.q_day_matrix),[14 7]);
verifyEqual(testCase,size(recursive.components.pi_matrix),[14 7]);
verifyEqual(testCase,size(recursive.components.v_by_day_hour),[7 24]);
verifyTrue(testCase,recursive.recovery.strict_reverse_recovery);
verifyEqual(testCase,recursive.recovery.reverse_day_order,20:-1:14);
verifyEqual(testCase,recursive.recovery.reverse_hour_order,24:-1:1);
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyFalse(testCase,recursive.full_direction_consumed);
verifyFalse(testCase,recursive.parallel_executed);
end
