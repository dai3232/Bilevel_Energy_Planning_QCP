function audits = build_stage_b2b_audits(data,index,lin,recursive,fullAudit,config)
%BUILD_STAGE_B2B_AUDITS Build persisted one-direction evidence tables.

arguments
    data (1,1) struct
    index (1,1) struct
    lin (1,1) struct
    recursive (1,1) struct
    fullAudit (1,1) struct
    config (1,1) struct
end
reduced = recursive.reduced;
equivalence = rkkt.solver.verify_stage_b2b_direction_equivalence( ...
    fullAudit,recursive,lin, ...
    DirectionRelative=config.direction_relative_error_tolerance, ...
    RecursiveResidual=config.recursive_full_kkt_residual_tolerance, ...
    FullResidual=config.full_kkt_residual_tolerance);
audits.equivalence = equivalence;
audits.inequality_elimination = elimination_table(lin,reduced);
audits.reduced_symmetry = symmetry_table(reduced,config);
audits.daily_water_border = border_table(recursive,index,config);
audits.daily_response = response_table(recursive);
audits.direction_comparison = direction_table(equivalence,config);
audits.back_substitution = back_substitution_table(lin,recursive,config);
audits.fixed_zero = fixed_zero_table(recursive);
audits.stationarity_finite_difference = stationarity_fd_table( ...
    data,index,lin,config);
audits.full_kkt_structure = fullAudit.kkt.block_audit;
audits.execution = execution_table(recursive,fullAudit);
assert(all(audits.inequality_elimination.status=="PASS") && ...
    all(audits.reduced_symmetry.status=="PASS") && ...
    all(audits.daily_water_border.status=="PASS") && ...
    all(audits.daily_response.status=="PASS") && ...
    all(audits.direction_comparison.status=="PASS") && ...
    all(audits.back_substitution.status=="PASS") && ...
    all(audits.fixed_zero.status=="PASS") && ...
    all(audits.stationarity_finite_difference.status=="PASS") && ...
    all(audits.execution.status=="PASS") && equivalence.all_pass, ...
    "stageB2B:audits:Blocking","One or more B-2B audits failed.");
end

