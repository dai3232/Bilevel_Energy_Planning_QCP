function data = load(projectRoot)
%LOAD Load controlled project inputs through the stable data facade.
%   DATA = RKKT.DATA.LOAD(PROJECTROOT) delegates all Excel discovery,
%   parsing, normalization, and input-hash verification to the existing
%   production function LOAD_PROJECT_DATA. The returned production object
%   is checked read-only against the PKG-2 data contract and is not
%   wrapped, cropped, reordered, or extended.

arguments
    projectRoot (1,1) string
end

projectRoot = strip(projectRoot);
if strlength(projectRoot) == 0
    error("rkkt:data:EmptyProjectRoot", ...
        "projectRoot must be a nonempty string scalar.");
end

legacyDataDirectory = fullfile(projectRoot, "src", "data");
if ~isfolder(legacyDataDirectory)
    error("rkkt:data:LegacyDataDirectoryMissing", ...
        "The production data directory does not exist: %s", ...
        legacyDataDirectory);
end

originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(legacyDataDirectory, "-begin");

resolvedProductionFunction = string(which("load_project_data"));
expectedProductionFunction = fullfile( ...
    legacyDataDirectory, "load_project_data.m");
if ~same_path(resolvedProductionFunction, expectedProductionFunction)
    error("rkkt:data:ProductionFunctionShadowed", ...
        "Expected load_project_data at '%s'; MATLAB resolved '%s'.", ...
        expectedProductionFunction, resolvedProductionFunction);
end

data = load_project_data(projectRoot);
validate_data_contract(data);

clear pathGuard
end

function validate_data_contract(data)
requiredTopLevel = [ ...
    "schemaVersion"
    "projectRoot"
    "meta"
    "base"
    "timeseries"
    "hashes"
    "audit"
    "auditPolicy"
    "sources"];
rkkt.contracts.requireFields(data, requiredTopLevel, ...
    "rkkt.data.load output");
rkkt.contracts.requireTextScalar(data.schemaVersion, ...
    "rkkt.data.load output.schemaVersion");
if string(data.schemaVersion) ~= "stage0-data-v1.0"
    contract_error("schemaVersion", "stage0-data-v1.0", ...
        string(data.schemaVersion));
end
rkkt.contracts.requireTextScalar(data.projectRoot, ...
    "rkkt.data.load output.projectRoot");

validate_metadata(data.meta);
validate_base_data(data.base);
validate_timeseries(data.timeseries, data.meta);
validate_hashes(data.hashes);
validate_audit(data.audit);
validate_audit_policy(data.auditPolicy);
validate_sources(data.sources);
end

function validate_metadata(metadata)
required = [ ...
    "nThermal"
    "nHydro"
    "nWind"
    "nSolar"
    "nStorage"
    "planBaseMW"
    "nDays"
    "nHours"
    "stepMinutes"
    "dtHours"];
rkkt.contracts.requireFields(metadata, required, ...
    "rkkt.data.load output.meta");

names = required;
expected = [4; 4; 5; 5; 2; 10000; 365; 24; 60; 1];
for k = 1:numel(names)
    name = names(k);
    value = metadata.(name);
    rkkt.contracts.requireNumericArray(value, ...
        "rkkt.data.load output.meta." + name, ...
        "ExpectedSize", [1, 1], "RequireFinite", true, ...
        "RequireReal", true, "SparseMode", "full");
    if value ~= expected(k)
        contract_error("meta." + name, compose("%.17g", expected(k)), ...
            compose("%.17g", value));
    end
end
end

function validate_base_data(base)
required = [ ...
    "general"
    "deviceCounts"
    "objectiveWeights"
    "thermalCost"
    "hydroCost"
    "wind"
    "solar"
    "storage"
    "energyBase"
    "thermal"
    "hydro"
    "constraints"];
rkkt.contracts.requireFields(base, required, ...
    "rkkt.data.load output.base");

expectedSizes = [ ...
    1, 4
    1, 5
    1, 8
    4, 3
    4, 2
    5, 7
    5, 7
    2, 14
    1, 2
    4, 12
    4, 7
    1, 15];
for k = 1:numel(required)
    validate_numeric_table(base.(required(k)), ...
        "rkkt.data.load output.base." + required(k), ...
        expectedSizes(k, :));
end
end

function validate_timeseries(timeseries, metadata)
required = [ ...
    "days"
    "hours"
    "hydroWaterMin"
    "hydroWaterMax"
    "windAvailability"
    "solarAvailability"
    "planPerUnit"
    "planMW"];
