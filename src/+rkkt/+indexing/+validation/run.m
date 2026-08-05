function moduleResult = run(options)
%RUN Run standalone manual validation for the PKG-3 indexing module.
%   The default input is the fixed PKG-2 data-module MAT artifact. The
%   routine compares RKKT.INDEXING.BUILD with BUILD_STAGE_A4_INDEX, records
%   objective index facts, and writes fixed manual artifacts directly into
%   this existing directory. It never creates a directory or calls model
%   assembly, KKT, solver, or IPM code.

arguments
    options.InputArtifact (1,1) string = default_input_artifact()
    options.Interactive (1,1) logical = true
    options.WriteArtifacts (1,1) logical = true
    options.OutputDirectory (1,1) string = default_output_directory()
end

inputArtifact = strip(options.InputArtifact);
outputDirectory = strip(options.OutputDirectory);
if ~isfile(inputArtifact)
    error("rkkt:indexing:validation:InputArtifactMissing", ...
        "PKG-2 data artifact does not exist: %s", inputArtifact);
end
if options.WriteArtifacts && ~isfolder(outputDirectory)
    error("rkkt:indexing:validation:OutputDirectoryMissing", ...
        "OutputDirectory must already exist; PKG-3 does not create directories: %s", ...
        outputDirectory);
end

loaded = load(inputArtifact, "moduleResult");
if ~isfield(loaded, "moduleResult")
    error("rkkt:indexing:validation:InputEnvelopeMissing", ...
        "Input MAT does not contain moduleResult.");
end
dataResult = loaded.moduleResult;
rkkt.contracts.validateModuleResult(dataResult);
if string(dataResult.meta.interface_name) ~= "rkkt.data.load" || ...
        ~isfield(dataResult.output, "projectData")
    error("rkkt:indexing:validation:InputContract", ...
        "Input must be the PKG-2 rkkt.data.load moduleResult.");
end
data = dataResult.output.projectData;
projectRoot = string(data.projectRoot);

directIndex = call_direct_index(data);
config = rkkt.model.load_stage_a4_configuration(projectRoot);
index = rkkt.indexing.build(data,config);
legacyFacadeExact = isequaln(directIndex, index);

dateHourCheck = build_date_hour_check(index);
dailyCounts = build_daily_counts(index);
dailyFixedZero = build_daily_fixed_zero(index);
blockDimensions = build_block_dimensions(index);
facts = inspect_index_facts(index, data, legacyFacadeExact);
if ~all(cell2mat(struct2cell(facts)))
    error("rkkt:indexing:validation:ObjectiveCheck", ...
        "One or more PKG-3 objective index checks are false.");
end

[tableFiles, tableValues] = planned_tables( ...
    index, dateHourCheck, outputDirectory, options.WriteArtifacts);
[figureFiles, figureIndex] = planned_figures( ...
    outputDirectory, options.WriteArtifacts);
if options.WriteArtifacts
    outputFile = fullfile(outputDirectory, "索引模块输出.mat");
else
    outputFile = "";
end

