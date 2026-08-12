function fixture = build_stage_b2c_initial_day_scan_fixture( ...
        data,days,referenceConfig,runId)
%BUILD_STAGE_B2C_INITIAL_DAY_SCAN_FIXTURE Form initialization day blocks.
%
% This diagnostic builder keeps the production Stage-A assembly and the
% approved daily-water evaluator.  It forms only the fully eliminated
% reduced matrix needed to inspect independent day blocks; it does not
% assemble a full KKT matrix, compute a Newton direction, or update state.

arguments
    data (1,1) struct
    days (1,:) double {mustBeInteger,mustBePositive}
    referenceConfig (1,1) struct
    runId (1,1) string
end

hours = 1:24;
baseConfig = referenceConfig.stage_a_compatibility;
baseConfig.days = days;
baseConfig.hours = hours;
baseConfig.aggregation_day_order = days;
baseConfig.start_hour = 1;
baseConfig.terminal_hour = 24;
baseConfig.soc_boundary_mode = "formal_daily_fixed_half_energy";

index = rkkt.indexing.build_canonical_index_framework( ...
    data,days,hours,[],runId);
index.scope.stage_id = "stage_A4";
index.scope.time_scope_type = baseConfig.time_scope_type;
index.scope.run_purpose = ...
    "stage_B_2C_initial_point_daily_joint_block_prevalence_scan";
index.scope.aggregation_day_order = days;

dailyDimensions = daily_chain_dimensions(index,days);
baseConfig.expected_full_kkt_dimension = ...
    index.counts.full_kkt_dimension;
baseConfig.expected_daily_hourly_chain_dimensions = dailyDimensions;
baseConfig.expected_total_hourly_chain_dimension = sum(dailyDimensions);
baseConfig.expected_fixed_zero_count = height(index.fixed_zero_map);

state = rkkt.model.initialize_stage_a_multiday_state( ...
    data,index,baseConfig);
state.iteration_index = 0;
state.state_revision = 0;
state.newton_direction_number = 0;
state.completed_newton_direction_count = 0;
baseLinearization = rkkt.model.build_stage_a_multiday_linearization( ...
    state,data,index,baseConfig,"SlackMode","initialize");

[waterG,waterL,waterZ,waterHessian,waterRowsByDay] = ...
    assemble_water_extension(baseLinearization.state.xi,data,index, ...
        days,referenceConfig.initialization.inequality_multiplier);
