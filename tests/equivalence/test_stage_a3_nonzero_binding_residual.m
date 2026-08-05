function tests = test_stage_a3_nonzero_binding_residual
%TEST_STAGE_A3_NONZERO_BINDING_RESIDUAL Exercise the general binding case.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a3_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a3_index(data,"RunId","A3_NONZERO_BINDING_TEST");
state = rkkt.model.initialize_stage_a3_state(data,index,config);
linearization = rkkt.model.build_stage_a3_linearization(state,data,index,config);

% Add a small deterministic residual only to q_d-q binding rows.  This is a
% test fixture for the general elimination formula, not a model change.
centeredCapacityPattern = (1:14).'-7.5;
for dayPosition = 1:numel(config.days)
    rows = linearization.maps.y_binding_by_day{dayPosition};
    residual = 1e-3*dayPosition*centeredCapacityPattern;
    linearization.r_eq(rows) = residual;
    linearization.constraints.eq(rows) = residual;
end
linearization.identity = linearization.identity+ ...
    "|deterministic-nonzero-binding-residual-v1";

direct = rkkt.solver.solve_stage_a3_full_kkt_direction(linearization);
recursive = rkkt.solver.solve_stage_a3_recursive_direction(linearization, ...
    AssemblyTolerance=1e-12, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
audit = rkkt.solver.verify_stage_a3_direction_equivalence( ...
    direct,recursive,linearization, ...
    DirectionRelative=config.tolerances.direction_relative_2norm, ...
    RecursiveResidual=config.tolerances.recursive_full_kkt_relative_residual, ...
    FullResidualPreferred=config.tolerances.direct_preferred, ...
    FullResidualMaximum=config.tolerances.direct_maximum);

betaNorms = arrayfun(@(value)norm(value.beta,2), ...
    recursive.daily_responses).';
gammaCDifferences = arrayfun(@(value)norm(value.gamma-value.c,2), ...
    recursive.daily_responses).';
fprintf(['A3 deterministic nonzero binding audit: direction=%.17g, ' ...
    'recursive_residual=%.17g, direct_residual=%.17g, ' ...
    'beta_min=%.17g, beta_max=%.17g, gamma_c_max=%.17g\n'], ...
    audit.direction_relative_error,audit.recursive_kkt_relative_residual, ...
    audit.full_kkt_relative_residual,min(betaNorms),max(betaNorms), ...
    max(gammaCDifferences));

testCase.TestData.config = config;
testCase.TestData.audit = audit;
testCase.TestData.recursive = recursive;
testCase.TestData.beta_norms = betaNorms;
testCase.TestData.gamma_c_differences = gammaCDifferences;
end

function testNonzeroBindingResidualGeneralCasePreservesEquivalence(testCase)
config = testCase.TestData.config;
audit = testCase.TestData.audit;
recursive = testCase.TestData.recursive;
verifyGreaterThan(testCase,max(testCase.TestData.beta_norms),0);
verifyGreaterThan(testCase,max(testCase.TestData.gamma_c_differences),0);
verifyLessThanOrEqual(testCase,audit.direction_relative_error, ...
    config.tolerances.direction_relative_2norm);
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual, ...
    config.tolerances.recursive_full_kkt_relative_residual);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual, ...
    config.tolerances.direct_maximum);
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyFalse(testCase,recursive.full_direction_consumed);
end
