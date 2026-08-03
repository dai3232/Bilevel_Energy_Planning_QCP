function index = build_stage_b_index(data,config,options)
%BUILD_STAGE_B_INDEX Append canonical daily-water rows to frozen Stage A.
%
% The Stage-A variable, equality, inequality, SOC, block, permutation, and
% fixed-zero prefixes are preserved exactly.  B-2A appends 56 inequalities
% in the explicit order day -> hydro -> upper/lower.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2A_INDEX"
end

validate_scope(data,config);
base = build_canonical_index_framework(data,config.days,config.hours,[], ...
    options.RunId);
validate_base_counts(base,config);

baseForLinearization = base;
baseForLinearization.scope.stage_id = "stage_A4";
baseForLinearization.scope.time_scope_type = config.time_scope_type;
baseForLinearization.scope.run_purpose = ...
    "stage_B_2A_frozen_stage_A_compatibility_view";
baseForLinearization.scope.aggregation_day_order = config.days;

[waterRows,waterIndex] = build_water_rows(base,config,options.RunId);
index = base;
index.constraint_index = [base.constraint_index;waterRows];
index.permutation_map = append_inequality_permutations( ...
    base.permutation_map,waterRows,base.counts.inequalities,options.RunId);
index.version = "stage-B2A-water-index-v1.0";
index.scope.stage_id = "stage_B";
index.scope.milestone_id = "B-2A";
index.scope.time_scope_type = config.time_scope_type;
index.scope.run_purpose = config.run_purpose;
index.scope.aggregation_day_order = config.days;
index.scope.water_bound_order = config.water_bound_order;
index.water_constraint_index = waterIndex;
index.stage_a_base_index = baseForLinearization;
index.counts.constraints = base.counts.constraints+height(waterRows);
index.counts.inequalities = base.counts.inequalities+height(waterRows);
index.counts.water_inequalities = height(waterRows);
index.counts.full_kkt_dimension = index.counts.variables+ ...
    index.counts.equalities+2*index.counts.inequalities;
index.expected = struct( ...
    "stage_a_primal",config.expected_stage_a_primal_dimension, ...
    "stage_a_equalities",config.expected_stage_a_equality_dimension, ...
    "stage_a_inequalities",config.expected_stage_a_inequality_dimension, ...
    "water_inequalities",config.expected_water_inequality_count, ...
    "full_kkt_dimension",config.expected_full_kkt_dimension);

validate_extended_index(index,base,config);
end

function [rows,auditIndex] = build_water_rows(base,config,runId)
rowCount = numel(config.days)*numel(config.hydro_ids)*2;
rows = repmat(base.constraint_index(1,:),rowCount,1);
run_id = repmat({char(runId)},rowCount,1);
constraint_id = cell(rowCount,1);
constraint_type = repmat({'inequality'},rowCount,1);
day = zeros(rowCount,1);
hour = zeros(rowCount,1);
asset_type = repmat({'hydro'},rowCount,1);
asset_id = zeros(rowCount,1);
constraint_name = cell(rowCount,1);
active_flag = true(rowCount,1);
local_row = zeros(rowCount,1);
global_row = zeros(rowCount,1);
unit = repmat({'m3/day'},rowCount,1);
window_position = zeros(rowCount,1);
predecessor_hour = nan(rowCount,1);
boundary_role = repmat({'daily_hydro_water'},rowCount,1);

stage_id = repmat("stage_B",rowCount,1);
milestone_id = repmat("B-2A",rowCount,1);
detailed_constraint_type = repmat("daily_hydro_water",rowCount,1);
hydro_id = zeros(rowCount,1);
bound_type = strings(rowCount,1);
row_position = (1:rowCount).';
inequality_position = zeros(rowCount,1);
touched_hour_count = repmat(24,rowCount,1);
touched_hour_indices = repmat(strjoin(string(1:24),"|"),rowCount,1);
touched_variable_count = repmat(24,rowCount,1);
touched_variable_indices = strings(rowCount,1);
touched_variable_names = repmat("PH",rowCount,1);
ordering_rule = repmat("day_hydro_upper_then_lower",rowCount,1);

