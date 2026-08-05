function tests = test_stage_a1_index
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repoRoot,'src')));
data = rkkt.data.load_project_data(repoRoot);
testCase.TestData.repoRoot = repoRoot;
testCase.TestData.data = data;
testCase.TestData.windowSpec = valid_window_spec();
testCase.TestData.index = rkkt.indexing.build_stage_a1_index(data,RunId="UNIT_A1_INDEX");
end

function testExactA1CanonicalCountsAndBlockDimensions(testCase)
index = testCase.TestData.index;
verifyEqual(testCase,index.counts.variables,100);
verifyEqual(testCase,index.counts.equalities,27);
verifyEqual(testCase,index.counts.inequalities,172);
verifyEqual(testCase,index.counts.constraints,199);
verifyEqual(testCase,index.counts.full_kkt_dimension,471);
verifyEqual(testCase,index.counts.fixed_zero,0);

hourBlocks = a1_hour_blocks(index);
verifyEqual(testCase,reshape(hourBlocks.hour_start,1,[]),8:10);
verifyEqual(testCase,reshape(hourBlocks.n_primal,1,[]),[24,24,24]);
verifyEqual(testCase,reshape(hourBlocks.n_equalities,1,[]),[3,3,5]);
verifyEqual(testCase,reshape(hourBlocks.kkt_block_dimension,1,[]),[27,27,29]);
verifyEqual(testCase,reshape(hourBlocks.terminal_equality_count,1,[]),[0,0,2]);

verifyTrue(testCase,index.scope.is_explicit_window);
verifyEqual(testCase,index.scope.window_type,"synthetic_closed_test_window");
verifyEqual(testCase,index.scope.start_hour,8);
verifyEqual(testCase,index.scope.terminal_hour,10);
verifyEqual(testCase,index.scope.soc_boundary_mode,"fixed_half_energy");
verifyEqual(testCase,index.scope.terminal_soc_equality_count,2);
end

function testWindowSocLinkEvidenceDoesNotConnectHourSeven(testCase)
links = testCase.TestData.index.soc_link_map;
hour8 = links(links.hour == 8,:);
verifyEqual(testCase,height(hour8),2);
verifyTrue(testCase,all(isnan(hour8.predecessor_hour)));
verifyEqual(testCase,hour8.predecessor_soc_global_index,zeros(2,1));
verifyEqual(testCase,string(hour8.boundary_source), ...
    repmat("fixed_half_energy",2,1));
verifyEqual(testCase,hour8.initial_energy_fraction,0.5*ones(2,1), ...
    'AbsTol',0);
verifyTrue(testCase,all(hour8.current_soc_global_index > 0));
verifyTrue(testCase,all(hour8.energy_capacity_global_index > 0));

hour9 = links(links.hour == 9,:);
hour10 = links(links.hour == 10,:);
verifyEqual(testCase,hour9.predecessor_hour,8*ones(2,1));
verifyEqual(testCase,hour10.predecessor_hour,9*ones(2,1));
verifyTrue(testCase,all(hour9.predecessor_soc_global_index > 0));
verifyTrue(testCase,all(hour10.predecessor_soc_global_index > 0));
verifyEqual(testCase,string(hour9.boundary_source), ...
    repmat("previous_window_hour",2,1));
verifyEqual(testCase,string(hour10.boundary_source), ...
    repmat("previous_window_hour",2,1));
end

function testHourTenHasExactlyTwoSyntheticTerminalRows(testCase)
constraints = testCase.TestData.index.constraint_index;
terminal = constraints(string(constraints.constraint_name) == "terminal_soc",:);
verifyEqual(testCase,height(terminal),2);
verifyEqual(testCase,terminal.day,ones(2,1));
verifyEqual(testCase,terminal.hour,10*ones(2,1));
verifyEqual(testCase,terminal.asset_id,[1;2]);
verifyEqual(testCase,terminal.local_row,[4;5]);
verifyEqual(testCase,string(terminal.boundary_role), ...
    repmat("synthetic_window_terminal_fixed_half_energy",2,1));
verifyTrue(testCase,all(contains(string(terminal.constraint_id), ...
    "EQ-SOC-WINDOW-END-D001-H10")));

links = testCase.TestData.index.soc_link_map;
verifyFalse(testCase,any(links.terminal_equality(links.hour < 10)));
verifyTrue(testCase,all(links.terminal_equality(links.hour == 10)));
verifyEqual(testCase,links.terminal_energy_fraction(links.hour == 10), ...
    0.5*ones(2,1),'AbsTol',0);
end

function testDefaultFullDayBehaviorStillClosesOnlyAtHourTwentyFour(testCase)
index = rkkt.indexing.build_canonical_index_framework(testCase.TestData.data,1,1:24,[], ...
    "UNIT_DEFAULT_FULL_DAY");
verifyFalse(testCase,index.scope.is_explicit_window);
verifyEqual(testCase,index.scope.terminal_hour,24);
terminal = index.constraint_index( ...
    string(index.constraint_index.constraint_name) == "terminal_soc",:);
verifyEqual(testCase,height(terminal),2);
verifyEqual(testCase,terminal.hour,24*ones(2,1));
verifyFalse(testCase,any(contains(string(terminal.constraint_id),"WINDOW")));

