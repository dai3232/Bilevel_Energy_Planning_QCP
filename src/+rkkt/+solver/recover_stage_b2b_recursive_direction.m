function recovery = recover_stage_b2b_recursive_direction(lin,partition,responses,core)
%RECOVER_STAGE_B2B_RECURSIVE_DIRECTION Recover the canonical full direction.
arguments
    lin (1,1) struct
    partition (1,1) struct
    responses (:,1) struct
    core (1,1) struct
end
contract=rkkt.solver.stage_b2b_linearization_contract(lin);
assert(isequal(partition.linearization_identity,contract.identity)&& ...
    isequal(core.linearization_identity,contract.identity), ...
    "stageB2B:recovery:Identity","Recovery identities differ.");
deltaXi=zeros(contract.nx,1); deltaY=zeros(contract.neq,1);
deltaXi(contract.q_global)=core.delta_q; deltaY(contract.y_duration)=core.delta_rho;
deltaQDay=cell(contract.n_days,1); deltaPi=cell(contract.n_days,1);
vByDayHour=cell(contract.n_days,contract.n_hours); etaByDay=cell(contract.n_days,1);
for d=contract.n_days:-1:1
    k=find([responses.day_id]==contract.days(d),1); assert(~isempty(k),"stageB2B:recovery:Day","Missing day response.");
    r=responses(k); qd=core.delta_q+r.beta; pi=r.c-r.S*qd;
    deltaQDay{d}=qd; deltaPi{d}=pi;
    deltaXi(contract.q_day_by_day{d})=qd; deltaY(contract.y_binding_by_day{d})=pi;
    etaByDay{d}=r.eta0-r.etaQ*qd;
    for t=contract.n_hours:-1:1
        v=r.a_by_hour{t}-r.U_by_hour{t}*qd;
        nxh=numel(contract.x_by_day_hour{d,t}); neqH=numel(contract.y_by_day_hour{d,t});
        assert(numel(v)==nxh+neqH,"stageB2B:recovery:HourShape","Hourly recovery shape mismatch.");
        deltaXi(contract.x_by_day_hour{d,t})=v(1:nxh);
        deltaY(contract.y_by_day_hour{d,t})=v(nxh+1:end); vByDayHour{d,t}=v;
    end
end
deltaL=-contract.r_ineq-sparse(lin.G)*deltaXi;
deltaZ=(-contract.r_comp-contract.z.*deltaL)./contract.l;
assert(all(isfinite([deltaXi;deltaY;deltaL;deltaZ])),"stageB2B:recovery:Finite","Nonfinite recursive direction.");
waterEtaError=zeros(contract.n_days,1);
waterEtaRelative=zeros(contract.n_days,1);
for d=1:contract.n_days
    expectedEta=deltaZ(contract.water_by_day{d});
    waterEtaError(d)=norm(expectedEta-etaByDay{d},inf);
    waterEtaRelative(d)=norm(expectedEta-etaByDay{d},2)/ ...
        max(1,norm(expectedEta,2));
end
assert(max(waterEtaRelative)<=1e-10,"stageB2B:recovery:WaterEta", ...
    "Water border eta relative mismatch %.17g (max absolute %.17g).", ...
    max(waterEtaRelative),max(waterEtaError));
fixed=rkkt.solver.stage_a_multiday_fixed_zero_evidence(lin.index);
recovery=struct("stage_id","stage_B","milestone_id","B-2B", ...
    "linearization_identity",contract.identity,"direction",[deltaXi;deltaY;deltaL;deltaZ], ...
    "components",struct("xi",deltaXi,"y",deltaY,"l",deltaL,"z",deltaZ,"q",core.delta_q, ...
        "rho",core.delta_rho,"q_day_by_day",{deltaQDay},"pi_by_day",{deltaPi}, ...
        "v_by_day_hour",{vByDayHour},"eta_by_day",{etaByDay}), ...
    "fixed_zero",fixed, ...
    "no_full_direction_fallback",true,"full_direction_consumed",false, ...
    "diagnostics",struct("water_eta_max_error",max(waterEtaError), ...
        "water_eta_max_relative_error",max(waterEtaRelative), ...
        "delta_l_residual",norm(deltaL+contract.r_ineq+lin.G*deltaXi,inf), ...
        "delta_z_residual",norm(contract.l.*deltaZ+contract.r_comp+contract.z.*deltaL,inf), ...
        "strict_reverse_recovery",true));
end
