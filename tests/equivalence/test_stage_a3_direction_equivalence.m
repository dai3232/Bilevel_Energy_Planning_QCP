function tests = test_stage_a3_direction_equivalence
%TEST_STAGE_A3_DIRECTION_EQUIVALENCE Compare one seven-day Newton step.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a3_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a3_index(data,"RunId","A3_EQUIVALENCE_TEST");
state = initialize_stage_a3_state(data,index,config);
linearization = build_stage_a3_linearization(state,data,index,config);
direct = solve_stage_a3_full_kkt_direction(linearization);
recursive = solve_stage_a3_recursive_direction(linearization, ...
    AssemblyTolerance=1e-12, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
audit = verify_stage_a3_direction_equivalence( ...
    direct,recursive,linearization, ...
    DirectionRelative=config.tolerances.direction_relative_2norm, ...
    RecursiveResidual=config.tolerances.recursive_full_kkt_relative_residual, ...
    FullResidualPreferred=config.tolerances.direct_preferred, ...
    FullResidualMaximum=config.tolerances.direct_maximum);
physical = recover_stage_a_physical_arrays( ...
    linearization.state.xi,recursive.components.xi,index,data);
testCase.TestData.config = config;
testCase.TestData.linearization = linearization;
testCase.TestData.direct = direct;
testCase.TestData.recursive = recursive;
testCase.TestData.audit = audit;
testCase.TestData.physical = physical;
end

function testCompleteKktIsSparseAndExactly18836(testCase)
direct = testCase.TestData.direct;
lin = testCase.TestData.linearization;
verifyEqual(testCase,direct.kkt.dimension,18836);
verifyEqual(testCase,size(direct.kkt.matrix),[18836 18836]);
verifyTrue(testCase,issparse(direct.kkt.matrix));
verifyEqual(testCase,direct.linearization_identity,lin.identity);
verifyFalse(testCase,direct.diagnostics.warning_present);
verifyLessThanOrEqual(testCase,direct.diagnostics.relative_residual, ...
    testCase.TestData.config.tolerances.direct_maximum);
end

function testOverallAndComponentDirectionsAreStrictlyEquivalent(testCase)
audit = testCase.TestData.audit;
tolerance = testCase.TestData.config.tolerances.direction_relative_2norm;
verifyLessThanOrEqual(testCase,audit.direction_relative_error,tolerance);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase, ...
        audit.component_relative_errors.(name),tolerance);
end
verifyTrue(testCase,audit.passed.direction);
end

function testRecursiveDirectionReinsertsIntoCompleteKkt(testCase)
audit = testCase.TestData.audit;
recursive = testCase.TestData.recursive;
tolerance = testCase.TestData.config.tolerances.recursive_full_kkt_relative_residual;
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual,tolerance);
verifyEqual(testCase,recursive.full_kkt_reinsertion.relative_residual, ...
    audit.recursive_kkt_relative_residual,"RelTol",1e-13);
verifyTrue(testCase,audit.passed.recursive_residual);
verifyTrue(testCase,audit.passed.full_residual_hard);
verifyTrue(testCase,audit.all_blocking_pass);
end

function testOneSharedLinearizationAndNoAuditDirectionFallback(testCase)
lin = testCase.TestData.linearization;
direct = testCase.TestData.direct;
recursive = testCase.TestData.recursive;
verifyEqual(testCase,direct.linearization_identity,lin.identity);
verifyEqual(testCase,recursive.linearization_identity,lin.identity);
verifyEqual(testCase,recursive.reduced.linearization_identity,lin.identity);
verifyEqual(testCase,recursive.partition.linearization_identity,lin.identity);
verifyEqual(testCase,recursive.core.linearization_identity,lin.identity);
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyFalse(testCase,recursive.full_direction_consumed);
verifyTrue(testCase,testCase.TestData.audit.passed.no_full_direction_fallback);
end

function testFixedZeroValuesAndDirectionsRecoverExactly(testCase)
recursive = testCase.TestData.recursive;
physical = testCase.TestData.physical;
verifyEqual(testCase,recursive.fixed_zero.count,422);
verifyTrue(testCase,recursive.fixed_zero.all_exact_zero);
verifyEqual(testCase,recursive.fixed_zero.value,zeros(422,1));
verifyEqual(testCase,recursive.fixed_zero.direction,zeros(422,1));
verifyEqual(testCase,physical.fixed_zero_audit.count,422);
verifyTrue(testCase,physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.directions_exact_zero);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_value,0);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_direction,0);
end

function testSevenResponsesAndSortedAggregationStayCanonical(testCase)
recursive = testCase.TestData.recursive;
verifyEqual(testCase,numel(recursive.daily_responses),7);
verifyEqual(testCase,[recursive.daily_responses.day_id],14:20);
verifyEqual(testCase,recursive.aggregation.day_ids_sorted,14:20);
verifyEqual(testCase,recursive.aggregation.input_order,[17 14 20 15 19 16 18]);
verifyTrue(testCase,recursive.aggregation.order_invariant_passed);
verifyTrue(testCase,testCase.TestData.audit.passed.day_sort_invariant);
end
