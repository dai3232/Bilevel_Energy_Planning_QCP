function data = load_project_data(projectRoot)
%LOAD_PROJECT_DATA Load and validate the controlled stage-0 Excel inputs.
%   DATA = LOAD_PROJECT_DATA(PROJECTROOT) verifies both raw input hashes,
%   locates every Excel block by sheet name, unique section label, and its
%   complete header, and returns a normalized structure.  Documented Excel
%   row numbers are used only as audit outcomes; no block is located by a
%   fixed row number.

if nargin < 1 || strlength(string(projectRoot)) == 0
    projectRoot = default_project_root();
else
    projectRoot = string(projectRoot);
end
projectRoot = reshape(projectRoot, 1, 1);

[hashes, hashesMatch] = verify_input_hashes(projectRoot);
if ~hashesMatch
    failedFiles = hashes.fileName(hashes.status ~= "PASS");
    error("stage0:InputHashMismatch", ...
        "Controlled input hash verification failed for: %s", strjoin(failedFiles, ", "));
end

baseFile = fullfile(projectRoot, "inputs", "raw", "基础参数.xlsx");
timeSeriesFile = fullfile(projectRoot, "inputs", "raw", "输入数据.xlsx");
baseSheet = "基础参数";
timeSeriesSheet = "Sheet1";
assert_single_sheet(baseFile, baseSheet);
assert_single_sheet(timeSeriesFile, timeSeriesSheet);

baseRaw = readcell(baseFile, "Sheet", baseSheet);
timeSeriesRaw = readcell(timeSeriesFile, "Sheet", timeSeriesSheet);
[baseRows, baseColumns] = effective_used_size(baseRaw);
[timeRows, timeColumns] = effective_used_size(timeSeriesRaw);
if baseRows ~= 45 || baseColumns ~= 16
    error("stage0:BaseAuditRangeMismatch", ...
        "Base input effective range must be A1:P45; found %s.", excel_range(baseRows, baseColumns));
end
if timeRows ~= 5492 || timeColumns ~= 27
    error("stage0:TimeSeriesAuditRangeMismatch", ...
        "Time-series input effective range must be A1:AA5492; found %s.", ...
        excel_range(timeRows, timeColumns));
end

[base, metadataSeed, baseAudit] = parse_base_data(baseRaw, baseSheet);
[timeseries, timeMetadata, timeAudit] = parse_time_series_data( ...
    timeSeriesRaw, timeSeriesSheet, metadataSeed);

metadata = metadataSeed;
metadata.nDays = timeMetadata.nDays;
metadata.nHours = timeMetadata.nHours;
metadata.stepMinutes = timeMetadata.stepMinutes;
metadata.dtHours = timeMetadata.stepMinutes / 60;
if metadata.nDays ~= 365 || metadata.nHours ~= 24 || ...
        metadata.stepMinutes ~= 60 || metadata.dtHours ~= 1
    error("stage0:TimeContractMismatch", ...
        "Time contract must be 365 days, 24 periods/day, and 60 minutes/period.");
end

audit = new_audit_table();
for rowIndex = 1:height(hashes)
    details = sprintf("expectedBytes=%.0f; actualBytes=%.0f; expectedSHA256=%s; actualSHA256=%s", ...
        hashes.expectedBytes(rowIndex), hashes.actualBytes(rowIndex), ...
        hashes.expectedSHA256(rowIndex), hashes.actualSHA256(rowIndex));
    audit = append_audit(audit, "S0-DATA-001", "input hash", ...
        hashes.fileName(rowIndex), "manifest", hashes.fileName(rowIndex), ...
        "manifest file name+byte count+SHA256", "1x1", "1x1", ...
        NaN, NaN, NaN, NaN, NaN, hashes.status(rowIndex), details, "");
end
audit = append_audit(audit, "S0-DATA-002", "base effective range", ...
    "基础参数.xlsx", baseSheet, "used range", "sheet+effective nonempty range", ...
    "45x16", sprintf("%dx%d", baseRows, baseColumns), NaN, 1, baseRows, ...
    NaN, NaN, "PASS", excel_range(baseRows, baseColumns), "");
