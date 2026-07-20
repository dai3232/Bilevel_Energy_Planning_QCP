function tests = test_stage_a2_direction_equivalence
%TEST_STAGE_A2_DIRECTION_EQUIVALENCE Compare one formal-day Newton step.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a2_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a2_index(data,"RunId","A2_EQUIVALENCE_TEST");
state = initialize_stage_a2_state(data,index,config);
linearization = build_stage_a2_linearization(state,data,index,config);
direct = solve_full_kkt_direction(linearization);
recursive = solve_recursive_direction(linearization, ...
    AssemblyTolerance=1e-12, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
audit = verify_direction_equivalence(direct,recursive,linearization, ...
    DirectionRelative=config.tolerances.direction_relative_2norm, ...
    RecursiveResidual=config.tolerances.recursive_full_kkt_relative_residual, ...
    FullResidualPreferred=config.tolerances.direct_preferred, ...
    FullResidualMaximum=config.tolerances.direct_maximum);
physical = recover_stage_a_physical_arrays( ...
    linearization.state.xi,recursive.components.xi,index,data);
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.linearization = linearization;
testCase.TestData.direct = direct;
testCase.TestData.recursive = recursive;
testCase.TestData.audit = audit;
testCase.TestData.physical = physical;
end

function testCompleteKktIsSparseAndHasFrozenDimension(testCase)
direct = testCase.TestData.direct;
lin = testCase.TestData.linearization;
verifyEqual(testCase,direct.kkt.dimension,2749);
verifyEqual(testCase,size(direct.kkt.matrix),[2749 2749]);
verifyTrue(testCase,issparse(direct.kkt.matrix));
verifyEqual(testCase,direct.linearization_identity,lin.identity);
verifyFalse(testCase,direct.diagnostics.warning_present);
verifyLessThanOrEqual(testCase,direct.diagnostics.relative_residual, ...
    testCase.TestData.config.tolerances.direct_maximum);
end

function testFullAndRecursiveDirectionsAreStrictlyEquivalent(testCase)
audit = testCase.TestData.audit;
config = testCase.TestData.config;
verifyLessThanOrEqual(testCase,audit.direction_relative_error, ...
    config.tolerances.direction_relative_2norm);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase,audit.component_relative_errors.(name), ...
        config.tolerances.direction_relative_2norm);
end
verifyTrue(testCase,audit.passed.direction);
end

function testRecursiveDirectionReinsertsIntoCompleteKkt(testCase)
audit = testCase.TestData.audit;
recursive = testCase.TestData.recursive;
config = testCase.TestData.config;
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual, ...
    config.tolerances.recursive_full_kkt_relative_residual);
verifyEqual(testCase,recursive.full_kkt_reinsertion.relative_residual, ...
    audit.recursive_kkt_relative_residual,"RelTol",1e-13);
verifyTrue(testCase,audit.passed.recursive_residual);
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyEqual(testCase,recursive.thomas.rhs_count,15);
verifyEqual(testCase,numel(recursive.thomas.factors),24);
end

function testAllCanonicalAndFixedZeroDirectionsRecover(testCase)
recursive = testCase.TestData.recursive;
physical = testCase.TestData.physical;
fixed = testCase.TestData.index.fixed_zero_map;
verifyEqual(testCase,numel(recursive.direction),2749);
verifyEqual(testCase,numel(recursive.components.xi),543);
verifyEqual(testCase,numel(recursive.components.y),90);
verifyEqual(testCase,numel(recursive.components.l),1058);
verifyEqual(testCase,numel(recursive.components.z),1058);
verifyEqual(testCase,height(fixed),61);
verifyEqual(testCase,nnz(string(fixed.asset_type)=="solar"),60);
wind19 = fixed.day==14 & fixed.hour==19 & ...
    string(fixed.asset_type)=="wind" & fixed.asset_id==3 & ...
    string(fixed.variable_name)=="PW";
verifyEqual(testCase,nnz(wind19),1);
verifyTrue(testCase,recursive.fixed_zero.all_exact_zero);
verifyEqual(testCase,recursive.fixed_zero.value,zeros(61,1));
verifyEqual(testCase,recursive.fixed_zero.direction,zeros(61,1));
verifyEqual(testCase,physical.fixed_zero_audit.count,61);
verifyTrue(testCase,physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.directions_exact_zero);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_value,0);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_direction,0);
end
