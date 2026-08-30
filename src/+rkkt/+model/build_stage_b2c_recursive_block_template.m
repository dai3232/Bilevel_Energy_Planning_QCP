function template = build_stage_b2c_recursive_block_template(data,index,config)
%BUILD_STAGE_B2C_RECURSIVE_BLOCK_TEMPLATE Build the recursive operators directly.
%
% This is the production recursive-only structure.  It preserves every
% canonical vector position, but stores Jacobians and Hessians only as one
% small global block plus independent daily blocks.  It never constructs a
% horizon-wide H, A, or G matrix.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end
assert(string(config.milestone_id)=="B-2C" && ...
    string(index.scope.milestone_id)=="B-2C" && ...
    isequal(reshape(double(config.hours),1,[]),1:24), ...
    "stageB2C:recursiveTemplate:Identity", ...
    "The direct recursive template requires a complete-day B-2C index.");

parameters = rkkt.model.stage_a_capacity_parameters(data);
days = reshape(double(config.days),1,[]);
hours = reshape(double(config.hours),1,[]);
nDays = numel(days);
nx = index.counts.variables;
neq = index.counts.equalities;
nBaseInequality = index.stage_a_base_index.counts.inequalities;
nWater = height(index.water_constraint_index);
nineq = nBaseInequality+nWater;

blocks = index.block_index;
globalBlock = blocks(blocks.day==0 & blocks.hour_start==0,:);
assert(height(globalBlock)==1,"stageB2C:recursiveTemplate:GlobalBlock", ...
    "The canonical index must contain one global capacity block.");
qGlobal = (globalBlock.variable_start:globalBlock.variable_end).';
yDuration = (globalBlock.equality_start:globalBlock.equality_end).';
assert(isequal(qGlobal,(1:14).') && isequal(yDuration,(1:2).'), ...
    "stageB2C:recursiveTemplate:GlobalOrder", ...
    "The frozen global q/rho order changed.");