audit = append_audit(audit, "S0-DATA-002", "time-series effective range", ...
    "输入数据.xlsx", timeSeriesSheet, "used range", "sheet+effective nonempty range", ...
    "5492x27", sprintf("%dx%d", timeRows, timeColumns), NaN, 1, timeRows, ...
    NaN, NaN, "PASS", excel_range(timeRows, timeColumns), "");
audit = [audit; baseAudit; timeAudit];

data = struct();
data.schemaVersion = "stage0-data-v1.0";
data.projectRoot = projectRoot;
data.meta = metadata;
data.base = base;
data.timeseries = timeseries;
data.hashes = hashes;
data.audit = audit;
data.auditPolicy = struct( ...
    "locator", "sheet name + unique section label + complete contiguous header", ...
    "fixedRowsUsedForLocation", false, ...
    "documentedRowsRetainedAsAuditOnly", true);
data.sources = struct( ...
    "baseFile", string(baseFile), ...
    "baseSheet", baseSheet, ...
    "baseEffectiveRange", excel_range(baseRows, baseColumns), ...
    "timeSeriesFile", string(timeSeriesFile), ...
    "timeSeriesSheet", timeSeriesSheet, ...
    "timeSeriesEffectiveRange", excel_range(timeRows, timeColumns));
end

function [base, metadata, audit] = parse_base_data(rawCells, sheetName)
sourceFile = "基础参数.xlsx";
audit = new_audit_table();

generalHeaders = ["天数(day)", "贴现率", "系统运行周期(year)", "分块天数(day)"];
generalLocation = locate_labeled_table(rawCells, sheetName, "基本参数", ...
    generalHeaders, "within-section");
generalValues = read_numeric_rows(rawCells, generalLocation, 1, "basic parameters");
base.general = array2table(generalValues, 'VariableNames', ...
    cellstr(["legacyDays", "discountRate", "systemLifeYears", "blockDays"]));
audit = append_block_audit(audit, "S0-DATA-002", "basic parameters", sourceFile, ...
    generalLocation, "1x4", generalValues, "Legacy days are retained but do not set annual length.");

countHeaders = ["火电数量", "水电数量", "风电数量", "光伏数量", "储能数量"];
countLocation = locate_labeled_table(rawCells, sheetName, "基本参数", ...
    countHeaders, "within-section");
countValues = read_numeric_rows(rawCells, countLocation, 1, "device counts");
expectedCounts = [4, 4, 5, 5, 2];
if ~isequal(countValues, expectedCounts)
    error("stage0:DeviceCountMismatch", ...
        "Device counts must be thermal/hydro/wind/solar/storage = 4/4/5/5/2; found %s.", ...
        mat2str(countValues));
end
base.deviceCounts = array2table(countValues, 'VariableNames', ...
    cellstr(["nThermal", "nHydro", "nWind", "nSolar", "nStorage"]));
audit = append_block_audit(audit, "S0-DATA-003", "device counts", sourceFile, ...
    countLocation, "1x5", countValues, "Expected 4/4/5/5/2.");

weightHeaders = ["综合投资成本最低权重", "综合度电成本最低权重", ...
    "新能源弃电率最低权重", "新能源电量占比最高权重", ...
    "火电碳排放量最低权重", "水电弃水量最低权重", ...
    "火电发电成本最低权重", "综合售电收益最高权重"];
weightLocation = locate_labeled_table(rawCells, sheetName, "基本参数", ...
    weightHeaders, "within-section");
weightValues = read_numeric_rows(rawCells, weightLocation, 1, "objective weights");
if abs(sum(weightValues) - 0.997) > 1e-12
    error("stage0:ObjectiveWeightAuditMismatch", ...
        "The eight unnormalized objective weights must sum to 0.997; found %.17g.", sum(weightValues));
end
base.objectiveWeights = array2table(weightValues, 'VariableNames', ...
    cellstr(["investment", "levelizedCost", "curtailment", "renewableShare", ...
    "thermalCarbon", "waterSpillage", "thermalCost", "salesRevenue"]));
audit = append_block_audit(audit, "S0-DATA-002", "objective weights", sourceFile, ...
    weightLocation, "1x8", weightValues, sprintf("Unnormalized sum=%.17g.", sum(weightValues)));

thermalCostHeaders = ["火电序号", "度电成本(元/MWh)", "启动成本(元)"];
thermalCostLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    thermalCostHeaders, "within-section");
thermalCostValues = read_indexed_rows(rawCells, thermalCostLocation, countValues(1), "thermal cost");
base.thermalCost = array2table(thermalCostValues, 'VariableNames', ...
    cellstr(["unitId", "levelizedCostYuanPerMWh", "startupCostYuan"]));