G = [baseLinearization.G;waterG];
l = [baseLinearization.l;waterL];
z = [baseLinearization.z;waterZ];
H = baseLinearization.H+waterHessian;
theta = z./l;
W = H+G.'*(spdiags(theta,0,numel(theta),numel(theta))*G);
A = baseLinearization.A;
nx = size(W,1);
neq = size(A,1);
saddle = [W,A.';A,sparse(neq,neq)];

globalIndices = [baseLinearization.maps.q_global; ...
    nx+baseLinearization.maps.y_duration];
dayBlocks = repmat(day_template(),numel(days),1);
for dayPosition = 1:numel(days)
    hourlyIndices = zeros(0,1);
    for hourPosition = 1:numel(hours)
        hourlyIndices = [hourlyIndices; ...
            baseLinearization.maps.x_by_day_hour{dayPosition,hourPosition}; ...
            nx+baseLinearization.maps.y_by_day_hour{dayPosition,hourPosition}]; %#ok<AGROW>
    end
    localIndices = [baseLinearization.maps.q_day_by_day{dayPosition}; ...
        nx+baseLinearization.maps.y_binding_by_day{dayPosition}; ...
        hourlyIndices];
    matrix = sparse(saddle(localIndices,localIndices));
    dayWaterRows = waterRowsByDay{dayPosition};
    dayBlocks(dayPosition) = struct( ...
        "day_id",days(dayPosition), ...
        "canonical_reduced_indices",localIndices, ...
        "matrix",matrix, ...
        "dimension",numel(localIndices), ...
        "nnz",nnz(matrix), ...
        "symmetry_relative",relative_symmetry(matrix), ...
        "maximum_water_l_over_z",max(waterL(dayWaterRows)./waterZ(dayWaterRows)), ...
        "minimum_water_z_over_l",min(waterZ(dayWaterRows)./waterL(dayWaterRows)));
end

crossDayNnz = 0;
for left = 1:numel(days)
    for right = left+1:numel(days)
        crossDayNnz = crossDayNnz+nnz(saddle( ...
            dayBlocks(left).canonical_reduced_indices, ...
            dayBlocks(right).canonical_reduced_indices));
    end
end
permutation = [globalIndices;vertcat(dayBlocks.canonical_reduced_indices)];
reducedDimension = nx+neq;

fixture = struct();
fixture.identity = "stage-B2C-initial-day-scan-v1.0|days"+ ...
    string(days(1))+"-"+string(days(end))+"|hours1-24";
fixture.days = days;
fixture.hours = hours;
fixture.day = dayBlocks;
fixture.global_reduced_indices = globalIndices;
fixture.global_dimension = numel(globalIndices);
fixture.cross_day_nnz = crossDayNnz;
fixture.permutation_is_bijection = numel(permutation)==reducedDimension && ...
    isequal(sort(permutation),(1:reducedDimension).');
fixture.counts = struct( ...
    "primal",nx,"equalities",neq,"base_inequalities",numel(baseLinearization.l), ...
    "water_inequalities",numel(waterL), ...
    "inequalities",numel(l),"reduced_dimension",reducedDimension, ...
    "full_kkt_dimension",nx+neq+2*numel(l), ...
    "day_count",numel(days),"day_factorization_count",numel(dayBlocks));
fixture.base_config = baseConfig;
fixture.base_index = index;
fixture.base_linearization_identity = baseLinearization.identity;
fixture.water_multiplier = referenceConfig.initialization.inequality_multiplier;

assert(crossDayNnz==0 && fixture.permutation_is_bijection, ...
    "stageB2C:initialScan:Partition", ...
    "The initialization reduced matrix is not an independent-day partition.");
end

function dimensions = daily_chain_dimensions(index,days)
blocks = index.block_index(index.block_index.day>0 & ...
    index.block_index.hour_start>0,:);
dimensions = zeros(1,numel(days));
for position = 1:numel(days)
    dimensions(position) = sum(blocks.kkt_block_dimension( ...
        blocks.day==days(position)));
end
end

function [G,l,z,H,rowsByDay] = assemble_water_extension( ...
        xi,data,index,days,multiplier)
variables = index.variable_index;
nPrimal = height(variables);
nHydro = data.meta.nHydro;
nWater = 2*nHydro*numel(days);
G = spalloc(nWater,nPrimal,24*nWater);
l = zeros(nWater,1);
z = repmat(multiplier,nWater,1);
H = sparse(nPrimal,nPrimal);
rowsByDay = cell(numel(days),1);
row = 0;
for dayPosition = 1:numel(days)
    firstRow = row+1;
    day = days(dayPosition);
    for hydro = 1:nHydro
        selected = variables.day==day & variables.hour>0 & ...
            string(variables.asset_type)=="hydro" & ...
            variables.asset_id==hydro & ...
            string(variables.variable_name)=="PH";
        hydroRows = sortrows(variables(selected,:),"hour");
        columns = hydroRows.global_index_start;
        evaluated = rkkt.model.evaluate_stage_b_daily_hydro_water( ...
            xi(columns),data.base.hydro.waterA(hydro), ...
            data.base.hydro.waterB(hydro),data.base.hydro.waterC(hydro));
        for side = [1,-1]
            row = row+1;
            if side==1
                constraintValue = evaluated.value- ...
                    data.timeseries.hydroWaterMax(day,hydro);
            else
                constraintValue = data.timeseries.hydroWaterMin(day,hydro)- ...
                    evaluated.value;
            end
            gradient = side*evaluated.gradient;
            localHessian = side*evaluated.hessian;
            G(row,columns) = gradient.'; %#ok<SPRIX>
            l(row) = max(1,-constraintValue);
            H = H+z(row)*sparse(columns,columns,diag(localHessian), ...
                nPrimal,nPrimal);
        end
    end
    rowsByDay{dayPosition} = (firstRow:row).';
end
end

function value = relative_symmetry(matrix)
value = norm(matrix-matrix.',"fro")/max(1,norm(matrix,"fro"));
end

function value = day_template()
value = struct("day_id",0,"canonical_reduced_indices",zeros(0,1), ...
    "matrix",sparse(0,0),"dimension",0,"nnz",0, ...
    "symmetry_relative",NaN,"maximum_water_l_over_z",NaN, ...
    "minimum_water_z_over_l",NaN);
end
