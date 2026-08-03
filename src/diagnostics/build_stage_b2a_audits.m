function audits = build_stage_b2a_audits(data,index,linearization,kkt,config)
%BUILD_STAGE_B2A_AUDITS Build persisted B-2A structure/derivative evidence.

audits = struct();
audits.water_constraint_index = index_audit(index,linearization);
audits.water_constraint_derivative = derivative_audit( ...
    data,index,linearization,config);
audits.linearization_identity = identity_audit(linearization,kkt);
audits.lagrangian_hessian = hessian_audit(linearization,config);
audits.full_kkt_structure = kkt_audit(kkt);
end

function value = index_audit(index,lin)
w = index.water_constraint_index;
v = index.variable_index;
n = height(w);
jacobian_nnz = zeros(n,1);
target_columns_exact = false(n,1);
cross_day_zero = false(n,1);
cross_asset_zero = false(n,1);
opposite_pair_gradient = false(n,1);
row_unique = false(n,1);
status = repmat("FAIL",n,1);
for k = 1:n
    row = lin.G(w.inequality_position(k),:);
    columns = find(row).';
    target = v.day==w.day(k) & v.hour>0 & ...
        string(v.asset_type)=="hydro" & v.asset_id==w.hydro_id(k) & ...
        string(v.variable_name)=="PH";
    expected = sort(v.global_index_start(target)).';
    jacobian_nnz(k) = nnz(row);
    target_columns_exact(k) = isequal(columns,expected);
    cross_day_zero(k) = ~any(v.day(columns)~=w.day(k));
    cross_asset_zero(k) = ~any(v.asset_id(columns)~=w.hydro_id(k) | ...
        string(v.asset_type(columns))~="hydro");
    if mod(k,2)==1
        pair = k+1;
    else
        pair = k-1;
    end
    opposite_pair_gradient(k) = ...
        nnz(row+lin.G(w.inequality_position(pair),:))==0;
    row_unique(k) = nnz(w.global_row==w.global_row(k))==1 && ...
        nnz(w.inequality_position==w.inequality_position(k))==1 && ...
        nnz(w.constraint_id==w.constraint_id(k))==1;
    if jacobian_nnz(k)==24 && target_columns_exact(k) && ...
            cross_day_zero(k) && cross_asset_zero(k) && ...
            opposite_pair_gradient(k) && row_unique(k)
        status(k) = "PASS";
    end
end
value = [w,table(jacobian_nnz,target_columns_exact,cross_day_zero, ...
    cross_asset_zero,opposite_pair_gradient,row_unique,status)];
end

function value = derivative_audit(data,index,lin,config)
[b1,~] = run_stage_b1_derivative_checks(data);
w = index.water_constraint_index;
n = height(w);
gradient_relative_error = zeros(n,1);
hessian_relative_error = zeros(n,1);
value_identity_error = zeros(n,1);
jacobian_sign_pass = false(n,1);
hessian_sign_pass = false(n,1);
hessian_sparse_diagonal_pass = false(n,1);
sign_status = repmat("FAIL",n,1);
status = repmat("FAIL",n,1);
for k = 1:n
    source = b1.day==w.day(k) & b1.hydro_id==w.hydro_id(k) & ...
        string(b1.test_point_id)=="internal";
    assert(nnz(source)==1,"stageB2A:audit:DerivativeSource", ...
        "Each water row requires one B-1 internal derivative sample.");
    gradient_relative_error(k) = b1.gradient_relative_error(source);
    hessian_relative_error(k) = b1.hessian_relative_error(source);
    local = k;
    record = lin.hessian.constraint_water(local);
    if mod(k,2)==1
        pair = k+1;
    else
        pair = k-1;
    end
    jacobian_sign_pass(k) = nnz( ...
        lin.constraints.water.G(k,:)+ ...
        lin.constraints.water.G(pair,:))==0;
    hessian_sign_pass(k) = nnz(record.global_hessian+ ...
        lin.hessian.constraint_water(pair).global_hessian)==0;
    localH = record.local_hessian;
    hessian_sparse_diagonal_pass(k) = issparse(localH) && ...
        nnz(localH)==24 && ...
        nnz(localH-spdiags(diag(localH),0,24,24))==0;
    value_identity_error(k) = lin.constraints.water.identity_error(k);
    if jacobian_sign_pass(k) && hessian_sign_pass(k)
        sign_status(k) = "PASS";
    end
    if gradient_relative_error(k)<= ...
            config.derivative_relative_error_threshold && ...
            hessian_relative_error(k)<= ...
            config.derivative_relative_error_threshold && ...
            value_identity_error(k)<=64*eps(max(1, ...
            abs(lin.constraints.water.constraint_value(k)))) && ...
            sign_status(k)=="PASS" && hessian_sparse_diagonal_pass(k)
        status(k) = "PASS";
    end