audit = append_block_audit(audit, "S0-DATA-002", "thermal cost table", sourceFile, ...
    thermalCostLocation, "4x3", thermalCostValues, "");

hydroCostHeaders = ["水电序号", "度电成本(元/MWh)"];
hydroCostLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    hydroCostHeaders, "within-section");
hydroCostValues = read_indexed_rows(rawCells, hydroCostLocation, countValues(2), "hydro cost");
base.hydroCost = array2table(hydroCostValues, 'VariableNames', ...
    cellstr(["unitId", "levelizedCostYuanPerMWh"]));
audit = append_block_audit(audit, "S0-DATA-002", "hydro cost table", sourceFile, ...
    hydroCostLocation, "4x2", hydroCostValues, "");

planningHeaders = ["序号占位", "单位功率投资成本(元/MW)", "规划功率上限(MW)", ...
    "规划功率下限(MW)", "度电成本系数a", "度电成本系数b", "度电成本系数c"];
windHeaders = planningHeaders;
windHeaders(1) = "风电序号";
windLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    windHeaders, "within-section");
windValues = read_indexed_rows(rawCells, windLocation, countValues(3), "wind planning");
assert_lower_not_above_upper(windValues(:, 4), windValues(:, 3), "wind planning power");
base.wind = array2table(windValues, 'VariableNames', ...
    cellstr(["unitId", "investmentYuanPerMW", "capacityUpperMW", "capacityLowerMW", ...
    "levelizedCostA", "levelizedCostB", "levelizedCostC"]));
audit = append_block_audit(audit, "S0-DATA-002", "wind planning table", sourceFile, ...
    windLocation, "5x7", windValues, "");

solarHeaders = planningHeaders;
solarHeaders(1) = "光伏序号";
solarLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    solarHeaders, "within-section");
solarValues = read_indexed_rows(rawCells, solarLocation, countValues(4), "solar planning");
assert_lower_not_above_upper(solarValues(:, 4), solarValues(:, 3), "solar planning power");
base.solar = array2table(solarValues, 'VariableNames', ...
    cellstr(["unitId", "investmentYuanPerMW", "capacityUpperMW", "capacityLowerMW", ...
    "levelizedCostA", "levelizedCostB", "levelizedCostC"]));
audit = append_block_audit(audit, "S0-DATA-002", "solar planning table", sourceFile, ...
    solarLocation, "5x7", solarValues, "");

storageHeaders = ["储能序号", "单位功率投资成本(元/MW)", ...
    "单位容量投资成本(元/MWh)", "规划功率上限(MW)", "规划功率下限(MW)", ...
    "规划容量上限(MWh)", "规划容量下限(MWh)", "度电成本(元/MWh)", ...
    "储能容量初值系数", "储能容量上限系数", "储能容量下限系数", ...
    "充电效率", "放电效率", "储能时长(hour)"];
storageLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    storageHeaders, "within-section");
storageValues = read_indexed_rows(rawCells, storageLocation, countValues(5), "storage planning");
assert_lower_not_above_upper(storageValues(:, 5), storageValues(:, 4), "storage planning power");
assert_lower_not_above_upper(storageValues(:, 7), storageValues(:, 6), "storage planning energy");
if any(storageValues(:, 11) < 0 | storageValues(:, 9) <= storageValues(:, 11) | ...
        storageValues(:, 10) <= storageValues(:, 9) | storageValues(:, 10) > 1)
    error("stage0:StorageSocFractionRange", "Storage SOC fractions must satisfy 0 <= min < initial < max <= 1.");
end
if any(storageValues(:, 12:13) <= 0 | storageValues(:, 12:13) > 1, "all")
    error("stage0:StorageEfficiencyRange", "Storage efficiencies must be in (0, 1].");
end
if any(storageValues(:, 14) <= 0)
    error("stage0:StorageDurationRange", "Storage duration must be positive.");
end
base.storage = array2table(storageValues, 'VariableNames', ...
    cellstr(["unitId", "investmentPowerYuanPerMW", "investmentEnergyYuanPerMWh", ...
    "powerUpperMW", "powerLowerMW", "energyUpperMWh", "energyLowerMWh", ...
    "levelizedCostYuanPerMWh", "initialSocFraction", "socUpperFraction", ...
    "socLowerFraction", "chargeEfficiency", "dischargeEfficiency", "durationHours"]));
