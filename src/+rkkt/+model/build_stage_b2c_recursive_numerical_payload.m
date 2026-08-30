function payload = build_stage_b2c_recursive_numerical_payload( ...
        data,structure,config)
%BUILD_STAGE_B2C_RECURSIVE_NUMERICAL_PAYLOAD Fill current model numerics.

% The structural cache supplies only compact integer topology.  This
% function rebuilds every data-dependent coefficient on each invocation.

arguments
    data (1,1) struct
    structure (1,1) struct
    config (1,1) struct
end
assert(string(structure.version)=="stage-B2C-recursive-structure-v1.0" && ...
    isequal(double(structure.scope.days),double(config.days)) && ...
    isequal(double(structure.scope.hours),double(config.hours)), ...
    "stageB2C:recursiveNumerical:Structure", ...
    "The numerical payload requires the matching compact structure.");

parameters = rkkt.model.stage_a_capacity_parameters(data);
days = reshape(double(config.days),1,[]);
nDays = numel(days);
nx = structure.counts.variables;
neq = structure.counts.equalities;
nBase = structure.counts.base_inequalities;
nWater = structure.counts.water_inequalities;
nineq = structure.counts.inequalities;
maps = structure.maps;
maps.direction = struct( ...
    "xi",double(maps.direction.xi),"y",double(maps.direction.y), ...
    "l",double(maps.direction.l),"z",double(maps.direction.z));