end
value = table(w.constraint_id,w.day,w.hydro_id,w.bound_type, ...
    gradient_relative_error,hessian_relative_error,value_identity_error, ...
    jacobian_sign_pass,hessian_sign_pass,hessian_sparse_diagonal_pass, ...
    sign_status,status, ...
    'VariableNames',{'constraint_id','day','hydro_id','bound_type', ...
    'gradient_relative_error','hessian_relative_error', ...
    'value_identity_error','jacobian_sign_pass','hessian_sign_pass', ...
    'hessian_sparse_diagonal_pass','sign_status','status'});
end

function value = identity_audit(lin,kkt)
check_id = ["all_inequality_Gx_offset";"water_Gx_offset"; ...
    "kkt_linearization_identity";"kkt_rhs_same_residual"];
identity_error = [lin.linearization_identity_error; ...
    max(lin.constraints.water.identity_error); ...
    double(string(kkt.linearization_identity)~=string(lin.identity)); ...
    norm(kkt.rhs-[-lin.r_dual;-lin.r_eq;-lin.r_ineq;-lin.r_comp],inf)];
threshold = [64*eps(max(1,norm(lin.constraints.ineq,inf))); ...
    64*eps(max(1,norm(lin.constraints.water.constraint_value,inf)));0;0];
actual = ["G*x+offset reproduces all values"; ...
    "Gwater*x+offset reproduces 56 nonlinear values"; ...
    string(kkt.linearization_identity);"exact persisted residual ordering"];
status = repmat("FAIL",4,1);
status(identity_error<=threshold) = "PASS";
value = table(check_id,identity_error,threshold,actual,status);
end

function value = hessian_audit(lin,config)
weighted = lin.objective.hessian;
for k = 1:numel(lin.hessian.constraint_water)
    h = lin.hessian.constraint_water(k);
    weighted = weighted+lin.z(h.inequality_position)*h.global_hessian;
end
check_id = ["objective_hessian_separate_zero"; ...
    "individual_water_hessians_signed_sparse"; ...
    "z_weighted_lagrangian_hessian_rebuilt"; ...
    "lagrangian_hessian_symmetry"];
actual_value = [nnz(lin.objective.hessian); ...
    sum([lin.hessian.constraint_water.nnz]); ...
    norm(weighted-lin.H,"fro"); ...
    lin.lagrangian_hessian_symmetry_relative];
threshold = [0;56*24;0;config.lagrangian_hessian_symmetry_tolerance];
comparison = ["equal";"equal";"less_or_equal";"less_or_equal"];
status = repmat("FAIL",4,1);
status(1) = conditional(actual_value(1)==threshold(1));
status(2) = conditional(actual_value(2)==threshold(2));
status(3) = conditional(actual_value(3)<=threshold(3));
status(4) = conditional(actual_value(4)<=threshold(4));
value = table(check_id,actual_value,threshold,comparison,status);
end

function value = kkt_audit(kkt)
value = kkt.blocks;
value.full_kkt_dimension = repmat(kkt.dimension,height(value),1);
value.full_kkt_nnz = repmat(kkt.nnz,height(value),1);
value.raw_full_kkt_symmetry_relative = repmat( ...
    kkt.symmetry.raw_full_kkt_relative,height(value),1);
value.raw_full_kkt_symmetry_status = repmat( ...
    string(kkt.symmetry.raw_full_kkt_status),height(value),1);
value.hessian_symmetry_relative = repmat( ...
    kkt.symmetry.hessian_relative,height(value),1);
value.full_kkt_solved = false(height(value),1);
value.recursive_direction_executed = false(height(value),1);
end

function value = conditional(condition)
if condition, value="PASS"; else, value="FAIL"; end
end
