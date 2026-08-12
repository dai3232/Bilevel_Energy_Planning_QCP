function recovery = recover_stage_b2c_daily_joint_direction( ...
        lin,partition,responses,core)
%RECOVER_STAGE_B2C_DAILY_JOINT_DIRECTION Recover every canonical direction.

arguments
    lin (1,1) struct
    partition (1,1) struct
    responses (:,1) struct
    core (1,1) struct
end

contract = partition.contract;
assert(isequal(partition.linearization_identity,lin.identity) && ...
    isequal(core.linearization_identity,lin.identity), ...
    "stageB2C:dailyJoint:RecoveryIdentity", ...
    "Recovery inputs do not share one linearization identity.");

reducedDirection = zeros(contract.nx+contract.neq,1);
written = false(size(reducedDirection));
globalIndices = partition.global.canonical_reduced_indices;
reducedDirection(globalIndices) = core.solution;
written(globalIndices) = true;
dailySolutions = cell(contract.n_days,1);
deltaQDay = cell(contract.n_days,1);
deltaPi = cell(contract.n_days,1);

for d = 1:contract.n_days
    day = partition.day(d);
    responsePosition = find([responses.day_id]==day.day_id,1);
    assert(~isempty(responsePosition), ...
        "stageB2C:dailyJoint:RecoveryDay", ...
        "Day %d response is missing.",day.day_id);
    response = responses(responsePosition);
    localDirection = response.a-response.U*core.solution;
    indices = day.canonical_reduced_indices;
    assert(~any(written(indices)), ...
        "stageB2C:dailyJoint:RecoveryOverlap", ...
        "Day %d overlaps an already recovered canonical slice.",day.day_id);
    reducedDirection(indices) = localDirection;
    written(indices) = true;
    dailySolutions{d} = localDirection;
    deltaQDay{d} = localDirection(day.q_day_local_positions);
    deltaPi{d} = localDirection(day.pi_day_local_positions);
end
assert(all(written), ...
    "stageB2C:dailyJoint:RecoveryCoverage", ...
    "Daily-joint recovery did not fill the complete reduced direction.");

deltaXi = reducedDirection(1:contract.nx);
deltaY = reducedDirection(contract.nx+1:end);
deltaL = -contract.r_ineq-sparse(lin.G)*deltaXi;
deltaZ = (-contract.r_comp-contract.z.*deltaL)./contract.l;
direction = [deltaXi;deltaY;deltaL;deltaZ];
assert(all(isfinite(direction)), ...
    "stageB2C:dailyJoint:RecoveryFinite", ...
    "Recovered daily-joint direction contains NaN or Inf.");

fixed = rkkt.solver.stage_a_multiday_fixed_zero_evidence(lin.index);
recovery = struct();
recovery.stage_id = "stage_B";
recovery.milestone_id = "B-2C";
recovery.linearization_identity = lin.identity;
recovery.direction = direction;
recovery.canonical_reduced_direction = reducedDirection;
recovery.components = struct("xi",deltaXi,"y",deltaY, ...
    "l",deltaL,"z",deltaZ,"q",deltaXi(contract.q_global), ...
    "rho",deltaY(contract.y_duration), ...
    "q_day_by_day",{deltaQDay},"pi_by_day",{deltaPi}, ...
    "daily_joint_by_day",{dailySolutions}, ...
    "eta_by_day",{cell(contract.n_days,1)});
recovery.fixed_zero = fixed;
recovery.no_full_direction_fallback = true;
recovery.full_direction_consumed = false;
recovery.state_update_executed = false;
recovery.diagnostics = struct( ...
    "equality_recovery_residual", ...
        norm(sparse(lin.A)*deltaXi+contract.r_eq,inf), ...
    "slack_recovery_residual", ...
        norm(sparse(lin.G)*deltaXi+deltaL+contract.r_ineq,inf), ...
    "complementarity_recovery_residual", ...
        norm(contract.z.*deltaL+contract.l.*deltaZ+contract.r_comp,inf), ...
    "water_eta_dimension",0,"fixed_zero_exact",fixed.all_exact_zero);
end
