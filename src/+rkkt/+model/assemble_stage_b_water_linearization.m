function water = assemble_stage_b_water_linearization( ...
        xi,data,index,config)
%ASSEMBLE_STAGE_B_WATER_LINEARIZATION Build 56 nonlinear water rows.
%
% Values, Jacobian rows, offsets, and individual constraint Hessians are
% produced together from the current primal point.  This function performs
% no solve and no state update.

arguments
    xi (:,1) double
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

variables = index.variable_index;
waterIndex = index.water_constraint_index;
nPrimal = height(variables);
nWater = height(waterIndex);
assert(numel(xi)==nPrimal && nWater==56, ...
    "stageB2A:waterLinearization:Dimensions", ...
    "B-2A requires 3722 primal entries and 56 water rows.");

G = spalloc(nWater,nPrimal,24*nWater);
offset = zeros(nWater,1);
constraintValue = zeros(nWater,1);
waterValue = zeros(nWater,1);
boundValue = zeros(nWater,1);
signValue = zeros(nWater,1);
identityError = zeros(nWater,1);
gradientNnz = zeros(nWater,1);
hessianNnz = zeros(nWater,1);
hessianSymmetry = zeros(nWater,1);
constraintHessians = repmat(empty_hessian_record(),nWater,1);

tripletCount = 24*nWater;
triplet_constraint_id = strings(tripletCount,1);
triplet_inequality_position = zeros(tripletCount,1);
triplet_day = zeros(tripletCount,1);
triplet_hydro_id = zeros(tripletCount,1);
triplet_bound_type = strings(tripletCount,1);
triplet_row = zeros(tripletCount,1);
triplet_col = zeros(tripletCount,1);
triplet_value = zeros(tripletCount,1);