k = 0;
for dayValue = config.days
    for hydro = config.hydro_ids
        target = base.variable_index.day==dayValue & ...
            base.variable_index.hour>0 & ...
            string(base.variable_index.asset_type)=="hydro" & ...
            base.variable_index.asset_id==hydro & ...
            string(base.variable_index.variable_name)=="PH";
        targetRows = base.variable_index(target,:);
        [~,order] = sort(targetRows.hour);
        targetRows = targetRows(order,:);
        assert(height(targetRows)==24 && ...
            isequal(targetRows.hour,(1:24).'), ...
            "stageB2A:index:HydroHourMap", ...
            "Day %d hydro %d must map to exactly 24 ordered PH variables.", ...
            dayValue,hydro);
        touched = targetRows.global_index_start;
        for side = ["upper","lower"]
            k = k+1;
            constraint_id{k} = char(compose( ...
                "INEQ-WATER-D%03d-HYDRO%02d-%s", ...
                dayValue,hydro,upper(side)));
            day(k) = dayValue;
            asset_id(k) = hydro;
            constraint_name{k} = char("daily_hydro_water_"+side);
            local_row(k) = 2*(hydro-1)+(side=="lower")+1;
            global_row(k) = base.counts.constraints+k;
            hydro_id(k) = hydro;
            bound_type(k) = side;
            inequality_position(k) = base.counts.inequalities+k;
            touched_variable_indices(k) = strjoin(string(touched.'),"|");
        end
    end
end
assert(k==rowCount,"stageB2A:index:WaterRowCount", ...
    "The explicit water-row loop did not create 56 rows.");

rows.run_id = run_id;
rows.constraint_id = constraint_id;
rows.constraint_type = constraint_type;
rows.day = day;
rows.hour = hour;
rows.asset_type = asset_type;
rows.asset_id = asset_id;
rows.constraint_name = constraint_name;
rows.active_flag = active_flag;
rows.local_row = local_row;
rows.global_row = global_row;
rows.unit = unit;
rows.window_position = window_position;
rows.predecessor_hour = predecessor_hour;
rows.boundary_role = boundary_role;

auditIndex = table(repmat(string(runId),rowCount,1),stage_id, ...
    milestone_id,detailed_constraint_type,string(constraint_id),day, ...
    hydro_id,bound_type,row_position,inequality_position,global_row, ...
    touched_hour_count,touched_hour_indices,touched_variable_count, ...
    touched_variable_indices,touched_variable_names,ordering_rule, ...
    'VariableNames',{'run_id','stage_id','milestone_id', ...
    'constraint_type','constraint_id','day','hydro_id','bound_type', ...
    'row_position','inequality_position','global_row', ...
    'touched_hour_count','touched_hour_indices', ...
    'touched_variable_count','touched_variable_indices', ...
    'touched_variable_names','ordering_rule'});
end

function result = append_inequality_permutations(base,waterRows, ...
        baseInequalityCount,runId)
template = base(string(base.space_name)=="inequality",:);
assert(~isempty(template),"stageB2A:index:PermutationTemplate", ...
    "The Stage-A inequality permutation is empty.");
added = repmat(template(1,:),height(waterRows),1);
added.run_id = repmat({char(runId)},height(waterRows),1);
added.space_name = repmat({'inequality'},height(waterRows),1);
added.canonical_index = baseInequalityCount+(1:height(waterRows)).';
added.solver_index = added.canonical_index;
added.object_type = repmat({'constraint'},height(waterRows),1);
added.object_name = waterRows.constraint_id;
result = [base;added];
end

function validate_scope(data,config)
assert(data.meta.nHydro==4 && data.meta.nHours==24 && ...
    isequal(config.days,14:20) && isequal(config.hours,1:24) && ...
    isequal(config.hydro_ids,1:4), ...
    "stageB2A:index:Scope", ...
    "B-2A index scope must be days 14:20, hours 1:24, hydros 1:4.");
assert(all(data.base.storage.initialSocFraction==0.5), ...
    "stageB2A:index:SocBoundary", ...
    "Formal daily SOC boundaries must remain fixed at 0.5E.");
end

function validate_base_counts(base,config)
actual = [base.counts.variables,base.counts.equalities, ...
    base.counts.inequalities,base.counts.full_kkt_dimension, ...
    base.counts.fixed_zero];
expected = [config.expected_stage_a_primal_dimension, ...
    config.expected_stage_a_equality_dimension, ...
    config.expected_stage_a_inequality_dimension, ...
    config.expected_stage_a_full_kkt_dimension, ...
    config.expected_stage_a_fixed_zero_count];
assert(isequal(actual,expected),"stageB2A:index:StageABaseline", ...
    "The frozen Stage-A index counts changed: actual=%s expected=%s.", ...
    mat2str(actual),mat2str(expected));
end

function validate_extended_index(index,base,config)
assert(isequaln(index.variable_index,base.variable_index) && ...
    isequaln(index.constraint_index(1:height(base.constraint_index),:), ...
        base.constraint_index) && ...
    isequaln(index.block_index,base.block_index) && ...
    isequaln(index.fixed_zero_map,base.fixed_zero_map) && ...
    isequaln(index.soc_link_map,base.soc_link_map), ...
    "stageB2A:index:StageAPrefixChanged", ...
    "Appending water rows changed a frozen Stage-A index object.");
water = index.water_constraint_index;
assert(height(water)==config.expected_water_inequality_count && ...
    isequal(water.row_position,(1:56).') && ...
    isequal(water.day,repelem((14:20).',8,1)) && ...
    isequal(water.hydro_id,repmat(repelem((1:4).',2,1),7,1)) && ...
    isequal(water.bound_type,repmat(["upper";"lower"],28,1)) && ...
    all(water.touched_hour_count==24) && ...
    numel(unique(water.constraint_id))==56 && ...
    numel(unique(water.global_row))==56 && ...
    index.counts.full_kkt_dimension==config.expected_full_kkt_dimension, ...
    "stageB2A:index:WaterInventory", ...
    "The canonical 56-row daily-water inventory is invalid.");
frameworkAudit = validate_canonical_index_framework(index);
assert(all(frameworkAudit.passed),"stageB2A:index:CanonicalAudit", ...
    "The extended canonical index failed its general audit.");
end
