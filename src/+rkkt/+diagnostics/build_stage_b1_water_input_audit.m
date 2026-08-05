function audit = build_stage_b1_water_input_audit(data,runId)
%BUILD_STAGE_B1_WATER_INPUT_AUDIT Build the authoritative 28-row B-1 audit.
%   Rows are ordered day-major then hydro-minor: day 14 plants 1:4, then
%   day 15 plants 1:4, through day 20 plants 1:4.

validate_run_id(runId);
validate_data_contract(data);

days = (14:20).';
hydroIds = (1:4).';
rowCount = numel(days)*numel(hydroIds);

run_id = repmat(string(runId),rowCount,1);
stage_id = repmat("stage_B",rowCount,1);
day = repelem(days,numel(hydroIds));
hydro_id = repmat(hydroIds,numel(days),1);
water_a = zeros(rowCount,1);
water_b = zeros(rowCount,1);
water_c = zeros(rowCount,1);
water_min_m3 = zeros(rowCount,1);
water_max_m3 = zeros(rowCount,1);
min_not_above_max = false(rowCount,1);
all_finite = false(rowCount,1);
source_field = repmat( ...
    "data.base.hydro.waterA|waterB|waterC|maxOutputMW;" + ...
    "data.timeseries.hydroWaterMin|hydroWaterMax;unit=m3/day", ...
    rowCount,1);
status = repmat("FAIL",rowCount,1);
max_output_mw = zeros(rowCount,1);
nonnegative_bounds = false(rowCount,1);
max_output_positive = false(rowCount,1);
water_unit = repmat("m3/day",rowCount,1);
power_unit = repmat("MW",rowCount,1);

row = 0;
for dayValue = reshape(days,1,[])
    for hydroId = reshape(hydroIds,1,[])
        row = row + 1;
        water_a(row) = data.base.hydro.waterA(hydroId);
        water_b(row) = data.base.hydro.waterB(hydroId);
        water_c(row) = data.base.hydro.waterC(hydroId);
        max_output_mw(row) = data.base.hydro.maxOutputMW(hydroId);
        water_min_m3(row) = data.timeseries.hydroWaterMin( ...
            dayValue,hydroId);
        water_max_m3(row) = data.timeseries.hydroWaterMax( ...
            dayValue,hydroId);
        values = [water_a(row),water_b(row),water_c(row), ...
            max_output_mw(row),water_min_m3(row),water_max_m3(row)];
        all_finite(row) = all(isfinite(values));
        min_not_above_max(row) = ...
            water_min_m3(row) <= water_max_m3(row);
        nonnegative_bounds(row) = water_min_m3(row) >= 0 && ...
            water_max_m3(row) >= 0;
        max_output_positive(row) = max_output_mw(row) > 0;
        if all_finite(row) && min_not_above_max(row) && ...
                nonnegative_bounds(row) && max_output_positive(row)
            status(row) = "PASS";
        end
    end
end

audit = table(run_id,stage_id,day,hydro_id,water_a,water_b,water_c, ...
    water_min_m3,water_max_m3,min_not_above_max,all_finite, ...
    source_field,status,max_output_mw,nonnegative_bounds, ...
    max_output_positive,water_unit,power_unit);

assert(height(audit)==28 && all(audit.day==day) && ...
    all(audit.hydro_id==hydro_id), ...
    "stageB1:waterAudit:OrderingFailure", ...
    "Water input audit must contain exactly 28 day-major/hydro-minor rows.");
end

function validate_run_id(value)
if ~(ischar(value) || (isstring(value) && isscalar(value))) || ...
        strlength(strtrim(string(value)))==0
    error("stageB1:waterAudit:InvalidRunId", ...
        "runId must be a nonempty text scalar.");
end
end

function validate_data_contract(data)
if ~isstruct(data) || ~isfield(data,"base") || ...
        ~isfield(data,"timeseries") || ~isfield(data.base,"hydro")
    error("stageB1:waterAudit:InvalidData", ...
        "data must be the normalized load_project_data structure.");
end
hydro = data.base.hydro;
required = ["unitId","maxOutputMW","waterA","waterB","waterC"];
if ~istable(hydro) || height(hydro)~=4 || ...
        ~all(ismember(required,string(hydro.Properties.VariableNames))) || ...
        ~isequal(double(hydro.unitId),(1:4).')
    error("stageB1:waterAudit:InvalidHydroBase", ...
        "data.base.hydro must contain ordered units 1:4 and required fields.");
end
requiredSeries = ["days","hydroWaterMin","hydroWaterMax"];
if ~all(isfield(data.timeseries,requiredSeries)) || ...
        ~isequal(size(data.timeseries.hydroWaterMin),[365,4]) || ...
        ~isequal(size(data.timeseries.hydroWaterMax),[365,4]) || ...
        ~isequal(double(data.timeseries.days(:)),(1:365).')
    error("stageB1:waterAudit:InvalidHydroTimeseries", ...
        "Hydro water series must be 365-by-4 with days exactly 1:365.");
end
end
