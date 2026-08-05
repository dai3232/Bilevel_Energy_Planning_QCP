function tests = test_stage_a1_solver_components
%TEST_STAGE_A1_SOLVER_COMPONENTS Audit each exact recursive elimination layer.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a1_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a1_index(data,"RunId","A1_SOLVER_COMPONENT_TEST");
state = rkkt.model.initialize_stage_a1_state(data,index,config);
linearization = rkkt.model.build_stage_a1_linearization(state,data,index,config);
reduced = rkkt.solver.eliminate_inequality_directions(linearization);
partition = rkkt.solver.partition_recursive_system(linearization,reduced, ...
    AssemblyTolerance=1e-12);
thomas = rkkt.solver.solve_block_thomas_ldl(partition, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
response = rkkt.solver.form_day_response(partition,thomas);
core = rkkt.solver.solve_core16_ldl(partition,response, ...
    SymmetryTolerance=config.tolerances.symmetry_relative);
testCase.TestData.config = config;
testCase.TestData.linearization = linearization;
testCase.TestData.reduced = reduced;
testCase.TestData.partition = partition;
testCase.TestData.thomas = thomas;
testCase.TestData.response = response;
testCase.TestData.core = core;
end

function testExactInequalityEliminationMatchesReducedKkt(testCase)
lin = testCase.TestData.linearization;
reduced = testCase.TestData.reduced;
verifyEqual(testCase,size(reduced.saddle),[127 127]);
verifyLessThanOrEqual(testCase,reduced.symmetry_relative,1e-15);

probe = (1:127).'/127;
dxi = probe(1:100);
dy = probe(101:127);
expected = [reduced.W*dxi + lin.A.'*dy; lin.A*dxi];
verifyEqual(testCase,reduced.saddle*probe,expected,"AbsTol",1e-14);
end

function testRecursivePartitionIsExactPermutation(testCase)
partition = testCase.TestData.partition;
verifyEqual(testCase,[partition.hour.dimension],[27 27 29]);
verifyEqual(testCase,size(partition.M),[83 83]);
verifyEqual(testCase,size(partition.B),[83 14]);
verifyTrue(testCase,partition.assembly_audit.passed);
verifyLessThanOrEqual(testCase, ...
    partition.assembly_audit.matrix_relative_error,1e-12);
verifyLessThanOrEqual(testCase, ...
    partition.assembly_audit.rhs_relative_error,1e-12);
end

function testThomasUsesOneFactorPerHourAndFifteenRhs(testCase)
partition = testCase.TestData.partition;
thomas = testCase.TestData.thomas;
verifyEqual(testCase,thomas.rhs_count,15);
verifyEqual(testCase,numel(thomas.factors),3);
for k = 1:3
    verifyEqual(testCase,thomas.factors{k}.dimension,partition.hour(k).dimension);
    verifyEqual(testCase,thomas.factors{k}.inertia_zero,0);
    verifyLessThanOrEqual(testCase, ...
        thomas.factors{k}.symmetry_relative,1e-12);
    verifyLessThanOrEqual(testCase, ...
        thomas.factors{k}.factor_relative_residual,1e-12);
end
verifyLessThanOrEqual(testCase, ...
    thomas.diagnostics.chain_relative_residual,1e-12);

reference = partition.M \ [partition.r_v,partition.B];
relative = norm(thomas.stacked_solution-reference,"fro") / ...
    max(1,norm(reference,"fro"));
verifyLessThanOrEqual(testCase,relative,1e-12);
end

function testDayResponseAndGlobalCoreDimensions(testCase)
response = testCase.TestData.response;
core = testCase.TestData.core;
verifyEqual(testCase,size(response.S),[14 14]);
verifyEqual(testCase,size(core.matrix),[16 16]);
verifyEqual(testCase,numel(core.delta_q),14);
verifyEqual(testCase,numel(core.delta_rho),2);
verifyEqual(testCase,core.factor.inertia_zero,0);
verifyLessThanOrEqual(testCase,core.diagnostics.relative_residual,1e-12);
end

function testAsymmetricPivotIsRejectedWithoutModification(testCase)
partition = testCase.TestData.partition;
partition.Q(1,2) = partition.Q(1,2) + 1;
verifyError(testCase,@() rkkt.solver.solve_core16_ldl( ...
    partition,testCase.TestData.response,SymmetryTolerance=1e-12), ...
    "stageA1:solver:Core16Failure");
end
