function tests = test_stage_b2a_linearization
%TEST_STAGE_B2A_LINEARIZATION Unified value/Jacobian/Hessian tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
c = rkkt.model.load_stage_b2a_configuration(root);
d = rkkt.data.load_project_data(root);
idx = rkkt.indexing.build_stage_b_index(d,c,"RunId","B2A_LINEARIZATION_TEST");
s = rkkt.model.initialize_stage_b2a_state(d,idx,c);
lin = rkkt.model.build_stage_b_multiday_linearization(s,d,idx,c);
testCase.TestData.root = root;
testCase.TestData.config = c;
testCase.TestData.data = d;
testCase.TestData.index = idx;
testCase.TestData.state = s;
testCase.TestData.lin = lin;
end

function testUnifiedDimensionsAndIdentity(testCase)
lin = testCase.TestData.lin;
verifyEqual(testCase,size(lin.A),[618,3722]);
verifyEqual(testCase,size(lin.G),[7304,3722]);
verifyEqual(testCase,lin.counts.full_kkt,18948);
verifyLessThanOrEqual(testCase,lin.linearization_identity_error,0);
verifyNotEmpty(testCase,string(lin.identity));
verifyTrue(testCase,contains(string(lin.identity),"stage-B2A-linearization-v1.0"));
verifyNotEmpty(testCase,string(lin.base_linearization_identity));
end

function testWaterGOffsetReproducesNonlinearValues(testCase)
lin = testCase.TestData.lin;
water = lin.constraints.water;
reconstructed = lin.G*lin.state.xi+lin.constraints.ineq_offset;
verifyLessThanOrEqual(testCase,norm(reconstructed-lin.constraints.ineq,inf), ...
    64*eps(max(1,norm(lin.constraints.ineq,inf))));
verifyLessThanOrEqual(testCase,max(water.identity_error),0);
verifyEqual(testCase,lin.r_ineq,lin.constraints.ineq+lin.l);
end

function testUpperLowerJacobianSignsAreOpposite(testCase)
w = testCase.TestData.index.water_constraint_index;
G = testCase.TestData.lin.constraints.water.G;
for pair = 1:2:56
    verifyEqual(testCase,G(pair,:),-G(pair+1,:),"AbsTol",0);
    verifyEqual(testCase,w.bound_type(pair),"upper");
    verifyEqual(testCase,w.bound_type(pair+1),"lower");
end
end

function testEveryConstraintHessianHasCorrectSignedLocalDiagonal(testCase)
lin = testCase.TestData.lin;
d = testCase.TestData.data;
v = testCase.TestData.index.variable_index;
for k = 1:56
    h = lin.hessian.constraint_water(k);
    p = h.variable_indices;
    expected = h.sign*2*d.base.hydro.waterA(h.hydro_id);
    verifyEqual(testCase,nnz(h.global_hessian),24);
    verifyEqual(testCase,full(diag(h.global_hessian(p,p))), ...
        repmat(expected,24,1),"AbsTol",0);
    outside = setdiff((1:height(v)).',p);
    verifyEqual(testCase,nnz(h.global_hessian(outside,:)),0);
    verifyEqual(testCase,nnz(h.global_hessian(:,outside)),0);
    verifyLessThanOrEqual(testCase, ...
        norm(h.global_hessian-h.global_hessian.',"fro"),0);
end
end

function testLagrangianHessianUsesNonlinearCurvature(testCase)
lin = testCase.TestData.lin;
weighted = sparse(size(lin.H,1),size(lin.H,2));
for k = 1:numel(lin.hessian.constraint_water)
    h = lin.hessian.constraint_water(k);
    weighted = weighted+lin.state.z(h.inequality_position)*h.global_hessian;
end
verifyEqual(testCase,lin.objective.hessian, sparse(3722,3722));
verifyEqual(testCase,lin.H,weighted,"AbsTol",0);
verifyGreaterThan(testCase,nnz(lin.H),0);
verifyLessThanOrEqual(testCase,lin.lagrangian_hessian_symmetry_relative,1e-12);
end

function testB1FiniteDifferenceDerivativeEvidenceRemainsAtThreshold(testCase)
d = testCase.TestData.data;
c = testCase.TestData.config;
[checks,~] = rkkt.diagnostics.run_stage_b1_derivative_checks(d);
verifyEqual(testCase,height(checks),112);
verifyLessThanOrEqual(testCase,max(checks.gradient_relative_error), ...
    c.derivative_relative_error_threshold);
verifyLessThanOrEqual(testCase,max(checks.hessian_relative_error), ...
    c.derivative_relative_error_threshold);
end

function testRepeatedLinearizationIsBitwiseDeterministic(testCase)
root = testCase.TestData.root;
c = testCase.TestData.config;
d = testCase.TestData.data;
idx = rkkt.indexing.build_stage_b_index(d,c,"RunId","B2A_LINEARIZATION_TEST");
s = rkkt.model.initialize_stage_b2a_state(d,idx,c);
first = rkkt.model.build_stage_b_multiday_linearization(s,d,idx,c);
second = rkkt.model.build_stage_b_multiday_linearization(s,d,idx,c);
verifyEqual(testCase,string(first.identity),string(second.identity));
verifyEqual(testCase,first.H,second.H,"AbsTol",0);
verifyEqual(testCase,first.G,second.G,"AbsTol",0);
verifyEqual(testCase,first.r_dual,second.r_dual,"AbsTol",0);
verifyEqual(testCase,root,testCase.TestData.root);
end