hour24 = index.block_index(index.block_index.day == 1 & ...
    index.block_index.hour_start == 24,:);
verifyEqual(testCase,hour24.n_equalities,5);
verifyEqual(testCase,hour24.terminal_equality_count,2);
hour1Links = index.soc_link_map(index.soc_link_map.hour == 1,:);
verifyTrue(testCase,all(isnan(hour1Links.predecessor_hour)));
verifyEqual(testCase,string(hour1Links.boundary_source), ...
    repmat("formal_daily_fixed_half_energy",2,1));

audit = rkkt.indexing.validate_canonical_index_framework(index);
verifyTrue(testCase,all(audit.passed), ...
    strjoin(audit.actual_value(audit.status == "FAIL"),"; "));
end

function testInvalidExplicitWindowSpecsFailWithoutReordering(testCase)
data = testCase.TestData.data;
spec = testCase.TestData.windowSpec;

missing = rmfield(spec,'terminal_hour');
verifyError(testCase,@() rkkt.indexing.build_canonical_index_framework( ...
    data,1,8:10,[],"UNIT_MISSING",missing), ...
    "stage0:index:WindowSpecMissingField");

verifyError(testCase,@() rkkt.indexing.build_canonical_index_framework( ...
    data,1,[8,10,9],[],"UNIT_UNSORTED",spec), ...
    "stage0:index:WindowHoursOrder");

verifyError(testCase,@() rkkt.indexing.build_canonical_index_framework( ...
    data,1,[8,10],[],"UNIT_GAPPED",spec), ...
    "stage0:index:WindowHoursNotContiguous");

wrongBoundary = spec;
wrongBoundary.soc_boundary_mode = "previous_physical_hour";
verifyError(testCase,@() rkkt.indexing.build_canonical_index_framework( ...
    data,1,8:10,[],"UNIT_WRONG_BOUNDARY",wrongBoundary), ...
    "stage0:index:UnsupportedSocBoundaryMode");
end

function testSyntheticFixedZeroMappingDeletesVariableAndBothBounds(testCase)
data = testCase.TestData.data;
data.timeseries.windAvailability(1,8,1) = 0;
index = rkkt.indexing.build_canonical_index_framework(data,1,8:10,[], ...
    "UNIT_SYNTHETIC_FIXED_ZERO",testCase.TestData.windowSpec);

fixed = index.fixed_zero_map(index.fixed_zero_map.day == 1 & ...
    index.fixed_zero_map.hour == 8 & ...
    string(index.fixed_zero_map.asset_type) == "wind" & ...
    index.fixed_zero_map.asset_id == 1,:);
verifyEqual(testCase,height(fixed),1);
verifyEqual(testCase,fixed.fixed_value,0,'AbsTol',0);
verifyEqual(testCase,fixed.fixed_direction_value,0,'AbsTol',0);
verifyEqual(testCase,string(fixed.reason),"zero_availability");
verifyEqual(testCase,string(fixed.inequality_status), ...
    "NOT_APPLICABLE_BOTH_BOUNDS");

active = index.variable_index(index.variable_index.day == 1 & ...
    index.variable_index.hour == 8 & ...
    string(index.variable_index.asset_type) == "wind" & ...
    index.variable_index.asset_id == 1,:);
verifyEmpty(testCase,active);
windBounds = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "inequality" & ...
    index.constraint_index.day == 1 & index.constraint_index.hour == 8 & ...
    string(index.constraint_index.asset_type) == "wind" & ...
    index.constraint_index.asset_id == 1,:);
verifyEmpty(testCase,windBounds);
verifyEqual(testCase,index.counts.variables,99);
verifyEqual(testCase,index.counts.inequalities,170);
verifyEqual(testCase,index.counts.full_kkt_dimension,466);

hour8 = index.block_index(index.block_index.day == 1 & ...
    index.block_index.hour_start == 8,:);
verifyEqual(testCase,hour8.n_primal,23);
verifyEqual(testCase,hour8.kkt_block_dimension,26);
audit = rkkt.indexing.validate_canonical_index_framework(index);
verifyTrue(testCase,all(audit.passed), ...
    strjoin(audit.actual_value(audit.status == "FAIL"),"; "));

xi = zeros(height(index.variable_index),1);
deltaXi = zeros(height(index.variable_index),1);
physical = rkkt.model.recover_stage_a_physical_arrays(xi,deltaXi,index,data);
verifyEqual(testCase,physical.fixed_zero_audit.count,1);
verifyTrue(testCase,physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.directions_exact_zero);

corrupt = index;
corrupt.fixed_zero_map.fixed_direction_value(1) = 1;
verifyError(testCase,@() rkkt.model.recover_stage_a_physical_arrays( ...
    xi,deltaXi,corrupt,data),"stageA:recovery:FixedZeroMapNonzero");
end

function blocks = a1_hour_blocks(index)
blocks = index.block_index(index.block_index.day == 1 & ...
    ismember(index.block_index.hour_start,8:10),:);
[~,order] = sort(blocks.hour_start);
blocks = blocks(order,:);
end

function spec = valid_window_spec()
spec = struct( ...
    "window_type","synthetic_closed_test_window", ...
    "start_hour",8, ...
    "terminal_hour",10, ...
    "soc_boundary_mode","fixed_half_energy", ...
    "terminal_soc_equality_count",2);
end