globalG = sparse(repelem((1:28).',1,1), ...
    repelem((1:14).',2,1),repmat([-1;1],14,1),28,14);
globalOffset = zeros(28,1);
globalOffset(1:2:end) = parameters.lower;
globalOffset(2:2:end) = -parameters.upper;
durationA = sparse(2,14);
for storage = 1:data.meta.nStorage
    durationA(storage,10+storage) = ...
        -parameters.storage_duration_hours(storage);
    durationA(storage,12+storage) = 1;
end

dayCells = cell(nDays,1);
waterColumns = zeros(nWater,24);
for d = 1:nDays
    fixed = structure.day(d);
    dayId = double(fixed.day_id);
    p = double(fixed.primal_indices);
    e = double(fixed.equality_indices);
    xCells = fixed.x_by_hour;
    yCells = fixed.y_by_hour;
    nxLocal = numel(p);
    neqLocal = numel(e);
    qDay = double(p(1:14));
    xDay = double(p(15:end));
    localX = 14+(1:numel(xDay)).';

    equalityA = spalloc(neqLocal,nxLocal,14+12*24);
    equalityGlobalA = sparse(neqLocal,14);
    equalityOffset = zeros(neqLocal,1);
    equalityA(1:14,1:14) = speye(14);
    equalityGlobalA(1:14,:) = -speye(14);
    descriptorCursor = 0;
    localEqualityCursor = 14;
    priorSoc = zeros(data.meta.nStorage,1);
    for t = 1:24
        count = numel(xCells{t});
        local = localX(descriptorCursor+(1:count));
        type = double(fixed.hourly_asset_type( ...
            descriptorCursor+(1:count)));
        asset = double(fixed.hourly_asset_id( ...
            descriptorCursor+(1:count)));
        variable = double(fixed.hourly_variable_code( ...
            descriptorCursor+(1:count)));
        localRows = localEqualityCursor+(1:numel(yCells{t}));
        coefficient = double(ismember(variable,[1,2,3,4,6]))- ...
            double(variable==5);
        equalityA(localRows(1),local(coefficient~=0)) = ...
            coefficient(coefficient~=0);
        equalityOffset(localRows(1)) = -data.timeseries.planMW(dayId,t);
        for storage = 1:data.meta.nStorage
            pch = local(type==5 & asset==storage & variable==5);
            pdis = local(type==5 & asset==storage & variable==6);
            soc = local(type==5 & asset==storage & variable==7);
            row = localRows(1+storage);
            equalityA(row,pch) = -parameters.charge_efficiency(storage)* ...
                data.meta.dtHours;
            equalityA(row,pdis) = data.meta.dtHours/ ...
                parameters.discharge_efficiency(storage);
            equalityA(row,soc) = 1;
            if t==1
                equalityA(row,12+storage) = -0.5;
            else
                equalityA(row,priorSoc(storage)) = -1;
            end
            priorSoc(storage) = soc;
            if t==24
                equalityA(localRows(3+storage),soc) = 1;
                equalityA(localRows(3+storage),12+storage) = -0.5;
            end
        end
        descriptorCursor = descriptorCursor+count;
        localEqualityCursor = localEqualityCursor+numel(yCells{t});
    end

    nBaseRows = numel(fixed.base_inequality_rows);
    baseG = spalloc(nBaseRows,nxLocal,2*nBaseRows);
    baseOffset = zeros(nBaseRows,1);
    for k = 1:numel(xDay)
        lowerRow = 2*k-1;
        upperRow = 2*k;
        column = localX(k);
        type = double(fixed.hourly_asset_type(k));
        asset = double(fixed.hourly_asset_id(k));
        variable = double(fixed.hourly_variable_code(k));
        hour = double(fixed.hourly_hour(k));
        baseG(lowerRow,column) = -1;
        if variable==7
            baseG(lowerRow,12+asset) = ...
                parameters.soc_lower_fraction(asset);
        end
        baseG(upperRow,column) = 1;
        if type==1
            baseG(upperRow,asset) = ...
                -data.timeseries.windAvailability(dayId,hour,asset);
        elseif type==2
            baseG(upperRow,5+asset) = ...
                -data.timeseries.solarAvailability(dayId,hour,asset);
        elseif type==3
            baseOffset(upperRow) = -data.base.hydro.maxOutputMW(asset);
        elseif type==4
            baseOffset(upperRow) = -data.base.thermal.maxOutputMW(asset);
        elseif variable==5 || variable==6
            baseG(upperRow,10+asset) = -1;
        elseif variable==7
            baseG(upperRow,12+asset) = ...
                -parameters.soc_upper_fraction(asset);
        else
            error("stageB2C:recursiveNumerical:UpperBound", ...
                "The compact descriptor contains an unsupported bound.");
        end
    end

    waterGlobalColumns = double(fixed.water_global_columns);
    waterLocalColumns = double(fixed.water_local_columns);
    waterRows = double(fixed.water_rows);
    waterColumns(waterRows-nBase,:) = waterGlobalColumns;
    waterSign = repmat([1;-1],data.meta.nHydro,1);
    waterBound = zeros(2*data.meta.nHydro,1);
    waterA = zeros(2*data.meta.nHydro,1);
    waterB = zeros(2*data.meta.nHydro,1);
    waterC = zeros(2*data.meta.nHydro,1);
    for hydro = 1:data.meta.nHydro
        upper = 2*hydro-1;
        lowerIndex = 2*hydro;
        waterBound(upper) = data.timeseries.hydroWaterMax(dayId,hydro);
        waterBound(lowerIndex) = data.timeseries.hydroWaterMin(dayId,hydro);
        waterA([upper,lowerIndex]) = data.base.hydro.waterA(hydro);
        waterB([upper,lowerIndex]) = data.base.hydro.waterB(hydro);
        waterC([upper,lowerIndex]) = data.base.hydro.waterC(hydro);
    end
    dayCells{d} = struct( ...
        "day_id",dayId,"primal_indices",p, ...
        "equality_indices",e, ...
        "base_inequality_rows",double(fixed.base_inequality_rows), ...
        "water_rows",waterRows,"A_local",sparse(equalityA), ...
        "A_global",sparse(equalityGlobalA), ...
        "equality_offset",equalityOffset,"base_G",sparse(baseG), ...
        "base_inequality_offset",baseOffset, ...
        "water_local_columns",waterLocalColumns, ...
        "water_global_columns",waterGlobalColumns, ...
        "water_sign",waterSign,"water_bound",waterBound, ...
        "water_a",waterA,"water_b",waterB,"water_c",waterC, ...
        "local_reduced_permutation", ...
            double(fixed.local_reduced_permutation), ...
        "canonical_reduced_indices", ...
            double(fixed.canonical_reduced_indices), ...
        "coupling",fixed.coupling, ...
        "q_day_local_positions",double(fixed.q_day_local_positions), ...
        "pi_day_local_positions",double(fixed.pi_day_local_positions), ...
        "hourly_local_positions",double(fixed.hourly_local_positions), ...
        "hourly_dimension",double(fixed.hourly_dimension), ...
        "dimension",double(fixed.dimension));
    assert(isequal(qDay,double(maps.q_day_by_day{d})), ...
        "stageB2C:recursiveNumerical:DayCapacity", ...
        "The direct day-capacity positions changed.");
end

objectiveOriginal = zeros(nx,1);
objectiveOriginal(double(maps.q_global)) = parameters.cost;
scaleFactor = max(abs(parameters.cost));
objectiveScaled = objectiveOriginal/scaleFactor;
counts = struct("primal",nx,"equalities",neq,"inequalities",nineq, ...
    "water_inequalities",nWater,"full_kkt", ...
        structure.counts.full_kkt_dimension, ...
    "stage_a_full_kkt",nx+neq+2*nBase, ...
    "days",nDays,"hourly_chain", ...
        structure.layout.total_hourly_chain_dimension);
template = struct();
template.version = "stage-B2C-recursive-block-template-v1.0";
template.storage_mode = "recursive_daily_blocks";
template.stage_id = "stage_B";
template.milestone_id = "B-2C";
template.index_version = string(structure.index_version);
template.days = days;
template.hours = double(config.hours);
template.n_primal = nx;
template.n_equalities = neq;
template.n_base_inequalities = nBase;
template.n_water_inequalities = nWater;
template.n_inequalities = nineq;
template.global_block = struct("q_indices",double(maps.q_global), ...
    "y_duration",double(maps.y_duration),"A",durationA, ...
    "G",globalG,"inequality_rows",(1:28).', ...
    "inequality_offset",globalOffset);
template.day = vertcat(dayCells{:});
template.maps = maps;
template.layout = structure.layout;
template.capacity_parameters = parameters;
template.objective_original_gradient = objectiveOriginal;
template.objective_scaled_gradient = objectiveScaled;
template.objective_scale_factor = scaleFactor;
template.counts = counts;
template.config = config;
template.model_contract_version = "1.0";
assert(isscalar(template),"stageB2C:recursiveNumerical:TemplateScalar", ...
    "The numerical template must remain a scalar structure.");
inputHashes = cellstr(lower(string(data.hashes.actualSHA256)));
template = setfield(template,"input_hashes",inputHashes); %#ok<SFLD>
template.water = struct( ...
    "rows",double(maps.ineq_water(:)),"columns",waterColumns, ...
    "sign",repmat([1;-1],data.meta.nHydro*nDays,1), ...
    "bound_value",water_bounds(data,days), ...
    "water_a",repmat(repelem(double(data.base.hydro.waterA),2,1), ...
        nDays,1), ...
    "water_b",repmat(repelem(double(data.base.hydro.waterB),2,1), ...
        nDays,1), ...
    "water_c",repmat(repelem(double(data.base.hydro.waterC),2,1), ...
        nDays,1), ...
    "hessian_coefficient",repmat([1;-1],data.meta.nHydro*nDays,1).* ...
        repmat(repelem(2.*double(data.base.hydro.waterA),2,1),nDays,1));
template.runtime = structure.runtime;

dataIdentity = struct();
dataIdentity.input_hashes = cellstr(lower(string( ...
    data.hashes.actualSHA256)));
dataIdentity.load_correction_sha256 = char(lower(string( ...
    data.load_correction.sha256)));
payload = struct( ...
    "version","stage-B2C-recursive-numerical-payload-v1.0", ...
    "schema","stage-b2c-recursive-numerical-payload-v1", ...
    "topology_fingerprint",string(structure.topology_fingerprint), ...
    "scope",structure.scope,"counts",structure.counts, ...
    "runtime",structure.runtime,"template",template, ...
    "data_identity",dataIdentity);
assert(payload.counts.full_kkt_dimension== ...
        config.expected_full_kkt_dimension && ...
    numel(payload.template.day)==nDays, ...
    "stageB2C:recursiveNumerical:Contract", ...
    "The current numerical payload failed the compact structure contract.");
end

function value = water_bounds(data,days)
value = zeros(2*data.meta.nHydro*numel(days),1);
cursor = 0;
for day = days
    for hydro = 1:data.meta.nHydro
        cursor = cursor+1;
        value(cursor) = data.timeseries.hydroWaterMax(day,hydro);
        cursor = cursor+1;
        value(cursor) = data.timeseries.hydroWaterMin(day,hydro);
    end
end
end
