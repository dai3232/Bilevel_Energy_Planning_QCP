function components = stage_a4_3_regression_195_plan()
%STAGE_A4_3_REGRESSION_195_PLAN Frozen eight-component regression plan.

component_order = uint32((1:8).');
component_label = [ ...
    "stage_A4_2D_1R"
    "stage_A4_2C"
    "stage_A4_2B"
    "stage_A4_2A"
    "stage_A4_1"
    "stage_A3"
    "stage_A2"
    "stage_A1"];
runner = [ ...
    "run_stage_A4_2D_1_tests"
    "run_stage_A4_2C_tests"
    "run_stage_A4_2B_tests"
    "run_stage_A4_2A_tests"
    "run_stage_A4_1_tests"
    "run_stage_A3_tests"
    "run_stage_A2_tests"
    "run_stage_A1_tests"];
expected_count = [8;8;8;11;24;67;32;37];
components = table(component_order,component_label,runner, ...
    expected_count);
assert(height(components)==8 && ...
    sum(components.expected_count)==195 && ...
    isequal(components.expected_count,[8;8;8;11;24;67;32;37]), ...
    "stageA4:a43:tests:Regression195Plan", ...
    "The frozen existing regression must remain 8+8+8+11+24+67+32+37.");
end