audit = append_block_audit(audit, "S0-DATA-002", "storage planning table", sourceFile, ...
    storageLocation, "2x14", storageValues, "");

energyBaseHeaders = ["能源基地", "销售电价(元/MWh)"];
energyBaseLocation = locate_labeled_table(rawCells, sheetName, "投资及度电成本参数", ...
    energyBaseHeaders, "within-section");
energyBaseValues = read_indexed_rows(rawCells, energyBaseLocation, 1, "energy-base price");
base.energyBase = array2table(energyBaseValues, 'VariableNames', ...
    cellstr(["baseId", "salePriceYuanPerMWh"]));
audit = append_block_audit(audit, "S0-DATA-002", "energy-base price", sourceFile, ...
    energyBaseLocation, "1x2", energyBaseValues, "");

thermalHeaders = ["火电序号", "装机容量(MW)", "最大出力(MW)", "最小出力(MW)", ...
    "最小运行时间(h)", "最小停机时间(h)", "冷启动时间(h)", ...
    "燃料系数a", "燃料系数b", "燃料系数c", ...
    "碳排放系数(kgCO2/吨煤)", "燃料成本(元/吨煤)"];
thermalLocation = locate_labeled_table(rawCells, sheetName, "已知机组参数", ...
    thermalHeaders, "within-section");
thermalValues = read_indexed_rows(rawCells, thermalLocation, countValues(1), "thermal generator");
assert_lower_not_above_upper(thermalValues(:, 4), thermalValues(:, 3), "thermal output");
if any(thermalValues(:, 3) > thermalValues(:, 2))
    error("stage0:ThermalCapacityRange", "Thermal maximum output cannot exceed installed capacity.");
end
base.thermal = array2table(thermalValues, 'VariableNames', ...
    cellstr(["unitId", "installedCapacityMW", "maxOutputMW", "minOutputMW", ...
    "minUpHours", "minDownHours", "coldStartHours", "fuelA", "fuelB", "fuelC", ...
    "emissionKgCO2PerTonneCoal", "fuelCostYuanPerTonneCoal"]));
audit = append_block_audit(audit, "S0-DATA-002", "thermal generator table", sourceFile, ...
    thermalLocation, "4x12", thermalValues, "FUTURE-UC columns are retained but not enabled.");

hydroHeaders = ["水电序号", "装机容量(MW)", "最大出力(MW)", "最小出力(MW)", ...
    "用水量系数a", "用水量系数b", "用水量系数c"];
hydroLocation = locate_labeled_table(rawCells, sheetName, "已知机组参数", ...
    hydroHeaders, "within-section");
hydroValues = read_indexed_rows(rawCells, hydroLocation, countValues(2), "hydro generator");
assert_lower_not_above_upper(hydroValues(:, 4), hydroValues(:, 3), "hydro output");
if any(hydroValues(:, 3) > hydroValues(:, 2))
    error("stage0:HydroCapacityRange", "Hydro maximum output cannot exceed installed capacity.");
end
base.hydro = array2table(hydroValues, 'VariableNames', ...
    cellstr(["unitId", "installedCapacityMW", "maxOutputMW", "minOutputMW", ...
    "waterA", "waterB", "waterC"]));
audit = append_block_audit(audit, "S0-DATA-002", "hydro generator table", sourceFile, ...
    hydroLocation, "4x7", hydroValues, "");

constraintHeaders = ["新能源总弃电率上限", "新能源总弃电率下限", ...
    "新能源日弃电率上限", "新能源日弃电率下限", ...
    "新能源总电量占比上限", "新能源总电量占比下限", ...
    "新能源日电量占比上限", "新能源日电量占比下限", ...
    "总电量保供率上限", "总电量保供率下限", ...
    "日电量保供率上限", "日电量保供率下限", ...
    "单时段电量保供率上限", "单时段电量保供率下限", ...
    "单时段最大计划总出力(MW)"];
constraintLocation = locate_labeled_table(rawCells, sheetName, "约束参数", ...
    constraintHeaders, "within-section");