rkkt.contracts.requireFields(timeseries, required, ...
    "rkkt.data.load output.timeseries");

validate_full_numeric(timeseries.days, "timeseries.days", [365, 1]);
validate_full_numeric(timeseries.hours, "timeseries.hours", [1, 24]);
validate_full_numeric(timeseries.hydroWaterMin, ...
    "timeseries.hydroWaterMin", [365, 4]);
validate_full_numeric(timeseries.hydroWaterMax, ...
    "timeseries.hydroWaterMax", [365, 4]);
validate_full_numeric(timeseries.windAvailability, ...
    "timeseries.windAvailability", [365, 24, 5]);
validate_full_numeric(timeseries.solarAvailability, ...
    "timeseries.solarAvailability", [365, 24, 5]);
validate_full_numeric(timeseries.planPerUnit, ...
    "timeseries.planPerUnit", [365, 24]);
validate_full_numeric(timeseries.planMW, ...
    "timeseries.planMW", [365, 24]);

if ~isequal(timeseries.days, (1:365).')
    contract_error("timeseries.days", "column vector (1:365)'", ...
        "different values or orientation");
end
if ~isequal(timeseries.hours, 1:24)
    contract_error("timeseries.hours", "row vector 1:24", ...
        "different values or orientation");
end
if any(timeseries.hydroWaterMin > timeseries.hydroWaterMax, "all")
    contract_error("timeseries hydro water bounds", ...
        "minimum <= maximum", "at least one minimum exceeds maximum");
end
if any(timeseries.windAvailability < 0 | ...
        timeseries.windAvailability > 1, "all")
    contract_error("timeseries.windAvailability", "[0,1]", ...
        "value outside [0,1]");
end
if any(timeseries.solarAvailability < 0 | ...
        timeseries.solarAvailability > 1, "all")
    contract_error("timeseries.solarAvailability", "[0,1]", ...
        "value outside [0,1]");
end
if any(timeseries.planPerUnit < 0 | timeseries.planPerUnit > 1, "all")
    contract_error("timeseries.planPerUnit", "[0,1]", ...
        "value outside [0,1]");
end
expectedPlanMW = timeseries.planPerUnit .* metadata.planBaseMW;
if ~isequaln(timeseries.planMW, expectedPlanMW)
    maximumDifference = max(abs( ...
        timeseries.planMW - expectedPlanMW), [], "all");
    contract_error("timeseries.planMW", ...
        "planPerUnit .* meta.planBaseMW", ...
        "maximum absolute difference=" + ...
        compose("%.17g", maximumDifference));
end
end

function validate_hashes(hashes)
if ~istable(hashes)
    error("rkkt:data:ContractViolation", ...
        "[hashes] expected a table; actual class=%s.", class(hashes));
end
required = [ ...
    "fileName"
    "expectedBytes"
    "actualBytes"
    "expectedSHA256"
    "actualSHA256"
    "bytesMatch"
    "hashMatch"
    "status"
    "filePath"];
require_table_variables(hashes, required, "hashes");
if height(hashes) ~= 2
    contract_error("hashes row count", "2", string(height(hashes)));
end
if ~isequal(sort(string(hashes.fileName)), ...
        sort(["基础参数.xlsx"; "输入数据.xlsx"]))
    contract_error("hashes.fileName", ...
        "基础参数.xlsx and 输入数据.xlsx", ...
        strjoin(string(hashes.fileName), ", "));
end
if any(string(hashes.status) ~= "PASS") || ...
        any(~logical(hashes.bytesMatch)) || ...
        any(~logical(hashes.hashMatch))
    contract_error("hashes verification", ...
        "all controlled inputs match", ...
        "at least one controlled input does not match");
end
if any(double(hashes.expectedBytes) ~= double(hashes.actualBytes))
    contract_error("hashes byte counts", ...
        "expectedBytes == actualBytes", "byte-count mismatch");
end
expectedSha = lower(string(hashes.expectedSHA256));
actualSha = lower(string(hashes.actualSHA256));
if any(expectedSha ~= actualSha)
    contract_error("hashes SHA256", ...
        "expectedSHA256 == actualSHA256", "SHA256 mismatch");
end
for k = 1:height(hashes)
    if isempty(regexp(char(actualSha(k)), ...
            "^[0-9a-f]{64}$", "once"))
        contract_error("hashes.actualSHA256", ...
            "64 lowercase hexadecimal characters", actualSha(k));
    end
end
end

function validate_audit(audit)
if ~istable(audit)
    error("rkkt:data:ContractViolation", ...
        "[audit] expected a table; actual class=%s.", class(audit));
end
required = [ ...
    "checkId"
    "item"
    "sourceFile"
    "sheet"
    "sectionLabel"
    "locator"
    "expectedShape"
    "actualShape"
    "headerRow"
    "dataStartRow"
    "dataEndRow"
    "minValue"
    "maxValue"
    "status"
    "details"
    "unit"];
require_table_variables(audit, required, "audit");
if isempty(audit) || any(string(audit.status) ~= "PASS")
    contract_error("audit.status", ...
        "nonempty table with all rows PASS", ...
        "empty table or non-PASS row");
end
end

function validate_audit_policy(policy)
required = [ ...
    "locator"
    "fixedRowsUsedForLocation"
    "documentedRowsRetainedAsAuditOnly"];
rkkt.contracts.requireFields(policy, required, ...
    "rkkt.data.load output.auditPolicy");
rkkt.contracts.requireTextScalar(policy.locator, ...
    "rkkt.data.load output.auditPolicy.locator");
if ~islogical(policy.fixedRowsUsedForLocation) || ...
        ~isscalar(policy.fixedRowsUsedForLocation) || ...
        policy.fixedRowsUsedForLocation
    contract_error("auditPolicy.fixedRowsUsedForLocation", ...
        "logical false", string(policy.fixedRowsUsedForLocation));
end
if ~islogical(policy.documentedRowsRetainedAsAuditOnly) || ...
        ~isscalar(policy.documentedRowsRetainedAsAuditOnly) || ...
        ~policy.documentedRowsRetainedAsAuditOnly
    contract_error("auditPolicy.documentedRowsRetainedAsAuditOnly", ...
        "logical true", ...
        string(policy.documentedRowsRetainedAsAuditOnly));
end
end

function validate_sources(sources)
required = [ ...
    "baseFile"
    "baseSheet"
    "baseEffectiveRange"
    "timeSeriesFile"
    "timeSeriesSheet"
    "timeSeriesEffectiveRange"];
rkkt.contracts.requireFields(sources, required, ...
    "rkkt.data.load output.sources");
for k = 1:numel(required)
    rkkt.contracts.requireTextScalar(sources.(required(k)), ...
        "rkkt.data.load output.sources." + required(k));
end
if string(sources.baseSheet) ~= "基础参数" || ...
        string(sources.baseEffectiveRange) ~= "A1:P45"
    contract_error("base source identity", ...
        "基础参数 / A1:P45", ...
        string(sources.baseSheet) + " / " + ...
        string(sources.baseEffectiveRange));
end
if string(sources.timeSeriesSheet) ~= "Sheet1" || ...
        string(sources.timeSeriesEffectiveRange) ~= "A1:AA5492"
    contract_error("time-series source identity", ...
        "Sheet1 / A1:AA5492", ...
        string(sources.timeSeriesSheet) + " / " + ...
        string(sources.timeSeriesEffectiveRange));
end
end

function validate_numeric_table(value, context, expectedSize)
if ~istable(value)
    error("rkkt:data:ContractViolation", ...
        "[%s] expected a table; actual class=%s.", context, class(value));
end
if ~isequal(size(value), expectedSize)
    contract_error(context + " size", ...
        strjoin(string(expectedSize), "x"), ...
        strjoin(string(size(value)), "x"));
end
array = table2array(value);
rkkt.contracts.requireNumericArray(array, context + " numeric payload", ...
    "ExpectedSize", expectedSize, "RequireFinite", true, ...
    "RequireReal", true, "SparseMode", "full");
end

function validate_full_numeric(value, context, expectedSize)
rkkt.contracts.requireNumericArray(value, ...
    "rkkt.data.load output." + context, ...
    "ExpectedSize", expectedSize, "RequireFinite", true, ...
    "RequireReal", true, "SparseMode", "full");
end

function require_table_variables(value, required, context)
actual = string(value.Properties.VariableNames);
missing = required(~ismember(required, actual));
if ~isempty(missing)
    error("rkkt:data:ContractViolation", ...
        "[%s] missing required table variable(s): %s.", ...
        context, strjoin(missing, ", "));
end
end

function contract_error(context, expected, actual)
error("rkkt:data:ContractViolation", ...
    "[%s] expected=%s; actual=%s.", ...
    context, string(expected), string(actual));
end

function equal = same_path(left, right)
left = replace(string(left), "/", "\");
right = replace(string(right), "/", "\");
if ispc
    equal = strcmpi(left, right);
else
    equal = strcmp(left, right);
end
end