metadata = struct( ...
    "interface_name", "rkkt.indexing.build", ...
    "production_function", "build_stage_a4_index", ...
    "input_artifact", inputArtifact, ...
    "input_sha256", compute_input_sha256(inputArtifact), ...
    "git_commit", git_commit(string(data.projectRoot)), ...
    "stage_id", "stage_A4", ...
    "day", 14:20, ...
    "hour", 1:24, ...
    "iteration", [], ...
    "revision", 0, ...
    "matlab_version", string(version), ...
    "generated_at", string(datetime("now", ...
        "TimeZone", "Asia/Shanghai", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "contract_version", rkkt.contracts.version(), ...
    "module_name", "索引模块", ...
    "output_file", string(outputFile), ...
    "interactive_figures", options.Interactive, ...
    "artifacts_requested", options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "projectData", data, ...
    "dataModuleMetadata", dataResult.meta, ...
    "inputArtifact", inputArtifact);
moduleResult.output = struct("index", index);
moduleResult.intermediate = struct( ...
    "dateHourCheck", dateHourCheck, ...
    "dailyCounts", dailyCounts, ...
    "dailyFixedZero", dailyFixedZero, ...
    "blockDimensions", blockDimensions, ...
    "figureIndex", figureIndex);
moduleResult.diagnostics = struct( ...
    "legacy_facade_exact_equal", legacyFacadeExact, ...
    "objective_facts", facts, ...
    "variable_count", height(index.variable_index), ...
    "constraint_count", height(index.constraint_index), ...
    "hour_block_count", height(dateHourCheck), ...
    "fixed_zero_count", height(index.fixed_zero_map), ...
    "permutation_row_count", height(index.permutation_map), ...
    "soc_link_count", height(index.soc_link_map), ...
    "artifacts_written", options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "canonical_variable_order", ...
        "全局容量、每日容量副本、按日期小时排列的活动变量", ...
    "canonical_constraint_order", ...
        "全局约束、每日容量绑定、按日期小时排列的等式与不等式", ...
    "hour_block_order", ...
        "第14日1—24小时至第20日1—24小时，共168块", ...
    "fixed_zero_semantics", ...
        "零可用率风光从活动变量及重合上下界中精确删除", ...
    "soc_semantics", ...
        "仅日内前一小时连接；每日首末均为0.5E");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    write_tables(tableFiles, tableValues);
    generate_figures(dailyCounts, dailyFixedZero, ...
        blockDimensions, figureIndex, options.Interactive);
    save_module_result(outputFile, moduleResult);
end

fprintf("当前模块：索引模块\n");
fprintf("公共接口：rkkt.indexing.build\n");
fprintf("正式生产函数：build_stage_a4_index\n");
fprintf("新旧索引严格相同：%d\n", legacyFacadeExact);
fprintf("变量/约束/小时块/固定零/SOC连接：%d/%d/%d/%d/%d\n", ...
    height(index.variable_index), height(index.constraint_index), ...
    height(dateHourCheck), height(index.fixed_zero_map), ...
    height(index.soc_link_map));
if options.WriteArtifacts
    fprintf("固定人工验证输出：%s\n", outputFile);
else
    fprintf("本次仅内存验证，未写人工验证文件。\n");
end
end

function index = call_direct_index(data)
config = rkkt.model.load_stage_a4_configuration( ...
    string(data.projectRoot));
index = rkkt.indexing.build_stage_a4_index(data,config);
end

function facts = inspect_index_facts(index, data, legacyFacadeExact)
hourly = index.block_index(index.block_index.day > 0 & ...
    index.block_index.hour_start > 0, :);
variables = index.variable_index;
constraints = index.constraint_index;

daysExact = isequal(index.scope.days, 14:20);
hoursExact = isequal(index.scope.hours, 1:24);
hourBlocksExact = height(hourly) == 168 && ...
    isequal(hourly.day, repelem((14:20).', 24)) && ...
    isequal(hourly.hour_start, repmat((1:24).', 7, 1));
variableNumbers = variables.global_index_start;
variableGlobalContinuousUnique = ...
    isequal(variableNumbers, (1:height(variables)).') && ...
    isequal(variables.global_index_end, variableNumbers) && ...
    numel(unique(variableNumbers)) == height(variables);
constraintNumbers = constraints.global_row;
constraintGlobalContinuousUnique = ...
    isequal(constraintNumbers, (1:height(constraints)).') && ...
    numel(unique(constraintNumbers)) == height(constraints);
fixedZeroRemoved = fixed_zero_removed(index, data);
permutationBijective = permutation_bijective(index.permutation_map);
[socOnlyWithinDay, dailyBoundaryHalfEnergy] = soc_facts(index);

facts = struct( ...
    "days_14_to_20_exact", daysExact, ...
    "twenty_four_hours_per_day_exact", hoursExact, ...
    "one_hundred_sixty_eight_hour_blocks_ordered", hourBlocksExact, ...
    "variable_global_numbers_continuous_unique", ...
        variableGlobalContinuousUnique, ...
    "constraint_global_numbers_continuous_unique", ...
        constraintGlobalContinuousUnique, ...
    "fixed_zero_removed_from_active_index", fixedZeroRemoved, ...
    "permutation_map_bijective", permutationBijective, ...
    "soc_links_only_within_day", socOnlyWithinDay, ...
    "daily_initial_terminal_half_energy", dailyBoundaryHalfEnergy, ...
    "legacy_facade_exact_equal", legacyFacadeExact);
end

function value = fixed_zero_removed(index, data)
value = height(index.fixed_zero_map) == 422;
variables = index.variable_index;
inequalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "inequality", :);
for k = 1:height(index.fixed_zero_map)
    row = index.fixed_zero_map(k, :);
    active = variables.day == row.day & ...
        variables.hour == row.hour & ...
        string(variables.asset_type) == string(row.asset_type) & ...
        variables.asset_id == row.asset_id & ...
        string(variables.variable_name) == string(row.variable_name);
    bounds = inequalities.day == row.day & ...
        inequalities.hour == row.hour & ...
        string(inequalities.asset_type) == string(row.asset_type) & ...
        inequalities.asset_id == row.asset_id;
    if string(row.asset_type) == "wind"
        availability = data.timeseries.windAvailability( ...
            row.day, row.hour, row.asset_id);
    else
        availability = data.timeseries.solarAvailability( ...
            row.day, row.hour, row.asset_id);
    end
    value = value && ~any(active) && ~any(bounds) && ...
        row.fixed_value == 0 && row.fixed_direction_value == 0 && ...
        availability == 0;
end
end

function value = permutation_bijective(mapping)
value = true;
spaces = ["variable"; "equality"; "inequality"];
for space = spaces.'
    rows = mapping(string(mapping.space_name) == space, :);
    n = height(rows);
    solver = rows.solver_index;
    value = value && isequal(rows.canonical_index, (1:n).') && ...
        all(solver == fix(solver)) && all(solver >= 1) && ...
        all(solver <= n) && numel(unique(solver)) == n;
end
end

function [withinDay, halfEnergy] = soc_facts(index)
withinDay = true;
halfEnergy = true;
variables = index.variable_index;
for k = 1:height(index.soc_link_map)
    row = index.soc_link_map(k, :);
    if row.hour == 1
        withinDay = withinDay && isnan(row.predecessor_hour) && ...
            row.predecessor_soc_global_index == 0;
        halfEnergy = halfEnergy && ...
            row.initial_energy_fraction == 0.5 && ...
            string(row.boundary_source) == ...
            "formal_daily_fixed_half_energy";
    else
        predecessor = variables(row.predecessor_soc_global_index, :);
        withinDay = withinDay && predecessor.day == row.day && ...
            predecessor.hour == row.hour - 1 && ...
            predecessor.asset_id == row.storage_id && ...
            string(predecessor.variable_name) == "SOC";
    end
    if row.hour == 24
        halfEnergy = halfEnergy && row.terminal_equality && ...
            row.terminal_energy_fraction == 0.5;
    else
        halfEnergy = halfEnergy && ~row.terminal_equality;
    end
end
end

function value = build_date_hour_check(index)
blocks = index.block_index(index.block_index.day > 0 & ...
    index.block_index.hour_start > 0, :);
n = height(blocks);
sequenceIndex = (1:n).';
dayPosition = repelem((1:7).', 24);
day = blocks.day;
hour = blocks.hour_start;
blockId = string(blocks.block_id);
variableStart = blocks.variable_start;
variableEnd = blocks.variable_end;
variableCount = blocks.n_primal;
equalityStart = blocks.equality_start;
equalityEnd = blocks.equality_end;
equalityCount = blocks.n_equalities;
kktBlockDimension = blocks.kkt_block_dimension;
constraintCount = zeros(n, 1);
fixedZeroCount = zeros(n, 1);
socLinkCount = zeros(n, 1);
for k = 1:n
    constraintCount(k) = nnz( ...
        index.constraint_index.day == day(k) & ...
        index.constraint_index.hour == hour(k));
    fixedZeroCount(k) = nnz( ...
        index.fixed_zero_map.day == day(k) & ...
        index.fixed_zero_map.hour == hour(k));
    socLinkCount(k) = nnz( ...
        index.soc_link_map.day == day(k) & ...
        index.soc_link_map.hour == hour(k));
end
value = table(sequenceIndex, dayPosition, day, hour, blockId, ...
    variableStart, variableEnd, variableCount, equalityStart, ...
    equalityEnd, equalityCount, constraintCount, fixedZeroCount, ...
    socLinkCount, kktBlockDimension);
end

function value = build_daily_counts(index)
day = (14:20).';
variableCount = zeros(7, 1);
equalityCount = zeros(7, 1);
inequalityCount = zeros(7, 1);
constraintCount = zeros(7, 1);
types = string(index.constraint_index.constraint_type);
for k = 1:7
    variableCount(k) = nnz(index.variable_index.day == day(k));
    equalityCount(k) = nnz(index.constraint_index.day == day(k) & ...
        types == "equality");
    inequalityCount(k) = nnz(index.constraint_index.day == day(k) & ...
        types == "inequality");
    constraintCount(k) = equalityCount(k) + inequalityCount(k);
end
value = table(day, variableCount, equalityCount, ...
    inequalityCount, constraintCount);
end

function value = build_daily_fixed_zero(index)
day = (14:20).';
fixedZeroCount = zeros(7, 1);
for k = 1:7
    fixedZeroCount(k) = nnz(index.fixed_zero_map.day == day(k));
end
value = table(day, fixedZeroCount);
end

function value = build_block_dimensions(index)
blocks = index.block_index(index.block_index.day > 0 & ...
    index.block_index.hour_start > 0, :);
day = blocks.day;
hour = blocks.hour_start;
primalCount = blocks.n_primal;
equalityCount = blocks.n_equalities;
kktBlockDimension = blocks.kkt_block_dimension;
value = table(day, hour, primalCount, equalityCount, kktBlockDimension);
end

function [files, values] = planned_tables( ...
        index, dateHourCheck, outputDirectory, writeArtifacts)
values = { ...
    index.variable_index
    index.constraint_index
    index.block_index
    index.fixed_zero_map
    index.soc_link_map
    index.permutation_map
    dateHourCheck};
if ~writeArtifacts
    files = strings(0, 1);
    return
end
names = [ ...
    "变量索引表.csv"
    "约束索引表.csv"
    "小时块索引表.csv"
    "固定零变量映射表.csv"
    "SOC连接关系表.csv"
    "排列映射表.csv"
    "日期小时索引检查表.csv"];
files = reshape(string(fullfile(outputDirectory, names)), [], 1);
end

function [files, index] = planned_figures(outputDirectory, writeArtifacts)
figureName = [ ...
    "每日变量和约束数量"
    "每日固定零变量数量"
    "24小时块维数分布"];
if writeArtifacts
    figPath = fullfile(outputDirectory, figureName + ".fig");
    pngPath = fullfile(outputDirectory, figureName + ".png");
    files = reshape([figPath, pngPath].', [], 1);
else
    figPath = strings(3, 1);
    pngPath = strings(3, 1);
    files = strings(0, 1);
end
index = table(figureName, reshape(figPath, [], 1), ...
    reshape(pngPath, [], 1), ...
    'VariableNames', ["figureName", "figPath", "pngPath"]);
end

function write_tables(files, values)
for k = 1:numel(files)
    rkkt.artifacts.write_table_csv_17g_atomic(values{k}, files(k));
end
end

function generate_figures(dailyCounts, dailyFixedZero, ...
        blockDimensions, figureIndex, interactive)
visibility = "off";
if interactive
    visibility = "on";
end

fig = new_figure(figureIndex.figureName(1), visibility);
bar(dailyCounts.day, ...
    [dailyCounts.variableCount, dailyCounts.constraintCount], ...
    "grouped");
xlabel("自然日");
ylabel("数量");
title("第14—20日每日变量和约束数量");
legend(["变量", "约束"], "Location", "best");
grid on;
save_figure_pair(fig, figureIndex.figPath(1), figureIndex.pngPath(1));
close_if_needed(fig, interactive);

fig = new_figure(figureIndex.figureName(2), visibility);
bar(dailyFixedZero.day, dailyFixedZero.fixedZeroCount);
xlabel("自然日");
ylabel("固定零变量数量");
title("第14—20日每日固定零变量数量");
grid on;
save_figure_pair(fig, figureIndex.figPath(2), figureIndex.pngPath(2));
close_if_needed(fig, interactive);

fig = new_figure(figureIndex.figureName(3), visibility);
hold on;
for day = 14:20
    rows = blockDimensions.day == day;
    plot(blockDimensions.hour(rows), ...
        blockDimensions.kktBlockDimension(rows), ...
        "-o", "LineWidth", 1.0, "MarkerSize", 3);
end
hold off;
xlabel("日内小时");
ylabel("小时块 KKT 维数");
title("第14—20日24小时块维数分布");
xticks(1:24);
legend(compose("第%d日", 14:20), "Location", "eastoutside");
grid on;
save_figure_pair(fig, figureIndex.figPath(3), figureIndex.pngPath(3));
close_if_needed(fig, interactive);
end

function fig = new_figure(name, visibility)
fig = figure( ...
    "Name", "索引验证：" + name, ...
    "NumberTitle", "off", ...
    "Color", "w", ...
    "Visible", visibility, ...
    "Position", [100, 100, 1180, 680]);
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

function close_if_needed(fig, interactive)
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

function value = compute_input_sha256(inputArtifact)
value = rkkt.data.compute_sha256_file(inputArtifact);
end

function commit = git_commit(projectRoot)
commit = "NOT_AVAILABLE";
if contains(projectRoot, """")
    return
end
command = "git -C """ + projectRoot + """ rev-parse HEAD";
[status, output] = system(command);
candidate = lower(strip(string(output)));
if status == 0 && ~isempty(regexp(char(candidate), ...
        "^[0-9a-f]{40}$", "once"))
    commit = candidate;
end
end

function pathValue = default_input_artifact()
validationDirectory = string(fileparts(mfilename("fullpath")));
indexingDirectory = string(fileparts(validationDirectory));
rkktDirectory = string(fileparts(indexingDirectory));
pathValue = fullfile(rkktDirectory, "+data", "+validation", ...
    "数据导入模块输出.mat");
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
