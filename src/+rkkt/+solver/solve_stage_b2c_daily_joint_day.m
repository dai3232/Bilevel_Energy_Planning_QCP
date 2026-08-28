function [response,retainedFactor] = solve_stage_b2c_daily_joint_day(day,options)
%SOLVE_STAGE_B2C_DAILY_JOINT_DAY Form one affine daily response.

arguments
    day (1,1) struct
    options.SymmetryTolerance (1,1) double = 1e-10
    options.ResidualTolerance (1,1) double = 1e-10
    options.RefinementPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

rhs = [day.rhs,day.capacity_coupling];
[solution,factor,retainedFactor] = ...
    rkkt.solver.solve_stage_b2c_daily_joint_block( ...
    day.matrix,rhs,"stageB2C_daily_joint_day_"+string(day.day_id), ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResidualTolerance=options.ResidualTolerance, ...
    RefinementPasses=options.RefinementPasses, ...
    ContinueNumericalPivotWarning=true);

a = solution(:,1);
U = [solution(:,2:15),zeros(day.dimension,2)];
p = a(day.pi_day_local_positions);
S = -U(day.pi_day_local_positions,1:14);

response = struct();
response.stage_id = "stage_B";
response.milestone_id = "B-2C";
response.linearization_identity = day.linearization_identity;
response.day_id = day.day_id;
response.a = a;
response.U = U;
response.p = p;
response.S = S;
response.schur_matrix_contribution = day.coupling.'*U;
response.schur_rhs_contribution = day.coupling.'*a;
response.factor = factor;
response.dimension = day.dimension;
response.rhs_count = size(rhs,2);
response.water_eta_dimension = 0;
response.response_contract = "u_day=a-U*[delta_q;delta_rho]";
response.recovery_contract = ...
    "u_day=a-U*core_solution; retained_LDL_corrects_only_if_residual_fails";
retainedFactor.day_id = day.day_id;
retainedFactor.linearization_identity = day.linearization_identity;
end
