function tests = test_stage_b2a_full_kkt_structure
%TEST_STAGE_B2A_FULL_KKT_STRUCTURE Sparse assemble-only KKT tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
c = load_stage_b2a_configuration(root);
d = load_project_data(root);
idx = build_stage_b_index(d,c,"RunId","B2A_KKT_TEST");
s = initialize_stage_b2a_state(d,idx,c);
lin = build_stage_b_multiday_linearization(s,d,idx,c);
kkt = assemble_stage_b_multiday_full_kkt(lin,c);
testCase.TestData.config = c;
testCase.TestData.data = d;
testCase.TestData.index = idx;
testCase.TestData.lin = lin;
testCase.TestData.kkt = kkt;
end

function testFullKktDimensionAndSparseNnz(testCase)
k = testCase.TestData.kkt;
verifyEqual(testCase,k.dimension,18948);
verifyEqual(testCase,size(k.matrix),[18948,18948]);
verifyTrue(testCase,issparse(k.matrix));
verifyEqual(testCase,k.nnz,54664);
end

function testBlockOffsetsAndNnzAreExact(testCase)
b = testCase.TestData.kkt.blocks;
verifyEqual(testCase,string(b.status),repmat("PASS",8,1));
verifyEqual(testCase,b.actual_nnz,b.expected_nnz);
verifyEqual(testCase,b.row_start(1),1);
verifyEqual(testCase,b.row_end(1),3722);
verifyEqual(testCase,b.row_start(4),3723);
verifyEqual(testCase,b.row_end(4),4340);
verifyEqual(testCase,b.row_start(6),4341);
verifyEqual(testCase,b.row_end(6),11644);
verifyEqual(testCase,b.row_start(7),11645);
verifyEqual(testCase,b.row_end(7),18948);
end

function testTransposeAndComplementarityBlocksFollowContract(testCase)
k = testCase.TestData.kkt;
s = k.slices;
K = k.matrix;
verifyEqual(testCase,K(s.stationarity_rows,s.y), ...
    K(s.y,s.stationarity_rows).',"AbsTol",0);
verifyEqual(testCase,K(s.stationarity_rows,s.z), ...
    testCase.TestData.lin.G.',"AbsTol",0);
verifyEqual(testCase,K(s.z,s.stationarity_rows), ...
    sparse(7304,3722),"AbsTol",0);
verifyEqual(testCase,K(s.l,s.l),speye(7304),"AbsTol",0);
verifyEqual(testCase,K(s.z,s.l),spdiags(testCase.TestData.lin.z,0,7304,7304), ...
    "AbsTol",0);
verifyEqual(testCase,K(s.z,s.z),spdiags(testCase.TestData.lin.l,0,7304,7304), ...
    "AbsTol",0);
verifyGreaterThan(testCase,k.symmetry.raw_full_kkt_relative,0);
verifyEqual(testCase,string(k.symmetry.raw_full_kkt_status), ...
    "NOT_APPLICABLE_CONTRACTUALLY_NONSYMMETRIC");
end

function testWaterSlackAndDualRowsAreAddedWithoutSolving(testCase)
lin = testCase.TestData.lin;
k = testCase.TestData.kkt;
verifyEqual(testCase,numel(lin.state.l),7248+56);
verifyEqual(testCase,numel(lin.state.z),7248+56);
verifyTrue(testCase,all(lin.state.l(7249:end)>0));
verifyTrue(testCase,all(lin.state.z(7249:end)>0));
verifyFalse(testCase,k.execution.solved);
verifyFalse(testCase,k.execution.recursive_direction_executed);
verifyFalse(testCase,k.execution.full_ipm_executed);
verifyFalse(testCase,k.execution.fallback_used);
verifyEqual(testCase,k.rhs,[-lin.r_dual;-lin.r_eq;-lin.r_ineq;-lin.r_comp], ...
    "AbsTol",0);
end

function testNoDirectionOrSolverFieldsAreProduced(testCase)
lin = testCase.TestData.lin;
k = testCase.TestData.kkt;
verifyEqual(testCase,lin.execution.newton_direction_count,0);
verifyFalse(testCase,lin.execution.full_kkt_solved);
verifyFalse(testCase,lin.execution.recursive_direction_executed);
verifyFalse(testCase,k.execution.fallback_used);
verifyFalse(testCase,isfield(lin,"direction"));
verifyFalse(testCase,isfield(k,"solution"));
end

function testAcceptanceBoundariesRemainNotRun(testCase)
% These two acceptance items are deliberately outside B-2A's structure scope.
verifyEqual(testCase,"NOT_RUN","NOT_RUN");
verifyFalse(testCase,testCase.TestData.config.full_kkt_solve_enabled);
verifyFalse(testCase,testCase.TestData.config.ipm_enabled);
end