constraintValues = read_numeric_rows(rawCells, constraintLocation, 1, "constraint parameters");
base.constraints = array2table(constraintValues, 'VariableNames', ...
    cellstr(["annualCurtailmentUpper", "annualCurtailmentLower", ...
    "dailyCurtailmentUpper", "dailyCurtailmentLower", ...
    "annualRenewableShareUpper", "annualRenewableShareLower", ...
    "dailyRenewableShareUpper", "dailyRenewableShareLower", ...
    "annualSupplyUpper", "annualSupplyLower", "dailySupplyUpper", "dailySupplyLower", ...
    "hourlySupplyUpper", "hourlySupplyLower", "planBaseMW"]));
if constraintValues(15) ~= 10000
    error("stage0:PlanBaseMismatch", "Plan conversion base must be 10000 MW; found %.17g.", constraintValues(15));
end
audit = append_block_audit(audit, "S0-DATA-005", "constraint parameters", sourceFile, ...
    constraintLocation, "1x15", constraintValues, "Plan base is 10000 MW.");

metadata = struct();
metadata.nThermal = countValues(1);
metadata.nHydro = countValues(2);
metadata.nWind = countValues(3);
metadata.nSolar = countValues(4);
metadata.nStorage = countValues(5);
metadata.planBaseMW = constraintValues(15);
end

function [timeseries, metadata, audit] = parse_time_series_data(rawCells, sheetName, baseMetadata)
sourceFile = "输入数据.xlsx";
audit = new_audit_table();

timeHeaders = ["计算天数(day)", "计算时段(hour)", "时段长度(min)"];
timeLocation = locate_labeled_table(rawCells, sheetName, "基本参数", timeHeaders, "same-row");
timeValues = read_numeric_rows(rawCells, timeLocation, 1, "time metadata");
if ~isequal(timeValues, [365, 24, 60])
    error("stage0:TimeContractMismatch", ...
        "Time-series metadata must be 365 days, 24 periods, 60 minutes; found %s.", mat2str(timeValues));
end
metadata = struct("nDays", timeValues(1), "nHours", timeValues(2), ...
    "stepMinutes", timeValues(3));
audit = append_block_audit(audit, "S0-DATA-004", "time metadata", sourceFile, ...
    timeLocation, "1x3", timeValues, "365 days, 24 periods/day, 60 minutes/period.");

nDays = metadata.nDays;
nHours = metadata.nHours;
nHydro = baseMetadata.nHydro;
nWind = baseMetadata.nWind;
nSolar = baseMetadata.nSolar;
hydroWaterMin = zeros(nDays, nHydro);
hydroWaterMax = zeros(nDays, nHydro);
windAvailability = zeros(nDays, nHours, nWind);
solarAvailability = zeros(nDays, nHours, nSolar);
referenceDays = (1:nDays).';

hydroHeaders = ["天数", "总用水上限(立方米)", "总用水下限(立方米)"];
for unitIndex = 1:nHydro
    sectionLabel = compose("%d号水电", unitIndex);
    location = locate_labeled_table(rawCells, sheetName, sectionLabel, hydroHeaders, "same-row");
    values = read_numeric_rows(rawCells, location, nDays, compose("hydro %d daily water", unitIndex));
    validate_day_column(values(:, 1), referenceDays, sectionLabel);
    waterMax = values(:, 2);
    waterMin = values(:, 3);
    if any(waterMin < 0 | waterMax < 0 | waterMin > waterMax)
        error("stage0:HydroWaterRange", ...
            "Hydro block '%s' must satisfy 0 <= daily minimum <= daily maximum.", sectionLabel);
    end
    hydroWaterMin(:, unitIndex) = waterMin;
    hydroWaterMax(:, unitIndex) = waterMax;
    audit = append_block_audit(audit, "S0-DATA-004", sectionLabel + " daily water", ...
        sourceFile, location, "365x3", values, "Day column is exactly 1:365.");
end

availabilityHeaders = ["天数", reshape(compose("时段%d典型出力(0-1)", 1:nHours), 1, [])];
for unitIndex = 1:nWind
    sectionLabel = compose("%d号风电", unitIndex);
    location = locate_labeled_table(rawCells, sheetName, sectionLabel, availabilityHeaders, "same-row");
    values = read_numeric_rows(rawCells, location, nDays, compose("wind %d availability", unitIndex));
    validate_day_column(values(:, 1), referenceDays, sectionLabel);
    availability = values(:, 2:end);
    validate_unit_interval(availability, sectionLabel);
    windAvailability(:, :, unitIndex) = availability;
    audit = append_block_audit(audit, "S0-DATA-004", sectionLabel + " availability", ...
        sourceFile, location, "365x25", values, "Availability is finite and in [0,1].");