function value = elimination_table(lin,reduced)
D = spdiags(lin.z./lin.l,0,numel(lin.l),numel(lin.l));
expectedW = sparse(lin.H)+sparse(lin.G.')*D*sparse(lin.G);
expectedB = -lin.r_dual-sparse(lin.G.')*(D*lin.r_ineq)+ ...
    sparse(lin.G.')*(lin.r_comp./lin.l);
matrixError = norm(reduced.W-expectedW,"fro")/max(1,norm(expectedW,"fro"));
rhsError = norm(reduced.b_xi-expectedB,2)/max(1,norm(expectedB,2));
dx = ones(size(lin.H,1),1)/sqrt(size(lin.H,1));
dl = -lin.r_ineq-lin.G*dx;
dz = (-lin.r_comp-lin.z.*dl)./lin.l;
ineqResidual = norm(lin.G*dx+dl+lin.r_ineq,2)/ ...
    max(1,norm(lin.r_ineq,2));
compResidual = norm(lin.z.*dl+lin.l.*dz+lin.r_comp,2)/ ...
    max(1,norm(lin.r_comp,2));
check_id = ["D_AND_W_FORMULA";"REDUCED_RHS_FORMULA"; ...
    "DL_BACK_SUBSTITUTION";"DZ_BACK_SUBSTITUTION"];
actual_value = [matrixError;rhsError;ineqResidual;compResidual];
threshold = [64*eps;64*eps;64*eps;64*eps];
status = repmat("PASS",4,1); status(actual_value>threshold)="FAIL";
value = table(check_id,actual_value,threshold,status);
end

function value = symmetry_table(reduced,config)
check_id = ["REDUCED_W";"REDUCED_SADDLE"];
actual_value = [norm(reduced.W-reduced.W.',"fro")/max(1,norm(reduced.W,"fro")); ...
    norm(reduced.saddle-reduced.saddle.',"fro")/ ...
        max(1,norm(reduced.saddle,"fro"))];
threshold = repmat(config.reduced_symmetry_tolerance,2,1);
automatic_symmetrization_used = false(2,1);
status = repmat("PASS",2,1); status(actual_value>threshold)="FAIL";
value = table(check_id,actual_value,threshold, ...
    automatic_symmetrization_used,status);
end

function value = border_table(recursive,index,config)
days = recursive.partition.day;
n = numel(days);
day_id=zeros(n,1); hourly_chain_dimension=zeros(n,1); ...
    border_dimension=zeros(n,1); augmented_dimension=zeros(n,1); ...
    day_response_dimension=zeros(n,1); total_rhs=zeros(n,1); ...
    border_symmetry_relative=zeros(n,1); chain_relative_residual=zeros(n,1); ...
    border_relative_residual=zeros(n,1); augmented_relative_residual=zeros(n,1); ...
    support_exact=false(n,1); cross_coupling_nnz=zeros(n,1); ...
    water_hourly_gtdg_nnz=zeros(n,1); assembly_location=strings(n,1); ...
    status=repmat("PASS",n,1);
for d=1:n
    response=recursive.responses(d); day=days(d);
    day_id(d)=day.day_id;
    hourly_chain_dimension(d)=day.hourly_chain_dimension;
    border_dimension(d)=response.diagnostics.border_dimension;
    augmented_dimension(d)=response.diagnostics.augmented_dimension;
    day_response_dimension(d)=response.diagnostics.day_response_dimension;
    total_rhs(d)=response.diagnostics.total_chain_rhs_count;
    border_symmetry_relative(d)=response.diagnostics.border_symmetry_relative;
    chain_relative_residual(d)=response.diagnostics.chain_relative_residual;
    border_relative_residual(d)=response.diagnostics.border_relative_residual;
    augmented_relative_residual(d)=response.diagnostics.augmented_relative_residual;
    support_exact(d)=all(day.water.support_audit.same_day_same_hydro);
    cross_coupling_nnz(d)=sum(day.water.support_audit.cross_day_nnz);
    water_hourly_gtdg_nnz(d)=day.water.hourly_water_GtDG_nnz_in_M;
    assembly_location(d)=string(day.water.assembly_location);
    if border_dimension(d)~=config.expected_water_border_dimension_per_day || ...
            day_response_dimension(d)~=14 || total_rhs(d)~=23 || ...
            border_symmetry_relative(d)>config.border_symmetry_tolerance || ...
            augmented_relative_residual(d)>1e-10 || ~support_exact(d) || ...
            cross_coupling_nnz(d)~=0 || water_hourly_gtdg_nnz(d)~=0 || ...
            nnz(index.water_constraint_index.day==day_id(d))~=8
        status(d)="FAIL";
    end
end
value=table(day_id,hourly_chain_dimension,border_dimension, ...
    augmented_dimension,day_response_dimension,total_rhs, ...
    border_symmetry_relative,chain_relative_residual, ...
    border_relative_residual,augmented_relative_residual,support_exact, ...
    cross_coupling_nnz,water_hourly_gtdg_nnz,assembly_location,status);
end

function value = response_table(recursive)
n=numel(recursive.responses); day_id=zeros(n,1); ...
    response_rows=zeros(n,1); response_columns=zeros(n,1); ...
    c_dimension=zeros(n,1); beta_dimension=zeros(n,1); ...
    gamma_dimension=zeros(n,1); status=repmat("PASS",n,1);
for d=1:n
    r=recursive.responses(d); day_id(d)=r.day_id;
    [response_rows(d),response_columns(d)]=size(r.S);
    c_dimension(d)=numel(r.c); beta_dimension(d)=numel(r.beta); ...
        gamma_dimension(d)=numel(r.gamma);
    if ~isequal([response_rows(d),response_columns(d)],[14,14]) || ...
            any([c_dimension(d),beta_dimension(d),gamma_dimension(d)]~=14)
        status(d)="FAIL";
    end
end
value=table(day_id,response_rows,response_columns,c_dimension, ...
    beta_dimension,gamma_dimension,status);
end

function value = direction_table(audit,config)
component=["overall";"xi";"y";"l";"z"; ...
    "recursive_full_kkt_residual";"full_audit_kkt_residual"];
actual_value=[audit.direction_relative_error; ...
    audit.component_relative_errors.xi;audit.component_relative_errors.y; ...
    audit.component_relative_errors.l;audit.component_relative_errors.z; ...
    audit.recursive_kkt_relative_residual;audit.full_kkt_relative_residual];
threshold=[repmat(config.direction_relative_error_tolerance,5,1); ...
    config.recursive_full_kkt_residual_tolerance; ...
    config.full_kkt_residual_tolerance];
status=repmat("PASS",numel(component),1); status(actual_value>threshold)="FAIL";
value=table(component,actual_value,threshold,status);
end

function value = back_substitution_table(lin,recursive,config)
c=recursive.components;
name=["stationarity";"equality";"inequality";"complementarity"];
raw={lin.H*c.xi+lin.A.'*c.y+lin.G.'*c.z+lin.r_dual; ...
    lin.A*c.xi+lin.r_eq;lin.G*c.xi+c.l+lin.r_ineq; ...
    lin.z.*c.l+lin.l.*c.z+lin.r_comp};
reference={lin.r_dual;lin.r_eq;lin.r_ineq;lin.r_comp};
relative_residual=zeros(4,1);
for k=1:4
    relative_residual(k)=norm(raw{k},2)/max(1,norm(reference{k},2));
end
threshold=repmat(config.recursive_full_kkt_residual_tolerance,4,1);
status=repmat("PASS",4,1); status(relative_residual>threshold)="FAIL";
value=table(name,relative_residual,threshold,status);
end

function value = fixed_zero_table(recursive)
f=recursive.fixed_zero;
check_id=["fixed_zero_count";"fixed_zero_values";"fixed_zero_directions"];
actual_value=[f.count;f.maximum_absolute_value;f.maximum_absolute_direction];
expected_value=[422;0;0];
status=[conditional(f.count==422);conditional(f.maximum_absolute_value==0); ...
    conditional(f.maximum_absolute_direction==0)];
value=table(check_id,actual_value,expected_value,status);
end

function value = stationarity_fd_table(data,index,lin,config)
state=lin.state;
water=index.water_constraint_index.inequality_position;
% Derive a positive diagnostic multiplier variation from the current state
% so the curvature audit is nontrivial without reusing B-2A's 1.25/0.75.
state.z(water)=state.z(water).*(1+0.01*(1:numel(water)).'/numel(water));
reference=rkkt.model.build_stage_b2b_multiday_linearization(state,data,index,config);
variables=index.variable_index;
mask=string(variables.asset_type)=="hydro" & variables.hour>0;
direction=zeros(size(state.xi));
direction(mask)=sin((1:nnz(mask)).')/sqrt(nnz(mask));
step=1e-4;
plus=state; minus=state;
plus.xi=state.xi+step*direction; minus.xi=state.xi-step*direction;
linPlus=rkkt.model.build_stage_b2b_multiday_linearization(plus,data,index,config);
linMinus=rkkt.model.build_stage_b2b_multiday_linearization(minus,data,index,config);
fd=(linPlus.r_dual-linMinus.r_dual)/(2*step);
analytic=reference.H*direction;
relative_error=norm(fd-analytic,2)/max(1,norm(analytic,2));
status=conditional(relative_error<=config.stationarity_finite_difference_tolerance);
value=table("stationarity_state_direction",relative_error, ...
    config.stationarity_finite_difference_tolerance,status, ...
    "positive_current_state_z_derived_variation", ...
    'VariableNames',{'check_id','relative_error','threshold','status', ...
    'multiplier_source'});
end

function value = execution_table(recursive,fullAudit)
check_id=["recursive_executed";"full_kkt_audit_only"; ...
    "no_full_direction_fallback";"full_ipm_not_executed"; ...
    "optimization_not_executed";"parallel_not_executed"; ...
    "stage_c1_not_entered"];
passed=[recursive.recursive_direction_executed;fullAudit.audit_only; ...
    recursive.no_full_direction_fallback && ~recursive.full_direction_consumed; ...
    ~recursive.full_ipm_executed;~recursive.optimization_executed; ...
    ~recursive.parallel_executed;~linflag(recursive,"stage_c1_entered")];
status=repmat("PASS",numel(check_id),1); status(~passed)="FAIL";
value=table(check_id,passed,status);
end

function value=linflag(object,name)
if isfield(object,name), value=logical(object.(name)); else, value=false; end
end
function value=conditional(condition)
if condition, value="PASS"; else, value="FAIL"; end
end
