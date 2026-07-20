function tests = test_stage_a1_direction_equivalence
%TEST_STAGE_A1_DIRECTION_EQUIVALENCE Verify the one frozen A1 Newton step.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a1_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a1_index(data,"RunId","A1_EQUIVALENCE_TEST");
state = initialize_stage_a1_state(data,index,config);
linearization = build_stage_a1_linearization(state,data,index,config);
direct = solve_full_kkt_direction(linearization);
recursive = solve_recursive_direction(linearization, ...
    AssemblyTolerance=1e-12, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
audit = verify_direction_equivalence(direct,recursive,linearization, ...
    DirectionRelative=config.tolerances.direction_relative_2norm, ...
    RecursiveResidual=config.tolerances.recursive_full_kkt_relative_residual, ...
    FullResidualPreferred=config.tolerances.direct_preferred, ...
    FullResidualMaximum=config.tolerances.direct_maximum);
testCase.TestData.config = config;
testCase.TestData.linearization = linearization;
testCase.TestData.direct = direct;
testCase.TestData.recursive = recursive;
testCase.TestData.audit = audit;
end

function testOverallAndComponentDirectionsAreStrictlyEquivalent(testCase)
audit = testCase.TestData.audit;
config = testCase.TestData.config;
verifyLessThanOrEqual(testCase,audit.direction_relative_error, ...
    config.tolerances.direction_relative_2norm);
names = ["xi","y","l","z"];
for name = names
    verifyLessThanOrEqual(testCase,audit.component_relative_errors.(name), ...
        config.tolerances.direction_relative_2norm);
end
verifyTrue(testCase,audit.passed.direction);
end

function testRecursiveDirectionSatisfiesFullKkt(testCase)
audit = testCase.TestData.audit;
config = testCase.TestData.config;
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual, ...
    config.tolerances.recursive_full_kkt_relative_residual);
verifyTrue(testCase,audit.passed.recursive_residual);
verifyTrue(testCase,testCase.TestData.recursive.no_full_direction_fallback);
end

function testDirectSparseSolveMeetsPreferredResidual(testCase)
audit = testCase.TestData.audit;
config = testCase.TestData.config;
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual, ...
    config.tolerances.direct_preferred);
verifyTrue(testCase,audit.passed.full_residual_preferred);
verifyTrue(testCase,audit.passed.full_residual_hard);
verifyEqual(testCase,testCase.TestData.direct.kkt.dimension,471);
verifyTrue(testCase,issparse(testCase.TestData.direct.kkt.matrix));
end

function testAllDirectionsRecoverAndFixedZerosRemainExact(testCase)
lin = testCase.TestData.linearization;
recursive = testCase.TestData.recursive;
physical = recover_stage_a_physical_arrays( ...
    lin.state.xi,recursive.components.xi,lin.index,load_project_data( ...
    string(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
verifyEqual(testCase,numel(recursive.direction),471);
verifyEqual(testCase,numel(recursive.components.xi),100);
verifyEqual(testCase,numel(recursive.components.y),27);
verifyEqual(testCase,numel(recursive.components.l),172);
verifyEqual(testCase,numel(recursive.components.z),172);
verifyTrue(testCase,recursive.fixed_zero.all_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.directions_exact_zero);
end
