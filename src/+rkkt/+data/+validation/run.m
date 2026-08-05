function moduleResult = run(projectRoot, options)
%RUN Run the standalone manual validation for the PKG-2 data module.
%   MODULERESULT = RKKT.DATA.VALIDATION.RUN(PROJECTROOT) loads the complete
%   365-day production object through both the implementation and
%   RKKT.DATA.LOAD, compares them without modification, and builds a
%   day-14-through-day-20 observation view. It does not call indexing,
%   model, solver, KKT, or IPM code.
%
%   Manual artifacts are fixed, overwriteable observations rather than
%   formal stage evidence. PKG-2 keeps them in this already-existing
%   package directory and never creates an output directory.

arguments
    projectRoot (1,1) string = default_project_root()
    options.Interactive (1,1) logical = true
    options.WriteArtifacts (1,1) logical = true
    options.OutputDirectory (1,1) string = default_output_directory()
end

projectRoot = strip(projectRoot);
outputDirectory = strip(options.OutputDirectory);
if strlength(projectRoot) == 0
    error("rkkt:data:validation:EmptyProjectRoot", ...
        "projectRoot must be a nonempty string scalar.");
end
if options.WriteArtifacts && ~isfolder(outputDirectory)
    error("rkkt:data:validation:OutputDirectoryMissing", ...
        "OutputDirectory must already exist; PKG-2 does not create directories: %s", ...
        outputDirectory);
end

selectedDays = 14:20;
selectedHours = 1:24;
directData = call_direct_loader(projectRoot);
projectData = rkkt.data.load(projectRoot);
validate_scope(projectData, selectedDays, selectedHours);

sevenDayData = select_seven_day_data( ...
    projectData, selectedDays, selectedHours);
hourMapping = build_hour_mapping( ...
    projectData, selectedDays, selectedHours);
fieldSummary = build_field_summary(sevenDayData);
chronologySummary = build_chronology_summary(sevenDayData);
comparison = compare_data_objects(directData, projectData);
comparisonSummary = comparison_table(comparison);

[tableFiles, tableValues] = planned_tables( ...
    projectData, fieldSummary, hourMapping, chronologySummary, ...
    comparisonSummary, outputDirectory, options.WriteArtifacts);
[figureFiles, figureIndex] = planned_figures( ...
    outputDirectory, options.WriteArtifacts);

if options.WriteArtifacts
    outputFile = fullfile( ...
        outputDirectory, "数据导入模块输出.mat");
else
    outputFile = "";
end

metadata = build_metadata( ...
    projectRoot, projectData, selectedDays, selectedHours, ...
    outputFile, options);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "project_root", projectRoot, ...
    "source_files", string(projectData.hashes.filePath), ...
    "source_hashes", projectData.hashes, ...
    "selected_days", selectedDays, ...
    "selected_hours", selectedHours);
moduleResult.output = struct( ...
    "projectData", projectData, ...
    "sevenDayObservation", sevenDayData);
moduleResult.intermediate = struct( ...
    "hourMapping", hourMapping, ...
    "fieldSummary", fieldSummary, ...
    "chronologySummary", chronologySummary, ...
    "comparisonSummary", comparisonSummary, ...
    "figureIndex", figureIndex, ...
    "chronologicalPlanMW", sevenDayData.chronological.planMW, ...
    "chronologicalWindAvailability", ...
        sevenDayData.chronological.windAvailability, ...
    "chronologicalSolarAvailability", ...
        sevenDayData.chronological.solarAvailability);
moduleResult.diagnostics = struct( ...
    "source_day_count", projectData.meta.nDays, ...
    "source_hours_per_day", projectData.meta.nHours, ...
    "selected_day_count", numel(selectedDays), ...
    "selected_hours_per_day", numel(selectedHours), ...
    "selected_total_hours", height(hourMapping), ...
    "first_selected_day", selectedDays(1), ...
    "last_selected_day", selectedDays(end), ...
    "input_audit_row_count", height(projectData.audit), ...
    "input_audit_all_successful", ...
        all(string(projectData.audit.status) == "PASS"), ...
    "chronology_maximum_absolute_difference", ...
        max(chronologySummary.maximumAbsoluteRoundTripDifference), ...
    "legacy_facade_comparison", comparison, ...
    "artifacts_written", options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "matrix_orientation", "行=自然日，列=日内小时", ...
    "chronological_orientation", ...
        "先按第14日1—24小时，再按第15日1—24小时，直至第20日", ...
    "source_object_scope", "完整365日对象；七日对象仅为人工观察视图", ...
    "mapping_table", hourMapping);
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;

rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    write_validation_tables(tableFiles, tableValues);
    generate_validation_figures( ...
        sevenDayData, figureIndex, options.Interactive);
    save_module_result(outputFile, moduleResult);
end

fprintf("当前模块：数据导入模块\n");
fprintf("公共接口：rkkt.data.load\n");
fprintf("正式生产函数：load_project_data\n");
fprintf("完整源对象：%d日 x %d小时\n", ...
    projectData.meta.nDays, projectData.meta.nHours);
fprintf("人工观察范围：第%d—%d日，共%d小时\n", ...
    selectedDays(1), selectedDays(end), height(hourMapping));
fprintf("新旧入口完整对象严格相同：%d\n", ...
    comparison.full_object_exact_equal);
fprintf("数值叶节点最大绝对差：%.17g\n", ...
    comparison.numeric_maximum_absolute_difference);
if options.WriteArtifacts
    fprintf("固定人工验证输出：%s\n", outputFile);
else
    fprintf("本次仅内存验证，未写人工验证文件。\n");
end
end

function metadata = build_metadata(projectRoot, projectData, days, hours, ...
        outputFile, options)
sourceFiles = string(projectData.hashes.filePath);
sourceHashes = lower(string(projectData.hashes.actualSHA256));
metadata = struct( ...
    "interface_name", "rkkt.data.load", ...
    "production_function", "load_project_data", ...
    "input_artifact", sourceFiles(1), ...
    "input_sha256", sourceHashes(1), ...
    "git_commit", git_commit(projectRoot), ...
    "stage_id", "stage_A4", ...
    "day", days, ...
    "hour", hours, ...
    "iteration", [], ...
    "revision", 0, ...
    "matlab_version", string(version), ...
    "generated_at", string(datetime("now", ...
        "TimeZone", "Asia/Shanghai", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "contract_version", rkkt.contracts.version(), ...
    "module_name", "数据导入模块", ...
    "source_artifacts", sourceFiles, ...
    "source_sha256", sourceHashes, ...
    "output_file", string(outputFile), ...
    "interactive_figures", options.Interactive, ...
    "artifacts_requested", options.WriteArtifacts);
end

function data = call_direct_loader(projectRoot)
data = rkkt.data.load_project_data(projectRoot);
end

function validate_scope(projectData, selectedDays, selectedHours)
if ~isequal(selectedDays, 14:20)
    error("rkkt:data:validation:UnexpectedDays", ...
        "The manual data observation must use days 14:20; actual=%s.", ...
        mat2str(selectedDays));
end
if ~isequal(selectedHours, 1:24)
    error("rkkt:data:validation:UnexpectedHours", ...
        "The manual data observation must use hours 1:24; actual=%s.", ...
        mat2str(selectedHours));
end
if projectData.meta.nDays ~= 365 || ...
        projectData.meta.nHours ~= 24
    error("rkkt:data:validation:SourceTimeContract", ...
        "The source object must remain 365 days by 24 hours.");
end
end

function selected = select_seven_day_data(data, days, hours)
selected = struct();
selected.days = reshape(days, [], 1);
selected.hours = reshape(hours, 1, []);
selected.nDays = numel(days);
selected.hoursPerDay = numel(hours);
selected.nHours = numel(days) * numel(hours);
selected.hydroWaterMin = data.timeseries.hydroWaterMin(days, :);
selected.hydroWaterMax = data.timeseries.hydroWaterMax(days, :);
selected.windAvailability = ...
    data.timeseries.windAvailability(days, hours, :);
selected.solarAvailability = ...
    data.timeseries.solarAvailability(days, hours, :);
selected.planPerUnit = data.timeseries.planPerUnit(days, hours);
selected.planMW = data.timeseries.planMW(days, hours);
selected.chronological = struct( ...
    "planPerUnit", day_hour_matrix_to_sequence( ...
        selected.planPerUnit), ...
    "planMW", day_hour_matrix_to_sequence(selected.planMW), ...
    "windAvailability", day_hour_tensor_to_sequence( ...
        selected.windAvailability), ...
    "solarAvailability", day_hour_tensor_to_sequence( ...
        selected.solarAvailability));
end

function mapping = build_hour_mapping(data, days, hours)
nDays = numel(days);
nHours = numel(hours);
validationIndex = (1:(nDays * nHours)).';
dayPosition = repelem((1:nDays).', nHours);
calendarDay = repelem(days(:), nHours);
hour = repmat(hours(:), nDays, 1);
sourceMatrixRow = calendarDay;
sourceMatrixColumn = hour;
sourceChronologicalIndex = ...
    (calendarDay - 1) * data.meta.nHours + hour;
mapping = table(validationIndex, dayPosition, calendarDay, hour, ...
    sourceMatrixRow, sourceMatrixColumn, sourceChronologicalIndex);
end

function summary = build_field_summary(selected)
fieldName = [ ...
    "hydroWaterMin"
    "hydroWaterMax"
    "windAvailability"
    "solarAvailability"
    "planPerUnit"
    "planMW"];
chineseName = [ ...
    "七日水电日用水下限"
    "七日水电日用水上限"
    "七日风电容量因子"
    "七日光伏容量因子"
    "七日计划功率标幺值"
    "七日计划功率（MW）"];
values = { ...
    selected.hydroWaterMin
    selected.hydroWaterMax
    selected.windAvailability
    selected.solarAvailability
    selected.planPerUnit
    selected.planMW};

n = numel(values);
actualShape = strings(n, 1);
elementCount = zeros(n, 1);
nanCount = zeros(n, 1);
infCount = zeros(n, 1);
minimumValue = zeros(n, 1);
maximumValue = zeros(n, 1);
for k = 1:n
    value = values{k};
    actualShape(k) = size_text(value);
    elementCount(k) = numel(value);
    nanCount(k) = nnz(isnan(value));
    infCount(k) = nnz(isinf(value));
    minimumValue(k) = min(value, [], "all");
    maximumValue(k) = max(value, [], "all");
end
summary = table(fieldName, chineseName, actualShape, elementCount, ...
    nanCount, infCount, minimumValue, maximumValue);
end

function summary = build_chronology_summary(selected)
fieldName = strings(0, 1);
deviceId = zeros(0, 1);
matrixShape = strings(0, 1);
sequenceLength = zeros(0, 1);
maximumAbsoluteRoundTripDifference = zeros(0, 1);

append(selected.planPerUnit, "planPerUnit", 0);
append(selected.planMW, "planMW", 0);
for unit = 1:size(selected.windAvailability, 3)
    append(selected.windAvailability(:, :, unit), ...
        "windAvailability", unit);
end
for unit = 1:size(selected.solarAvailability, 3)
    append(selected.solarAvailability(:, :, unit), ...
        "solarAvailability", unit);
end

summary = table(fieldName, deviceId, matrixShape, sequenceLength, ...
    maximumAbsoluteRoundTripDifference);

    function append(matrix, name, id)
        sequence = day_hour_matrix_to_sequence(matrix);
        reconstructed = reshape( ...
            sequence, size(matrix, 2), size(matrix, 1)).';
        fieldName(end + 1, 1) = name;
        deviceId(end + 1, 1) = id;
        matrixShape(end + 1, 1) = size_text(matrix);
        sequenceLength(end + 1, 1) = numel(sequence);
        maximumAbsoluteRoundTripDifference(end + 1, 1) = ...
            max(abs(matrix - reconstructed), [], "all");
    end
end

function comparison = compare_data_objects(reference, facade)
state = struct( ...
    "node_count", 0, ...
    "numeric_leaf_count", 0, ...
    "class_mismatch_count", 0, ...
    "size_mismatch_count", 0, ...
    "field_order_mismatch_count", 0, ...
    "nonnumeric_mismatch_count", 0, ...
    "numeric_maximum_absolute_difference", 0);
state = compare_node(reference, facade, state);
comparison = state;
comparison.root_class_equal = ...
    strcmp(class(reference), class(facade));
comparison.root_size_equal = isequal(size(reference), size(facade));
comparison.top_level_field_order_equal = ...
    isequal(fieldnames(reference), fieldnames(facade));
comparison.hash_table_exact_equal = ...
    isequaln(reference.hashes, facade.hashes);
comparison.full_object_exact_equal = isequaln(reference, facade);
end

function state = compare_node(left, right, state)
state.node_count = state.node_count + 1;
if ~strcmp(class(left), class(right))
    state.class_mismatch_count = ...
        state.class_mismatch_count + 1;
    return
end
if ~isequal(size(left), size(right))
    state.size_mismatch_count = ...
        state.size_mismatch_count + 1;
    return
end

if isnumeric(left)
    state.numeric_leaf_count = state.numeric_leaf_count + 1;
    if ~isempty(left)
        difference = max(abs(double(left) - double(right)), [], "all");
        if isnan(difference)
            if ~isequaln(left, right)
                state.numeric_maximum_absolute_difference = Inf;
            end
        else
            state.numeric_maximum_absolute_difference = max( ...
                state.numeric_maximum_absolute_difference, difference);
        end
    end
elseif isstruct(left)
    leftFields = fieldnames(left);
    rightFields = fieldnames(right);
    if ~isequal(leftFields, rightFields)
        state.field_order_mismatch_count = ...
            state.field_order_mismatch_count + 1;
        return
    end
    for elementIndex = 1:numel(left)
        for fieldIndex = 1:numel(leftFields)
            name = leftFields{fieldIndex};
            state = compare_node( ...
                left(elementIndex).(name), ...
                right(elementIndex).(name), state);
        end
    end
elseif istable(left)
    leftNames = left.Properties.VariableNames;
    rightNames = right.Properties.VariableNames;
    if ~isequal(leftNames, rightNames) || ...
            ~isequal(left.Properties.RowNames, ...
            right.Properties.RowNames)
        state.field_order_mismatch_count = ...
            state.field_order_mismatch_count + 1;
        return
    end
    for k = 1:numel(leftNames)
        name = leftNames{k};
        state = compare_node(left.(name), right.(name), state);
    end
elseif iscell(left)
    for k = 1:numel(left)
        state = compare_node(left{k}, right{k}, state);
    end
elseif ~isequaln(left, right)
    state.nonnumeric_mismatch_count = ...
        state.nonnumeric_mismatch_count + 1;
end
end

function value = comparison_table(comparison)
aspect = [ ...
    "root_class_equal"
    "root_size_equal"
    "top_level_field_order_equal"
    "class_mismatch_count"
    "size_mismatch_count"
    "field_order_mismatch_count"
    "hash_table_exact_equal"
    "numeric_leaf_count"
    "numeric_maximum_absolute_difference"
    "nonnumeric_mismatch_count"
    "full_object_exact_equal"];
actualValue = [ ...
    string(comparison.root_class_equal)
    string(comparison.root_size_equal)
    string(comparison.top_level_field_order_equal)
    string(comparison.class_mismatch_count)
    string(comparison.size_mismatch_count)
    string(comparison.field_order_mismatch_count)
    string(comparison.hash_table_exact_equal)
    string(comparison.numeric_leaf_count)
    compose("%.17g", ...
        comparison.numeric_maximum_absolute_difference)
    string(comparison.nonnumeric_mismatch_count)
    string(comparison.full_object_exact_equal)];
value = table(aspect, actualValue);
end

function [files, values] = planned_tables(projectData, fieldSummary, ...
        hourMapping, chronologySummary, comparisonSummary, ...
        outputDirectory, writeArtifacts)
values = { ...
    projectData.hashes
    fieldSummary
    hourMapping
    chronologySummary
    comparisonSummary};
if ~writeArtifacts
    files = strings(0, 1);
    return
end
baseNames = [ ...
    "数据导入模块_输入文件哈希.csv"
    "数据导入模块_七日数据字段维数汇总.csv"
    "数据导入模块_七日小时映射表.csv"
    "数据导入模块_七日时序往返重排诊断.csv"
    "数据导入模块_新旧入口对照.csv"];
files = fullfile(outputDirectory, baseNames);
files = reshape(string(files), [], 1);
end

function [files, index] = planned_figures(outputDirectory, writeArtifacts)
figureName = [ ...
    "七日计划功率曲线"
    "七日风电容量因子曲线"
    "七日光伏容量因子曲线"
    "原始时序与按日重排结果对照图"
    "每日数据点数量图"];
if writeArtifacts
    figPath = fullfile(outputDirectory, ...
        "数据导入模块_" + figureName + ".fig");
    pngPath = fullfile(outputDirectory, ...
        "数据导入模块_" + figureName + ".png");
    files = reshape([figPath, pngPath].', [], 1);
else
    figPath = strings(numel(figureName), 1);
    pngPath = strings(numel(figureName), 1);
    files = strings(0, 1);
end
index = table(figureName, reshape(figPath, [], 1), ...
    reshape(pngPath, [], 1), ...
    'VariableNames', ["figureName", "figPath", "pngPath"]);
end

function write_validation_tables(files, values)
if numel(files) ~= numel(values)
    error("rkkt:data:validation:TablePlanMismatch", ...
        "The table-file plan does not match the in-memory table count.");
end
for k = 1:numel(files)
    rkkt.artifacts.write_table_csv_17g_atomic(values{k}, files(k));
end
end

function generate_validation_figures(selected, figureIndex, interactive)
visibility = "off";
if interactive
    visibility = "on";
end
x = (1:selected.nHours).';
dayLabels = compose("第%d日", selected.days);

fig = new_figure(figureIndex.figureName(1), visibility);
plot(x, selected.chronological.planMW, "LineWidth", 1.2);
decorate_hour_axis(selected, "连续小时序号", "计划功率（MW）", ...
    "第14—20日计划功率曲线");
grid on;
save_figure_pair(fig, figureIndex.figPath(1), ...
    figureIndex.pngPath(1));
close_if_noninteractive(fig, interactive);

fig = new_figure(figureIndex.figureName(2), visibility);
plot(x, selected.chronological.windAvailability, "LineWidth", 1.0);
decorate_hour_axis(selected, "连续小时序号", "风电容量因子", ...
    "第14—20日风电容量因子曲线");
legend(compose("风电%d", ...
    1:size(selected.windAvailability, 3)), ...
    "Location", "eastoutside");
grid on;
save_figure_pair(fig, figureIndex.figPath(2), ...
    figureIndex.pngPath(2));
close_if_noninteractive(fig, interactive);

fig = new_figure(figureIndex.figureName(3), visibility);
plot(x, selected.chronological.solarAvailability, "LineWidth", 1.0);
decorate_hour_axis(selected, "连续小时序号", "光伏容量因子", ...
    "第14—20日光伏容量因子曲线");
legend(compose("光伏%d", ...
    1:size(selected.solarAvailability, 3)), ...
    "Location", "eastoutside");
grid on;
save_figure_pair(fig, figureIndex.figPath(3), ...
    figureIndex.pngPath(3));
close_if_noninteractive(fig, interactive);

planSequence = selected.chronological.planMW;
reconstructed = reshape( ...
    planSequence, selected.hoursPerDay, selected.nDays).';
reconstructedSequence = ...
    day_hour_matrix_to_sequence(reconstructed);
fig = new_figure(figureIndex.figureName(4), visibility);
layout = tiledlayout(fig, 2, 1, "TileSpacing", "compact");
nexttile(layout);
plot(x, planSequence, "-", "LineWidth", 1.2);
hold on;
plot(x, reconstructedSequence, "--", "LineWidth", 1.0);
hold off;
decorate_hour_axis(selected, "连续小时序号", "计划功率（MW）", ...
    "原始七日矩阵与往返重排结果");
legend(["原始七日矩阵", "往返重排结果"], ...
    "Location", "best");
grid on;
nexttile(layout);
plot(x, abs(planSequence - reconstructedSequence), ...
    "LineWidth", 1.2);
decorate_hour_axis(selected, "连续小时序号", "绝对差", ...
    "逐小时往返重排绝对差");
grid on;
save_figure_pair(fig, figureIndex.figPath(4), ...
    figureIndex.pngPath(4));
close_if_noninteractive(fig, interactive);

fig = new_figure(figureIndex.figureName(5), visibility);
bar(1:selected.nDays, ...
    repmat(selected.hoursPerDay, selected.nDays, 1));
xticks(1:selected.nDays);
xticklabels(dayLabels);
xlabel("自然日");
ylabel("数据点数量");
title("第14—20日每日小时数据点数量");
ylim([0, selected.hoursPerDay + 4]);
grid on;
save_figure_pair(fig, figureIndex.figPath(5), ...
    figureIndex.pngPath(5));
close_if_noninteractive(fig, interactive);
end

function fig = new_figure(name, visibility)
fig = figure( ...
    "Name", "数据验证：" + name, ...
    "NumberTitle", "off", ...
    "Color", "w", ...
    "Visible", visibility, ...
    "Position", [100, 100, 1180, 680]);
end

function decorate_hour_axis(selected, xLabelText, yLabelText, titleText)
xlabel(xLabelText);
ylabel(yLabelText);
title(titleText);
xlim([1, selected.nHours]);
for boundary = selected.hoursPerDay + 0.5: ...
        selected.hoursPerDay:selected.nHours - 0.5
    xline(boundary, ":", "Color", [0.45, 0.45, 0.45], ...
        "HandleVisibility", "off");
end
centers = (0:(selected.nDays - 1)) * selected.hoursPerDay + ...
    (selected.hoursPerDay + 1) / 2;
xticks(centers);
xticklabels(compose("第%d日", selected.days));
end

function save_figure_pair(fig, figPath, pngPath)
temporaryFig = string(tempname(fileparts(figPath))) + ".fig";
temporaryPng = string(tempname(fileparts(pngPath))) + ".png";
cleanup = onCleanup(@() delete_files([temporaryFig; temporaryPng]));
savefig(fig, temporaryFig);
exportgraphics(fig, temporaryPng, "Resolution", 200);
movefile(temporaryFig, figPath, "f");
movefile(temporaryPng, pngPath, "f");
clear cleanup
end

function close_if_noninteractive(fig, interactive)
if ~interactive && isgraphics(fig)
    close(fig);
end
end

function save_module_result(outputFile, moduleResult)
temporary = string(tempname(fileparts(outputFile))) + ".mat";
cleanup = onCleanup(@() delete_files(temporary));
save(temporary, "moduleResult", "-v7.3");
movefile(temporary, outputFile, "f");
clear cleanup
end

function sequence = day_hour_matrix_to_sequence(matrix)
sequence = reshape(matrix.', [], 1);
end

function sequence = day_hour_tensor_to_sequence(tensor)
sequence = reshape(permute(tensor, [2, 1, 3]), ...
    size(tensor, 1) * size(tensor, 2), size(tensor, 3));
end

function value = size_text(array)
value = strjoin(string(size(array)), "x");
end

function commit = git_commit(projectRoot)
commit = "NOT_AVAILABLE";
if contains(projectRoot, """")
    return
end
command = 'git -C "' + projectRoot + '" rev-parse HEAD';
[status, output] = system(command);
candidate = lower(strip(string(output)));
if status == 0 && ~isempty(regexp(char(candidate), ...
        "^[0-9a-f]{40}$", "once"))
    commit = candidate;
end
end

function root = default_project_root()
root = rkkt.projectRoot();
end

function directory = default_output_directory()
directory = string(fileparts(mfilename("fullpath")));
end


function delete_files(paths)
for k = 1:numel(paths)
    if isfile(paths(k))
        delete(paths(k));
    end
end
end
