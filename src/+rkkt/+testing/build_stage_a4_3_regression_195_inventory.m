function [relativeFiles,inventory,components] = ...
        build_stage_a4_3_regression_195_inventory(repositoryRoot)
%BUILD_STAGE_A4_3_REGRESSION_195_INVENTORY Build the frozen 195-test suite.

arguments
    repositoryRoot (1,1) string
end
components = rkkt.testing.stage_a4_3_regression_195_plan();
fileGroups = { ...
    "tests/integration/test_stage_a4_small_step_root_cause_audit.m"
    "tests/integration/test_stage_a4_common_step_ab_comparison.m"
    "tests/integration/test_stage_a4_complementarity_gap_audit.m"
    "tests/integration/test_stage_a4_five_iteration_diagnostic.m"
    [ ...
        "tests/unit/test_stage_a4_model.m"
        "tests/unit/test_stage_a4_step_update.m"
        "tests/integration/test_stage_a4_single_iteration.m"]
    [ ...
        "tests/unit/test_stage_a3_index.m"
        "tests/unit/test_stage_a3_linearization.m"
        "tests/unit/test_stage_a3_solver_components.m"
        "tests/unit/test_stage_a3_historical_preflight.m"
        "tests/unit/test_stage_a3_test_inventory_contract.m"
        "tests/equivalence/test_stage_a3_direction_equivalence.m"
        "tests/equivalence/test_stage_a3_nonzero_binding_residual.m"
        "tests/integration/test_stage_a3_artifacts.m"
        "tests/integration/test_stage_a3_report.m"]
    [ ...
        "tests/unit/test_stage_a2_index.m"
        "tests/unit/test_stage_a2_linearization.m"
        "tests/unit/test_stage_a2_solver_components.m"
        "tests/equivalence/test_stage_a2_direction_equivalence.m"
        "tests/integration/test_stage_a2_artifacts.m"
        "tests/integration/test_stage_a2_report.m"]
    [ ...
        "tests/unit/test_stage_a1_index.m"
        "tests/unit/test_stage_a1_linearization.m"
        "tests/unit/test_stage_a1_solver_components.m"
        "tests/equivalence/test_stage_a1_direction_equivalence.m"
        "tests/integration/test_stage_a1_artifacts.m"
        "tests/integration/test_stage_a1_report.m"]};

relativeFiles = strings(0,1);
testName = strings(0,1);
sourceFile = strings(0,1);
componentLabel = strings(0,1);
componentOrder = zeros(0,1,"uint32");
for componentIndex = 1:height(components)
    files = string(fileGroups{componentIndex});
    componentNames = strings(0,1);
    componentSources = strings(0,1);
    for fileIndex = 1:numel(files)
        absolute = fullfile(repositoryRoot, ...
            replace(files(fileIndex),"/",filesep));
        assert(isfile(absolute), ...
            "stageA4:a43:tests:Regression195MissingFile", ...
            "Frozen regression source is missing: %s",absolute);
        fileSuite = matlab.unittest.TestSuite.fromFile(absolute);
        assert(~isempty(fileSuite), ...
            "stageA4:a43:tests:Regression195EmptyFile", ...
            "Frozen regression source contains no tests: %s",absolute);
        componentNames = [componentNames; ...
            string({fileSuite.Name}).']; %#ok<AGROW>
        componentSources = [componentSources; ...
            repmat(files(fileIndex),numel(fileSuite),1)]; %#ok<AGROW>
    end
    expectedCount = components.expected_count(componentIndex);
    assert(numel(componentNames)==expectedCount && ...
        numel(unique(componentNames))==expectedCount, ...
        "stageA4:a43:tests:Regression195Component", ...
        "%s must contain exactly %d unique tests.", ...
        components.component_label(componentIndex),expectedCount);
    validate_authoritative_inventory(repositoryRoot, ...
        components.component_label(componentIndex), ...
        componentNames,componentSources);
    relativeFiles = [relativeFiles;files]; %#ok<AGROW>
    testName = [testName;componentNames]; %#ok<AGROW>
    sourceFile = [sourceFile;componentSources]; %#ok<AGROW>
    componentLabel = [componentLabel;repmat( ...
        components.component_label(componentIndex), ...
        expectedCount,1)]; %#ok<AGROW>
    componentOrder = [componentOrder;repmat( ...
        components.component_order(componentIndex), ...
        expectedCount,1)]; %#ok<AGROW>
end
testOrder = uint32((1:numel(testName)).');
inventory = table(testOrder,testName,sourceFile,componentOrder, ...
    componentLabel,'VariableNames',{'test_order','test_name', ...
    'source_file','component_order','component_label'});
assert(height(inventory)==195 && ...
    numel(unique(inventory.test_name))==195 && ...
    numel(unique(relativeFiles))==numel(relativeFiles), ...
    "stageA4:a43:tests:Regression195Identity", ...
    "The frozen existing regression must contain exactly 195 unique tests.");
end

function validate_authoritative_inventory(root,label,names,sources)
switch label
    case "stage_A4_2D_1R"
        file = "stage_A4_2D_1_expected_test_inventory.csv";
    case "stage_A4_2C"
        file = "stage_A4_2C_expected_test_inventory.csv";
    case "stage_A4_2B"
        file = "stage_A4_2B_expected_test_inventory.csv";
    case "stage_A4_1"
        file = "stage_A4_1_expected_test_inventory.csv";
    case "stage_A3"
        file = "stage_A3_expected_test_inventory.csv";
    otherwise
        file = "";
end
if strlength(file)==0
    return
end
pathValue = fullfile(root,"tests",file);
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
expected = readtable(pathValue,options);
assert(height(expected)==numel(names) && ...
    isequal(string(expected.test_name),names) && ...
    isequal(string(expected.source_file),sources), ...
    "stageA4:a43:tests:Regression195Authority", ...
    "The live %s inventory differs from its version-controlled contract.", ...
    label);
end