triplet = 0;
for row = 1:nWater
    day = waterIndex.day(row);
    hydro = waterIndex.hydro_id(row);
    side = string(waterIndex.bound_type(row));
    target = variables.day==day & variables.hour>0 & ...
        string(variables.asset_type)=="hydro" & ...
        variables.asset_id==hydro & ...
        string(variables.variable_name)=="PH";
    targetRows = variables(target,:);
    [~,order] = sort(targetRows.hour);
    targetRows = targetRows(order,:);
    assert(height(targetRows)==24 && ...
        isequal(targetRows.hour,(1:24).'), ...
        "stageB2A:waterLinearization:TargetColumns", ...
        "Each water row must touch exactly one 24-hour PH trajectory.");
    columns = targetRows.global_index_start;
    power = xi(columns);
    a = data.base.hydro.waterA(hydro);
    b = data.base.hydro.waterB(hydro);
    c = data.base.hydro.waterC(hydro);
    evaluation = rkkt.model.evaluate_stage_b_daily_hydro_water(power,a,b,c);
    if side=="upper"
        sign = 1;
        bound = data.timeseries.hydroWaterMax(day,hydro);
        value = evaluation.value-bound;
        gradient = evaluation.gradient;
        localHessian = evaluation.hessian;
    elseif side=="lower"
        sign = -1;
        bound = data.timeseries.hydroWaterMin(day,hydro);
        value = bound-evaluation.value;
        gradient = -evaluation.gradient;
        localHessian = -evaluation.hessian;
    else
        error("stageB2A:waterLinearization:BoundType", ...
            "Unsupported bound type %s.",side);
    end
    globalHessian = sparse(columns,columns,diag(localHessian), ...
        nPrimal,nPrimal);
    G(row,columns) = gradient.'; %#ok<SPRIX>
    offset(row) = value-G(row,:)*xi;
    constraintValue(row) = value;
    waterValue(row) = evaluation.value;
    boundValue(row) = bound;
    signValue(row) = sign;
    identityError(row) = abs(G(row,:)*xi+offset(row)-value);
    gradientNnz(row) = nnz(G(row,:));
    hessianNnz(row) = nnz(globalHessian);
    hessianSymmetry(row) = relative_symmetry_error(globalHessian);
    record = empty_hessian_record();
    record.constraint_id = string(waterIndex.constraint_id(row));
    record.inequality_position = waterIndex.inequality_position(row);
    record.global_constraint_row = waterIndex.global_row(row);
    record.day = day;
    record.hydro_id = hydro;
    record.bound_type = side;
    record.sign = sign;
    record.variable_indices = columns;
    record.local_hessian = localHessian;
    record.global_hessian = globalHessian;
    record.nnz = nnz(globalHessian);
    constraintHessians(row) = record;
    for hourPosition = 1:24
        triplet = triplet+1;
        triplet_constraint_id(triplet) = record.constraint_id;
        triplet_inequality_position(triplet) = ...
            record.inequality_position;
        triplet_day(triplet) = day;
        triplet_hydro_id(triplet) = hydro;
        triplet_bound_type(triplet) = side;
        triplet_row(triplet) = columns(hourPosition);
        triplet_col(triplet) = columns(hourPosition);
        triplet_value(triplet) = localHessian(hourPosition,hourPosition);
    end
end
assert(triplet==tripletCount, ...
    "stageB2A:waterLinearization:HessianTriplets", ...
    "Water Hessian triplet inventory is incomplete.");

water = struct();
water.G = G;
water.offset = offset;
water.constraint_value = constraintValue;
water.water_value = waterValue;
water.bound_value = boundValue;
water.sign = signValue;
water.identity_error = identityError;
water.constraint_hessians = constraintHessians;
water.hessian_triplets = table(triplet_constraint_id, ...
    triplet_inequality_position,triplet_day,triplet_hydro_id, ...
    triplet_bound_type,triplet_row,triplet_col,triplet_value, ...
    'VariableNames',{'constraint_id','inequality_position','day', ...
    'hydro_id','bound_type','row','column','value'});
water.row_audit = table(waterIndex.constraint_id,waterIndex.day, ...
    waterIndex.hydro_id,waterIndex.bound_type, ...
    waterIndex.inequality_position,waterIndex.touched_hour_count, ...
    waterIndex.touched_variable_indices,constraintValue,waterValue, ...
    boundValue,signValue,gradientNnz,hessianNnz,hessianSymmetry, ...
    identityError, ...
    'VariableNames',{'constraint_id','day','hydro_id','bound_type', ...
    'inequality_position','touched_hour_count', ...
    'touched_variable_indices','constraint_value','water_value', ...
    'bound_value','sign','jacobian_nnz','hessian_nnz', ...
    'hessian_symmetry_relative','linearization_identity_error'});
water.counts = struct("rows",nWater,"jacobian_nnz",nnz(G), ...
    "hessian_triplets",height(water.hessian_triplets));
water.maximum_identity_error = max(identityError);
water.maximum_hessian_symmetry_relative = max(hessianSymmetry);

assert(all(gradientNnz==24) && all(hessianNnz==24) && ...
    nnz(G)==24*nWater && ...
    max(identityError)<=64*eps(max(1,max(abs(constraintValue)))) && ...
    max(hessianSymmetry)<= ...
        config.lagrangian_hessian_symmetry_tolerance, ...
    "stageB2A:waterLinearization:StructureAudit", ...
    "Water value/Jacobian/Hessian structure is inconsistent.");
end

function value = relative_symmetry_error(matrix)
denominator = max(1,norm(matrix,"fro"));
value = norm(matrix-matrix.',"fro")/denominator;
end

function value = empty_hessian_record()
value = struct("constraint_id","","inequality_position",0, ...
    "global_constraint_row",0,"day",0,"hydro_id",0, ...
    "bound_type","","sign",0,"variable_indices",zeros(0,1), ...
    "local_hessian",sparse(0,0),"global_hessian",sparse(0,0), ...
    "nnz",0);
end
