function tests = test_pkg3_indexing_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot, "src");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(sourceRoot);
addpath(fullfile(sourceRoot, "model"));
addpath(fullfile(sourceRoot, "indexing"));

dataArtifact = fullfile(sourceRoot, "+rkkt", "+data", ...
    "+validation", "数据导入模块输出.mat");
loaded = load(dataArtifact, "moduleResult");
data = loaded.moduleResult.output.projectData;
legacyIndex = build_stage_a4_index(data);
facadeIndex = rkkt.indexing.build(data);
manualResult = rkkt.indexing.validation.run( ...
    Interactive=false, WriteArtifacts=true);

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.data = data;
testCase.TestData.legacyIndex = legacyIndex;
testCase.TestData.facadeIndex = facadeIndex;
testCase.TestData.manualResult = manualResult;
end

function testLegacyAndFacadeAreStrictlyEqual(testCase)
verifyTrue(testCase, isequaln( ...
    testCase.TestData.legacyIndex, ...
    testCase.TestData.facadeIndex));
verifyTrue(testCase, testCase.TestData.manualResult. ...
    diagnostics.legacy_facade_exact_equal);
end

function testRequiredIndexFieldsExist(testCase)
required = [ ...
    "version"
    "model_contract_version"
    "scope"
    "variable_index"
    "constraint_index"
    "block_index"
    "fixed_zero_map"
    "permutation_map"
    "soc_link_map"
    "counts"
    "expected"];
actual = string(fieldnames(testCase.TestData.facadeIndex));
verifyTrue(testCase, all(ismember(required, actual)));
end

function testDateHourBlocksAreExactly168(testCase)
index = testCase.TestData.facadeIndex;
blocks = index.block_index(index.block_index.day > 0 & ...
    index.block_index.hour_start > 0, :);
verifyEqual(testCase, height(blocks), 168);
verifyEqual(testCase, blocks.day, repelem((14:20).', 24));
verifyEqual(testCase, blocks.hour_start, repmat((1:24).', 7, 1));
verifyEqual(testCase, blocks.hour_end, blocks.hour_start);
for day = 14:20
    verifyEqual(testCase, nnz(blocks.day == day), 24);
end
end

function testGlobalNumbersAreContinuousAndUnique(testCase)
index = testCase.TestData.facadeIndex;
variables = index.variable_index.global_index_start;
constraints = index.constraint_index.global_row;
verifyEqual(testCase, variables, (1:height(index.variable_index)).');
verifyEqual(testCase, index.variable_index.global_index_end, variables);
verifyEqual(testCase, numel(unique(variables)), numel(variables));
verifyEqual(testCase, constraints, ...
    (1:height(index.constraint_index)).');
verifyEqual(testCase, numel(unique(constraints)), numel(constraints));
end

function testFixedZeroMapIsExactAndRemoved(testCase)
index = testCase.TestData.facadeIndex;
data = testCase.TestData.data;
fixed = index.fixed_zero_map;
variables = index.variable_index;
inequalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "inequality", :);
verifyEqual(testCase, height(fixed), 422);
verifyEqual(testCase, fixed.fixed_value, zeros(422, 1));
verifyEqual(testCase, fixed.fixed_direction_value, zeros(422, 1));
for k = 1:height(fixed)
    row = fixed(k, :);
    active = variables.day == row.day & ...
        variables.hour == row.hour & ...
        string(variables.asset_type) == string(row.asset_type) & ...
        variables.asset_id == row.asset_id & ...
        string(variables.variable_name) == string(row.variable_name);
    bounds = inequalities.day == row.day & ...
        inequalities.hour == row.hour & ...
        string(inequalities.asset_type) == string(row.asset_type) & ...
        inequalities.asset_id == row.asset_id;
    verifyFalse(testCase, any(active));
    verifyFalse(testCase, any(bounds));
    if string(row.asset_type) == "wind"
        availability = data.timeseries.windAvailability( ...
            row.day, row.hour, row.asset_id);
    else
        availability = data.timeseries.solarAvailability( ...
            row.day, row.hour, row.asset_id);
    end
    verifyEqual(testCase, availability, 0);
end
end

function testPermutationMapIsBijective(testCase)
mapping = testCase.TestData.facadeIndex.permutation_map;
for space = ["variable", "equality", "inequality"]
    rows = mapping(string(mapping.space_name) == space, :);
    n = height(rows);
    verifyEqual(testCase, rows.canonical_index, (1:n).');
    verifyTrue(testCase, all(rows.solver_index >= 1));
    verifyTrue(testCase, all(rows.solver_index <= n));
    verifyEqual(testCase, numel(unique(rows.solver_index)), n);
end
end

function testSocLinksNeverCrossDaysAndCloseAtHalfEnergy(testCase)
index = testCase.TestData.facadeIndex;
links = index.soc_link_map;
variables = index.variable_index;
verifyEqual(testCase, height(links), 336);
for k = 1:height(links)
    row = links(k, :);
    if row.hour == 1
        verifyTrue(testCase, isnan(row.predecessor_hour));
        verifyEqual(testCase, row.predecessor_soc_global_index, 0);
        verifyEqual(testCase, row.initial_energy_fraction, 0.5);
        verifyEqual(testCase, string(row.boundary_source), ...
            "formal_daily_fixed_half_energy");
    else
        predecessor = variables( ...
            row.predecessor_soc_global_index, :);
        verifyEqual(testCase, predecessor.day, row.day);
        verifyEqual(testCase, predecessor.hour, row.hour - 1);
        verifyEqual(testCase, predecessor.asset_id, row.storage_id);
        verifyEqual(testCase, string(predecessor.variable_name), "SOC");
    end
    if row.hour == 24
        verifyTrue(testCase, row.terminal_equality);
        verifyEqual(testCase, row.terminal_energy_fraction, 0.5);
    else
        verifyFalse(testCase, row.terminal_equality);
    end
end
end

function testValidationEntryWritesFixedMatCsvAndFigures(testCase)
value = testCase.TestData.manualResult;
rkkt.contracts.validateModuleResult(value);
verifyTrue(testCase, isfile(value.meta.output_file));
verifyEqual(testCase, numel(value.tableFiles), 7);
verifyEqual(testCase, numel(value.figureFiles), 6);
verifyTrue(testCase, all(isfile(value.tableFiles)));
verifyTrue(testCase, all(isfile(value.figureFiles)));

expectedTables = [ ...
    "变量索引表.csv"
    "约束索引表.csv"
    "小时块索引表.csv"
    "固定零变量映射表.csv"
    "SOC连接关系表.csv"
    "排列映射表.csv"
    "日期小时索引检查表.csv"];
actualTables = strings(7, 1);
for k = 1:7
    [~, name, extension] = fileparts(value.tableFiles(k));
    actualTables(k) = string(name) + string(extension);
end
verifyEqual(testCase, actualTables, expectedTables);
verifyEqual(testCase, value.diagnostics.hour_block_count, 168);
end
