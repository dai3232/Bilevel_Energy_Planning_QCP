function tests = test_stage_a2_solver_components
%TEST_STAGE_A2_SOLVER_COMPONENTS Audit the 24-hour variable-block recursion.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a2_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a2_index(data,"RunId","A2_SOLVER_COMPONENT_TEST");
state = rkkt.model.initialize_stage_a2_state(data,index,config);
linearization = rkkt.model.build_stage_a2_linearization(state,data,index,config);
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

function testReducedSystemCountsAreDerivedFromActiveVariables(testCase)
lin = testCase.TestData.linearization;
reduced = testCase.TestData.reduced;
verifyEqual(testCase,lin.counts.primal,543);
verifyEqual(testCase,lin.counts.equalities,90);
verifyEqual(testCase,lin.counts.inequalities,1058);
verifyEqual(testCase,lin.counts.full_kkt,2749);
verifyEqual(testCase,size(reduced.W),[543 543]);
verifyEqual(testCase,size(reduced.saddle),[633 633]);
verifyLessThanOrEqual(testCase,reduced.symmetry_relative,1e-15);
end

function testTwentyFourNaturalHourBlocksAndSocInterfaces(testCase)
partition = testCase.TestData.partition;
expectedDimensions = [repmat(22,1,7),repmat(27,1,11),26, ...
    repmat(22,1,4),24];
verifyEqual(testCase,[partition.hour.hour],1:24);
verifyEqual(testCase,[partition.hour.dimension],expectedDimensions);
verifyEqual(testCase,[partition.hour.n_primal], ...
    [repmat(19,1,7),repmat(24,1,11),23,repmat(19,1,5)]);
verifyEqual(testCase,[partition.hour.n_equalities],[repmat(3,1,23),5]);
verifyEqual(testCase,size(partition.M),[589 589]);
verifyEqual(testCase,size(partition.B),[589 14]);
verifyEqual(testCase,numel(partition.r_v),589);
verifyEqual(testCase,height(partition.block_offsets),24);
verifyEqual(testCase,partition.block_offsets.dimension.',expectedDimensions);
verifyEqual(testCase,size(partition.hour(1).E),[0 0]);
for hour = 2:24
    verifyEqual(testCase,size(partition.hour(hour).E), ...
        [expectedDimensions(hour),expectedDimensions(hour-1)]);
    verifyEqual(testCase,nnz(partition.hour(hour).E),2, ...
        sprintf("Hour %d interface must contain only two predecessor-SOC links.",hour));
end
verifyTrue(testCase,partition.assembly_audit.passed);
verifyLessThanOrEqual(testCase, ...
    partition.assembly_audit.matrix_relative_error,1e-12);
verifyLessThanOrEqual(testCase, ...
    partition.assembly_audit.rhs_relative_error,1e-12);
end

function testThomasUsesTwentyFourFactorsAndFifteenRhs(testCase)
partition = testCase.TestData.partition;
thomas = testCase.TestData.thomas;
verifyEqual(testCase,thomas.rhs_count,15);
verifyEqual(testCase,numel(thomas.factors),24);
verifyEqual(testCase,numel(thomas.diagnostics.hour_block),24);
for hour = 1:24
    factor = thomas.factors{hour};
    diagnostic = thomas.diagnostics.hour_block(hour);
    verifyEqual(testCase,factor.dimension,partition.hour(hour).dimension);
    verifyEqual(testCase,diagnostic.hour,hour);
    verifyEqual(testCase,diagnostic.dimension,partition.hour(hour).dimension);
    verifyEqual(testCase,diagnostic.rhs_count,15);
    verifyEqual(testCase,diagnostic.D_numeric_rank, ...
        rank(full(partition.hour(hour).D)));
    verifyEqual(testCase,diagnostic.schur_numeric_rank,factor.numeric_rank);
    verifyEqual(testCase,diagnostic.schur_inertia_zero,0);
    verifyEqual(testCase,factor.inertia_zero,0);
    verifyLessThanOrEqual(testCase,diagnostic.D_symmetry_relative,1e-12);
    verifyLessThanOrEqual(testCase, ...
        diagnostic.schur_symmetry_relative,1e-12);
    verifyLessThanOrEqual(testCase, ...
        diagnostic.schur_factor_relative_residual,1e-12);
end
verifyLessThanOrEqual(testCase, ...
    thomas.diagnostics.chain_relative_residual,1e-10);

reference = partition.M \ [partition.r_v,partition.B];
relative = norm(thomas.stacked_solution-reference,"fro") / ...
    max(1,norm(reference,"fro"));
verifyLessThanOrEqual(testCase,relative,1e-10);
end

function testDayResponseAndCoreRetainFrozenDimensions(testCase)
response = testCase.TestData.response;
core = testCase.TestData.core;
verifyEqual(testCase,size(response.S),[14 14]);
verifyEqual(testCase,numel(response.c),14);
verifyEqual(testCase,size(core.matrix),[16 16]);
verifyEqual(testCase,numel(core.delta_q),14);
verifyEqual(testCase,numel(core.delta_rho),2);
verifyEqual(testCase,core.factor.inertia_zero,0);
verifyLessThanOrEqual(testCase,core.diagnostics.relative_residual,1e-10);
end