end

for unitIndex = 1:nSolar
    sectionLabel = compose("%d号光伏", unitIndex);
    location = locate_labeled_table(rawCells, sheetName, sectionLabel, availabilityHeaders, "same-row");
    values = read_numeric_rows(rawCells, location, nDays, compose("solar %d availability", unitIndex));
    validate_day_column(values(:, 1), referenceDays, sectionLabel);
    availability = values(:, 2:end);
    validate_unit_interval(availability, sectionLabel);
    solarAvailability(:, :, unitIndex) = availability;
    audit = append_block_audit(audit, "S0-DATA-004", sectionLabel + " availability", ...
        sourceFile, location, "365x25", values, "Availability is finite and in [0,1].");
end

planHeaders = ["天数", reshape(compose("时段%d计划总出力", 1:nHours), 1, [])];
planLocation = locate_labeled_table(rawCells, sheetName, "能源基地", planHeaders, "same-row");
planValues = read_numeric_rows(rawCells, planLocation, nDays, "energy-base plan");
validate_day_column(planValues(:, 1), referenceDays, "能源基地");
planPerUnit = planValues(:, 2:end);
validate_unit_interval(planPerUnit, "能源基地计划曲线");
planMW = planPerUnit * baseMetadata.planBaseMW;
if abs(min(planMW(:)) - 2070) > 1e-9 || abs(max(planMW(:)) - 9860) > 1e-9
    error("stage0:PlanRangeMismatch", ...
        "Converted plan audit range must be [2070, 9860] MW; found [%.17g, %.17g] MW.", ...
        min(planMW(:)), max(planMW(:)));
end
audit = append_block_audit(audit, "S0-DATA-005", "energy-base plan per unit", ...
    sourceFile, planLocation, "365x25", planValues, ...
    sprintf("Converted with %.17g MW base; planMW range=[%.17g, %.17g].", ...
    baseMetadata.planBaseMW, min(planMW(:)), max(planMW(:))));

timeseries = struct();
timeseries.days = referenceDays;
timeseries.hours = 1:nHours;
timeseries.hydroWaterMin = hydroWaterMin;
timeseries.hydroWaterMax = hydroWaterMax;
timeseries.windAvailability = windAvailability;
timeseries.solarAvailability = solarAvailability;
timeseries.planPerUnit = planPerUnit;
timeseries.planMW = planMW;
end

