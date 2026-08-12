function tests = test_stage_b2c_daily_joint_block
tests = functiontests(localfunctions);
end

function testOneFactorForFifteenRightHandSides(testCase)
matrix = sparse([4,1,0;1,0,1;0,1,-2]);
rhs = reshape(1:45,3,15);
[solution,diagnostics] = rkkt.solver.solve_stage_b2c_daily_joint_block( ...
    matrix,rhs,"unit_daily_joint_block");
verifyLessThanOrEqual(testCase, ...
    norm(solution-matrix\rhs,"fro")/max(1,norm(matrix\rhs,"fro")),1e-12);
verifyEqual(testCase,diagnostics.factorization_count,1);
verifyEqual(testCase,diagnostics.rhs_count,15);
verifyFalse(testCase,diagnostics.regularization_used);
verifyFalse(testCase,diagnostics.pseudoinverse_used);
end

function testStructurallySingularBlockStops(testCase)
matrix = sparse([1,0;0,0]);
verifyError(testCase,@() ...
    rkkt.solver.solve_stage_b2c_daily_joint_block( ...
        matrix,ones(2,1),"unit_singular_daily_joint_block"), ...
    "stageB2C:dailyJoint:ModelDecisionStructuralRank");
end

function testNumericalNearZeroPivotContinuesToFinalKktGate(testCase)
matrix = sparse([1,1;1,1+eps]);
rhs = matrix*[1;1];
[solution,diagnostics] = rkkt.solver.solve_stage_b2c_daily_joint_block( ...
    matrix,rhs,"unit_numerical_near_zero_daily_joint_block");
verifyLessThanOrEqual(testCase, ...
    norm(matrix*solution-rhs,2)/max(1,norm(rhs,2)),1e-12);
verifyEqual(testCase,diagnostics.structural_rank,2);
verifyEqual(testCase,diagnostics.inertia_zero,1);
verifyTrue(testCase,diagnostics.numerical_zero_pivot_continued);
verifyEqual(testCase,diagnostics.acceptance_scope, ...
    "final_reconstructed_kkt_residual");
verifyFalse(testCase,diagnostics.warning_present);
verifyTrue(testCase,diagnostics.solution_finite);
verifyFalse(testCase,diagnostics.regularization_used);
verifyFalse(testCase,diagnostics.pseudoinverse_used);
end

function testDailyResponseUsesLinearSuperposition(testCase)
n = 28;
matrix = spdiags((1:n).',0,n,n);
capacityCoupling = sparse(mod((1:n).'+(1:14),5)-2);
coupling = [capacityCoupling,sparse(n,2)];
day = struct("day_id",14,"linearization_identity","unit", ...
    "matrix",matrix,"rhs",linspace(-2,3,n).', ...
    "capacity_coupling",capacityCoupling,"coupling",coupling, ...
    "dimension",n,"pi_day_local_positions",(15:28).');
response = rkkt.solver.solve_stage_b2c_daily_joint_day(day);
globalDirection = linspace(-1,1,16).';
localDirection = response.a-response.U*globalDirection;
verifyLessThanOrEqual(testCase, ...
    norm(matrix*localDirection+coupling*globalDirection-day.rhs,2),1e-12);
verifyEqual(testCase,size(response.S),[14,14]);
verifyEqual(testCase,response.rhs_count,15);
verifyEqual(testCase,response.water_eta_dimension,0);
end
