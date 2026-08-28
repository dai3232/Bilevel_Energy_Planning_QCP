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

function testDefaultAcceptsAuthorizedRoundoffAsymmetry(testCase)
matrix = sparse([4,1+2e-11;1,-2]);
rhs = [1;2];
relative = norm(matrix-matrix.',"fro")/max(1,norm(matrix,"fro"));
verifyGreaterThan(testCase,relative,1e-12);
verifyLessThanOrEqual(testCase,relative,1e-10);
[~,diagnostics] = rkkt.solver.solve_stage_b2c_daily_joint_block( ...
    matrix,rhs,"unit_authorized_roundoff_asymmetry");
verifyEqual(testCase,diagnostics.symmetry_relative,relative,"AbsTol",0);
verifyError(testCase,@() ...
    rkkt.solver.solve_stage_b2c_daily_joint_block( ...
        matrix,rhs,"unit_old_symmetry_gate",SymmetryTolerance=1e-12), ...
    "stageB2C:dailyJoint:BlockSymmetry");
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
[response,retained] = rkkt.solver.solve_stage_b2c_daily_joint_day(day);
globalDirection = linspace(-1,1,16).';
localDirection = response.a-response.U*globalDirection;
verifyLessThanOrEqual(testCase, ...
    norm(matrix*localDirection+coupling*globalDirection-day.rhs,2),1e-12);
verifyEqual(testCase,size(response.S),[14,14]);
verifyEqual(testCase,response.rhs_count,15);
verifyEqual(testCase,response.water_eta_dimension,0);
finalRhs = day.rhs-day.coupling*globalDirection;
[direct,directDiagnostics] = ...
    rkkt.solver.apply_stage_b2c_daily_joint_factor( ...
        retained,day.matrix,finalRhs,"unit_direct_final_rhs");
verifyLessThanOrEqual(testCase, ...
    norm(matrix*direct-finalRhs,2)/max(1,norm(finalRhs,2)),1e-12);
verifyTrue(testCase,directDiagnostics.retained_factor_reused);
verifyTrue(testCase,directDiagnostics.direct_final_rhs_solve);
verifyEqual(testCase,directDiagnostics.additional_factorization_count,0);
verifyEqual(testCase,response.recovery_contract, ...
    "u_day=a-U*core_solution; retained_LDL_corrects_only_if_residual_fails");
end

function testGlobalPhysicalCoreRebuildMatchesElimination(testCase)
nx = 14;
neq = 2;
nineq = 4;
q = (1:14).';
yDuration = (1:2).';
H = spdiags((1:14).',0,nx,nx);
A = sparse(neq,nx);
A(:,1:2) = [1,-2;3,4];
G = sparse(nineq,nx);
G(:,1:4) = [1,0,-2,0;0,3,0,0;2,-1,1,0;0,0,0,5];
l = [0.7;1.3;2.1;0.9];
z = [1.1;0.8;1.7;2.2];
rDual = linspace(-0.2,0.3,nx).';
rEq = [-0.4;0.6];
rIneq = [0.1;-0.3;0.2;-0.1];
rComp = [-0.5;0.7;-0.2;0.4];
theta = z./l;
phi = (rComp-z.*rIneq)./l;
matrix = [full(H+G.'*spdiags(theta,0,nineq,nineq)*G),full(A.'); ...
    full(A),zeros(neq)];
rhs = [-rDual+G.'*phi;-rEq];
contract = struct("q_global",q,"y_duration",yDuration, ...
    "nx",nx,"l",l,"z",z,"r_dual",rDual,"r_eq",rEq, ...
    "r_ineq",rIneq,"r_comp",rComp);
partition = struct("contract",contract,"global",struct( ...
    "canonical_reduced_indices",(1:16).', ...
    "matrix",sparse(matrix),"rhs",rhs));
lin = struct("identity","unit_global_physical", ...
    "H",H,"A",A,"G",G);
target = rkkt.solver.build_stage_b2c_global_physical_core_base( ...
    lin,partition);
verifyEqual(testCase,target.dimension,16);
verifyLessThanOrEqual(testCase, ...
    norm((target.matrix_high+target.matrix_low)-matrix,"fro")/ ...
        max(1,norm(matrix,"fro")),5e-16);
verifyLessThanOrEqual(testCase, ...
    norm((target.rhs_high+target.rhs_low)-rhs,2)/max(1,norm(rhs,2)), ...
    5e-16);
verifyLessThanOrEqual(testCase,target.symmetry_relative,5e-16);
verifyFalse(testCase,target.regularization_used);
verifyFalse(testCase,target.model_changed);
end

function testDirectFinalRhsAvoidsAffineResponseCancellation(testCase)
matrix = sparse(diag([1,1e-14]));
rhsPhysical = [1;1+1e-14];
rhsCoupling = [0;1];
[responses,~,retained] = ...
    rkkt.solver.solve_stage_b2c_daily_joint_block( ...
        matrix,[rhsPhysical,rhsCoupling],"unit_cancellation_factor", ...
        ContinueNumericalPivotWarning=true);
finalRhs = rhsPhysical-rhsCoupling;
affine = responses(:,1)-responses(:,2);
[direct,diagnostics] = ...
    rkkt.solver.apply_stage_b2c_daily_joint_factor( ...
        retained,matrix,finalRhs,"unit_cancellation_direct", ...
        ContinueNumericalPivotWarning=true);
affineResidual = norm(matrix*affine-finalRhs,2);
directResidual = norm(matrix*direct-finalRhs,2);
verifyLessThan(testCase,directResidual,affineResidual);
verifyLessThanOrEqual(testCase,directResidual,1e-15);
verifyEqual(testCase,diagnostics.additional_factorization_count,0);
end

function testHighLowStateUpdateConsumesLowDirectionBeforeRounding(testCase)
state = struct("xi",-1e16,"y",-1e16,"l",2,"z",3);
high = struct("xi",1e16,"y",1e16,"l",-0.5,"z",-1);
low = struct("xi",1,"y",1,"l",4*eps,"z",4*eps);
[updated,audit,displacementHigh,displacementLow] = ...
    rkkt.solver.update_primal_dual_state_high_low( ...
    state,high,low,1,1);
verifyEqual(testCase,updated.xi,1,"AbsTol",0);
verifyEqual(testCase,updated.y,1,"AbsTol",0);
verifyGreaterThan(testCase,updated.l,1.5);
verifyGreaterThan(testCase,updated.z,2);
verifyTrue(testCase,audit.high_low_direction_consumed);
verifyEqual(testCase,audit.method, ...
    "twofold_direction_single_round_state_update");
verifyGreaterThan(testCase,audit.maximum_relative_difference_from_naive,0);
verifyEqual(testCase,displacementHigh.xi,1e16,"AbsTol",0);
verifyEqual(testCase,displacementLow.xi,1,"AbsTol",0);
verifyTrue(testCase,audit.accepted_displacement_retained_high_low);
end

function testHighLowFractionToBoundaryConsumesBothParts(testCase)
values = [2;4;3];
directionHigh = [-1;-8;1];
directionLow = [0;-eps(8);0];
step = rkkt.solver.compute_fraction_to_boundary_step_high_low( ...
    values,directionHigh,directionLow,0.9);
verifyEqual(testCase,step.limiting_index,2);
verifyEqual(testCase,step.limiting_direction,-8-eps(8),"AbsTol",0);
verifyEqual(testCase,step.limiting_direction_high,-8-eps(8),"AbsTol",0);
verifyEqual(testCase,step.limiting_direction_low,0,"AbsTol",0);
verifyLessThan(testCase,step.raw_boundary_step,0.5);
verifyLessThan(testCase,step.alpha,0.45);
verifyGreaterThan(testCase,step.minimum_trial_value,0);
verifyTrue(testCase,step.high_low_direction_consumed);
end