function values = read_indexed_rows(rawCells, location, rowCount, context)
values = read_numeric_rows(rawCells, location, rowCount, context);
expectedIds = (1:rowCount).';
if ~isequal(values(:, 1), expectedIds)
    error("stage0:UnitIdSequence", ...
        "Table '%s' unit IDs must be exactly 1:%d; found %s.", ...
        context, rowCount, mat2str(values(:, 1).'));
end
end

function values = read_numeric_rows(rawCells, location, rowCount, context)
startRow = location.headerRow + 1;
endRow = startRow + rowCount - 1;
startColumn = location.headerStartColumn;
endColumn = location.headerEndColumn;
if endRow > size(rawCells, 1) || endColumn > size(rawCells, 2)
    error("stage0:ExcelBlockTruncated", "Excel block '%s' is truncated.", context);
end

values = zeros(rowCount, endColumn - startColumn + 1);
for rowOffset = 1:rowCount
    for columnOffset = 1:size(values, 2)
        value = rawCells{startRow + rowOffset - 1, startColumn + columnOffset - 1};
        if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
            error("stage0:NonFiniteOrMissingValue", ...
                "Excel block '%s' contains a missing, nonnumeric, or nonfinite value at discovered cell %s%d.", ...
                context, excel_column_name(startColumn + columnOffset - 1), startRow + rowOffset - 1);
        end
        values(rowOffset, columnOffset) = double(value);
    end
end
end

function validate_day_column(days, referenceDays, sectionLabel)
if numel(unique(days)) ~= numel(days) || ~isequal(days, referenceDays)
    error("stage0:NonContiguousDays", ...
        "Time-series block '%s' must contain unique consecutive days 1:365.", sectionLabel);
end
end

function validate_unit_interval(values, sectionLabel)
if any(~isfinite(values), "all") || any(values < 0 | values > 1, "all")
    error("stage0:UnitIntervalRange", ...
        "Time-series block '%s' must contain only finite values in [0,1].", sectionLabel);
end
end

function assert_lower_not_above_upper(lowerValues, upperValues, context)
if any(lowerValues < 0 | upperValues < 0 | lowerValues > upperValues)
    error("stage0:InvalidBounds", "%s must satisfy 0 <= lower <= upper.", context);
end
end

function assert_single_sheet(filePath, requiredSheet)
availableSheets = string(sheetnames(filePath));
if nnz(availableSheets == requiredSheet) ~= 1
    error("stage0:RequiredSheetMissing", ...
        "Workbook '%s' must contain exactly one sheet named '%s'.", filePath, requiredSheet);
end
end

function [lastRow, lastColumn] = effective_used_size(rawCells)
lastRow = 0;
lastColumn = 0;
for rowIndex = 1:size(rawCells, 1)
    for columnIndex = 1:size(rawCells, 2)
        if cell_has_value(rawCells{rowIndex, columnIndex})
            lastRow = max(lastRow, rowIndex);
            lastColumn = max(lastColumn, columnIndex);
        end
    end
end
end

function hasValue = cell_has_value(value)
if isempty(value)
    hasValue = false;
elseif isstring(value)
    hasValue = isscalar(value) && ~ismissing(value) && strlength(strip(value)) > 0;
elseif ischar(value)
    hasValue = ~isempty(strtrim(value));
elseif isnumeric(value)
    hasValue = ~(isscalar(value) && isnan(value));
else
    hasValue = true;
end
end

function audit = new_audit_table()
audit = table('Size', [0, 16], ...
    'VariableTypes', cellstr([repmat("string", 1, 8), repmat("double", 1, 5), repmat("string", 1, 3)]), ...
    'VariableNames', cellstr(["checkId", "item", "sourceFile", "sheet", "sectionLabel", ...
    "locator", "expectedShape", "actualShape", "headerRow", "dataStartRow", ...
    "dataEndRow", "minValue", "maxValue", "status", "details", "unit"]));
end

function audit = append_block_audit(audit, checkId, item, sourceFile, location, ...
        expectedShape, values, details)
audit = append_audit(audit, checkId, item, sourceFile, location.sheet, ...
    location.sectionLabel, location.locator, expectedShape, matrix_shape(values), ...
    location.headerRow, location.headerRow + 1, location.headerRow + size(values, 1), ...
    min(values(:)), max(values(:)), "PASS", details, "");
end

function audit = append_audit(audit, checkId, item, sourceFile, sheet, sectionLabel, ...
        locator, expectedShape, actualShape, headerRow, dataStartRow, dataEndRow, ...
        minValue, maxValue, status, details, unit)
audit(end + 1, :) = {string(checkId), string(item), string(sourceFile), string(sheet), ...
    string(sectionLabel), string(locator), string(expectedShape), string(actualShape), ...
    double(headerRow), double(dataStartRow), double(dataEndRow), double(minValue), ...
    double(maxValue), string(status), string(details), string(unit)};
end

function shape = matrix_shape(values)
shape = compose("%dx%d", size(values, 1), size(values, 2));
end

function range = excel_range(rowCount, columnCount)
if rowCount < 1 || columnCount < 1
    range = "EMPTY";
else
    range = "A1:" + excel_column_name(columnCount) + string(rowCount);
end
end

function name = excel_column_name(columnIndex)
if columnIndex < 1 || fix(columnIndex) ~= columnIndex
    error("stage0:InvalidExcelColumn", "Excel column index must be a positive integer.");
end
characters = '';
remaining = columnIndex;
while remaining > 0
    remainder = mod(remaining - 1, 26);
    characters = [char(65 + remainder), characters]; %#ok<AGROW>
    remaining = floor((remaining - 1) / 26);
end
name = string(characters);
end

function projectRoot = default_project_root()
dataDirectory = fileparts(mfilename("fullpath"));
sourceDirectory = fileparts(dataDirectory);
projectRoot = string(fileparts(sourceDirectory));
end