globalG = sparse(repelem((1:28).',1,1), ...
    repelem((1:14).',2,1),repmat([-1;1],14,1),28,14);
globalOffset = zeros(28,1);
globalOffset(1:2:end) = parameters.lower;
globalOffset(2:2:end) = -parameters.upper;
durationA = sparse(2,14);
for storage = 1:2
    durationA(storage,10+storage) = ...
        -parameters.storage_duration_hours(storage);
    durationA(storage,12+storage) = 1;
end

variables = index.variable_index;
waterIndex = index.water_constraint_index;
dayCells = cell(nDays,1);
qDayByDay = cell(nDays,1);
yBindingByDay = cell(nDays,1);
xByDayHour = cell(nDays,24);
yByDayHour = cell(nDays,24);
ineqByDayHour = cell(nDays,24);
waterByDay = cell(nDays,1);
dailyDimensions = zeros(1,nDays);
waterColumns = zeros(nWater,24);

hourlyPrimalStart = 14+14*nDays+1;
for d = 1:nDays
    dayId = days(d);
    capacityBlock = blocks(blocks.day==dayId & ...
        blocks.hour_start==0,:);
    hourBlocks = blocks(blocks.day==dayId & blocks.hour_start>0,:);
    [~,order] = sort(hourBlocks.hour_start);
    hourBlocks = hourBlocks(order,:);
    assert(height(capacityBlock)==1 && height(hourBlocks)==24 && ...
        isequal(reshape(double(hourBlocks.hour_start),1,[]),hours), ...
        "stageB2C:recursiveTemplate:DayBlocks", ...
        "Day %d does not have one capacity block and 24 hour blocks.",dayId);

    qDay = (capacityBlock.variable_start:capacityBlock.variable_end).';
    yBinding = (capacityBlock.equality_start:capacityBlock.equality_end).';
    xCells = cell(24,1);
    yCells = cell(24,1);
    ineqCells = cell(24,1);
    for t = 1:24
        xCells{t} = (hourBlocks.variable_start(t): ...
            hourBlocks.variable_end(t)).';
        yCells{t} = (hourBlocks.equality_start(t): ...
            hourBlocks.equality_end(t)).';
        firstOrdinal = xCells{t}(1)-hourlyPrimalStart+1;
        lastOrdinal = xCells{t}(end)-hourlyPrimalStart+1;
        ineqCells{t} = (28+2*firstOrdinal-1:28+2*lastOrdinal).';
        xByDayHour{d,t} = xCells{t};
        yByDayHour{d,t} = yCells{t};
        ineqByDayHour{d,t} = ineqCells{t};
    end
    xDay = vertcat(xCells{:});
    yHour = vertcat(yCells{:});
    baseRows = vertcat(ineqCells{:});
    localPrimal = [qDay;xDay];
    localEquality = [yBinding;yHour];
    nxLocal = numel(localPrimal);
    neqLocal = numel(localEquality);
    globalToLocal = zeros(nx,1);
    globalToLocal(localPrimal) = 1:nxLocal;

    equalityA = spalloc(neqLocal,nxLocal,14+12*24);
    equalityGlobalA = sparse(neqLocal,14);
    equalityOffset = zeros(neqLocal,1);
    equalityA(1:14,1:14) = speye(14);
    equalityGlobalA(1:14,:) = -speye(14);
    for t = 1:24
        xIndices = xCells{t};
        xRows = variables(xIndices,:);
        localColumns = globalToLocal(xIndices);
        localEqStart = 14+sum(cellfun(@numel,yCells(1:t-1)))+1;
        localEq = localEqStart:(localEqStart+numel(yCells{t})-1);
        names = string(xRows.variable_name);
        types = string(xRows.asset_type);
        assets = double(xRows.asset_id);

        coefficients = double(ismember(names,["PW","PP","PH","PF","Pdis"]))- ...
            double(names=="Pch");
        nonzero = coefficients~=0;
        equalityA(localEq(1),localColumns(nonzero)) = coefficients(nonzero);
        equalityOffset(localEq(1)) = -data.timeseries.planMW(dayId,t);

        for storage = 1:2
            pch = localColumns(types=="storage" & assets==storage & names=="Pch");
            pdis = localColumns(types=="storage" & assets==storage & names=="Pdis");
            soc = localColumns(types=="storage" & assets==storage & names=="SOC");
            assert(isscalar(pch) && isscalar(pdis) && isscalar(soc), ...
                "stageB2C:recursiveTemplate:StorageMap", ...
                "Day %d hour %d storage %d has an invalid active map.", ...
                dayId,t,storage);
            row = localEq(1+storage);
            equalityA(row,pch) = -parameters.charge_efficiency(storage)* ...
                data.meta.dtHours;
            equalityA(row,pdis) = data.meta.dtHours/ ...
                parameters.discharge_efficiency(storage);
            equalityA(row,soc) = 1;
            if t==1
                equalityA(row,12+storage) = -0.5;
            else
                priorIndices = xCells{t-1};
                priorRows = variables(priorIndices,:);
                prior = priorIndices(string(priorRows.asset_type)=="storage" & ...
                    priorRows.asset_id==storage & ...
                    string(priorRows.variable_name)=="SOC");
                equalityA(row,globalToLocal(prior)) = -1;
            end
        end
        if t==24
            assert(numel(localEq)==5, ...
                "stageB2C:recursiveTemplate:TerminalRows", ...
                "The final hour must contain two terminal SOC rows.");
            for storage = 1:2
                soc = localColumns(types=="storage" & assets==storage & names=="SOC");
                equalityA(localEq(3+storage),soc) = 1;
                equalityA(localEq(3+storage),12+storage) = -0.5;
            end
        else
            assert(numel(localEq)==3, ...
                "stageB2C:recursiveTemplate:HourlyRows", ...
                "A nonterminal hour must contain balance and two SOC rows.");
        end
    end

    nBaseRows = numel(baseRows);
    baseG = spalloc(nBaseRows,nxLocal,2*nBaseRows);
    baseOffset = zeros(nBaseRows,1);
    rowPosition = 0;
    for t = 1:24
        xIndices = xCells{t};
        xRows = variables(xIndices,:);
        localColumns = globalToLocal(xIndices);
        names = string(xRows.variable_name);
        types = string(xRows.asset_type);
        assets = double(xRows.asset_id);
        for k = 1:numel(xIndices)
            lowerRow = rowPosition+1;
            upperRow = rowPosition+2;
            column = localColumns(k);
            baseG(lowerRow,column) = -1;
            if names(k)=="SOC"
                baseG(lowerRow,12+assets(k)) = ...
                    parameters.soc_lower_fraction(assets(k));
            end
            baseG(upperRow,column) = 1;
            if types(k)=="wind"
                baseG(upperRow,assets(k)) = ...
                    -data.timeseries.windAvailability(dayId,t,assets(k));
            elseif types(k)=="solar"
                baseG(upperRow,5+assets(k)) = ...
                    -data.timeseries.solarAvailability(dayId,t,assets(k));
            elseif types(k)=="hydro"
                baseOffset(upperRow) = -data.base.hydro.maxOutputMW(assets(k));
            elseif types(k)=="thermal"
                baseOffset(upperRow) = -data.base.thermal.maxOutputMW(assets(k));
            elseif types(k)=="storage" && ismember(names(k),["Pch","Pdis"])
                baseG(upperRow,10+assets(k)) = -1;
            elseif types(k)=="storage" && names(k)=="SOC"
                baseG(upperRow,12+assets(k)) = ...
                    -parameters.soc_upper_fraction(assets(k));
            else
                error("stageB2C:recursiveTemplate:UpperBound", ...
                    "Unsupported upper bound at day %d hour %d.",dayId,t);
            end
            rowPosition = upperRow;
        end
    end
    assert(rowPosition==nBaseRows, ...
        "stageB2C:recursiveTemplate:BaseRows", ...
        "The daily base-inequality assembly is incomplete.");

    waterMask = waterIndex.day==dayId;
    waterRows = waterIndex.inequality_position(waterMask);
    waterLocalColumns = zeros(8,24);
    waterGlobalColumns = zeros(8,24);
    waterSign = zeros(8,1);
    waterBound = zeros(8,1);
    waterA = zeros(8,1); waterB = zeros(8,1); waterC = zeros(8,1);
    dayWaterIndex = waterIndex(waterMask,:);
    for w = 1:8
        hydro = dayWaterIndex.hydro_id(w);
        columns = zeros(24,1);
        for t = 1:24
            xIndices = xCells{t};
            xRows = variables(xIndices,:);
            match = string(xRows.asset_type)=="hydro" & ...
                xRows.asset_id==hydro & string(xRows.variable_name)=="PH";
            columns(t) = xIndices(match);
        end
        waterGlobalColumns(w,:) = columns;
        waterLocalColumns(w,:) = globalToLocal(columns);
        isUpper = string(dayWaterIndex.bound_type(w))=="upper";
        waterSign(w) = 2*double(isUpper)-1;
        if isUpper
            waterBound(w) = data.timeseries.hydroWaterMax(dayId,hydro);
        else
            waterBound(w) = data.timeseries.hydroWaterMin(dayId,hydro);
        end
        waterA(w) = data.base.hydro.waterA(hydro);
        waterB(w) = data.base.hydro.waterB(hydro);
        waterC(w) = data.base.hydro.waterC(hydro);
    end
    waterColumns(waterRows-nBaseInequality,:) = waterGlobalColumns;

    localPermutationCells = cell(2+2*24,1);
    localPermutationCells{1} = (1:14).';
    localPermutationCells{2} = nxLocal+(1:14).';
    position = 2;
    primalCursor = 14;
    equalityCursor = 14;
    for t = 1:24
        position = position+1;
        localPermutationCells{position} = primalCursor+(1:numel(xCells{t})).';
        primalCursor = primalCursor+numel(xCells{t});
        position = position+1;
        localPermutationCells{position} = nxLocal+equalityCursor+ ...
            (1:numel(yCells{t})).';
        equalityCursor = equalityCursor+numel(yCells{t});
    end
    localPermutation = vertcat(localPermutationCells{:});
    canonicalReducedIndices = [qDay;nx+yBinding];
    for t = 1:24
        canonicalReducedIndices = [canonicalReducedIndices; ...
            xCells{t};nx+yCells{t}]; %#ok<AGROW>
    end
    coupling = sparse(numel(localPermutation),16);
    couplingCanonical = [sparse(nxLocal,16); ...
        equalityGlobalA,sparse(neqLocal,2)];
    coupling = couplingCanonical(localPermutation,:);

    dayCells{d} = struct( ...
        "day_id",dayId,"primal_indices",localPrimal, ...
        "equality_indices",localEquality,"base_inequality_rows",baseRows, ...
        "water_rows",waterRows,"A_local",sparse(equalityA), ...
        "A_global",sparse(equalityGlobalA), ...
        "equality_offset",equalityOffset,"base_G",sparse(baseG), ...
        "base_inequality_offset",baseOffset, ...
        "water_local_columns",waterLocalColumns, ...
        "water_global_columns",waterGlobalColumns, ...
        "water_sign",waterSign,"water_bound",waterBound, ...
        "water_a",waterA,"water_b",waterB,"water_c",waterC, ...
        "local_reduced_permutation",localPermutation, ...
        "canonical_reduced_indices",canonicalReducedIndices, ...
        "coupling",coupling,"q_day_local_positions",(1:14).', ...
        "pi_day_local_positions",(15:28).', ...
        "hourly_local_positions",(29:numel(localPermutation)).', ...
        "hourly_dimension",numel(localPermutation)-28, ...
        "dimension",numel(localPermutation));
    qDayByDay{d} = qDay;
    yBindingByDay{d} = yBinding;
    waterByDay{d} = waterRows;
    dailyDimensions(d) = numel(localPermutation)-28;
end

maps = struct("days",days,"hours",hours,"q_global",qGlobal, ...
    "q_day",reshape(vertcat(qDayByDay{:}),14,nDays), ...
    "q_day_by_day",{qDayByDay},"y_duration",yDuration, ...
    "y_binding_by_day",{yBindingByDay}, ...
    "y_binding",vertcat(yBindingByDay{:}), ...
    "x_by_day_hour",{xByDayHour},"y_by_day_hour",{yByDayHour}, ...
    "ineq_global",(1:28).',"ineq_by_day_hour",{ineqByDayHour}, ...
    "water_by_day",{waterByDay}, ...
    "ineq_water",waterIndex.inequality_position(:));
maps.direction = struct("xi",(1:nx).',"y",nx+(1:neq).', ...
    "l",nx+neq+(1:nineq).',"z",nx+neq+nineq+(1:nineq).');

objectiveOriginal = zeros(nx,1);
objectiveOriginal(qGlobal) = parameters.cost;
scaleFactor = max(abs(parameters.cost));
objectiveScaled = objectiveOriginal/scaleFactor;
counts = struct("primal",nx,"equalities",neq,"inequalities",nineq, ...
    "water_inequalities",nWater,"full_kkt",nx+neq+2*nineq, ...
    "stage_a_full_kkt",nx+neq+2*nBaseInequality, ...
    "days",nDays,"hourly_chain",sum(dailyDimensions));
layout = struct("days",days,"hours",hours, ...
    "daily_chain_dimensions",dailyDimensions, ...
    "total_hourly_chain_dimension",sum(dailyDimensions));

template = struct( ...
    "version","stage-B2C-recursive-block-template-v1.0", ...
    "storage_mode","recursive_daily_blocks", ...
    "stage_id","stage_B","milestone_id","B-2C", ...
    "index_version",string(index.version),"days",days,"hours",hours, ...
    "n_primal",nx,"n_equalities",neq, ...
    "n_base_inequalities",nBaseInequality, ...
    "n_water_inequalities",nWater,"n_inequalities",nineq, ...
    "global_block",struct("q_indices",qGlobal,"y_duration",yDuration, ...
        "A",durationA,"G",globalG,"inequality_rows",(1:28).', ...
        "inequality_offset",globalOffset), ...
    "day",vertcat(dayCells{:}),"maps",maps,"layout",layout, ...
    "capacity_parameters",parameters, ...
    "objective_original_gradient",objectiveOriginal, ...
    "objective_scaled_gradient",objectiveScaled, ...
    "objective_scale_factor",scaleFactor,"counts",counts, ...
    "config",config,"model_contract_version","1.0", ...
    "input_hashes",lower(string(data.hashes.actualSHA256)));
template.water = struct("rows",waterIndex.inequality_position(:), ...
    "columns",waterColumns,"sign",repmat([1;-1],4*nDays,1), ...
    "bound_value",water_bounds(data,waterIndex), ...
    "water_a",double(data.base.hydro.waterA(waterIndex.hydro_id)), ...
    "water_b",double(data.base.hydro.waterB(waterIndex.hydro_id)), ...
    "water_c",double(data.base.hydro.waterC(waterIndex.hydro_id)), ...
    "hessian_coefficient",repmat([1;-1],4*nDays,1).* ...
        (2.*double(data.base.hydro.waterA(waterIndex.hydro_id))));

assert(counts.full_kkt==config.expected_full_kkt_dimension && ...
    isequal(dailyDimensions, ...
        config.expected_stage_a_daily_hourly_chain_dimensions) && ...
    numel(unique([qGlobal;vertcat(qDayByDay{:});vertcat(xByDayHour{:})]))==nx && ...
    numel(unique([yDuration;vertcat(yBindingByDay{:}); ...
        vertcat(yByDayHour{:})]))==neq, ...
    "stageB2C:recursiveTemplate:Contract", ...
    "The direct recursive template does not cover the canonical spaces.");
template.runtime = rkkt.model.build_stage_b2c_recursive_runtime_maps( ...
    data,index,template,config);
end

function value = water_bounds(data,waterIndex)
value = zeros(height(waterIndex),1);
for row = 1:height(waterIndex)
    if string(waterIndex.bound_type(row))=="upper"
        value(row) = data.timeseries.hydroWaterMax( ...
            waterIndex.day(row),waterIndex.hydro_id(row));
    else
        value(row) = data.timeseries.hydroWaterMin( ...
            waterIndex.day(row),waterIndex.hydro_id(row));
    end
end
end
