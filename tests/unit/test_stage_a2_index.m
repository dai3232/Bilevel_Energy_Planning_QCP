function tests = test_stage_a2_index
%TEST_STAGE_A2_INDEX Audit the formal day-14 canonical activity structure.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
data = rkkt.data.load_project_data(projectRoot);
config = rkkt.model.load_stage_a2_configuration(projectRoot);
index = rkkt.indexing.build_stage_a2_index(data,"RunId","A2_INDEX_TEST");
testCase.TestData.projectRoot = projectRoot;
testCase.TestData.data = data;
testCase.TestData.config = config;
testCase.TestData.index = index;
end

function testFormalDayCountsAndNaturalBlockDimensions(testCase)
index = testCase.TestData.index;
config = testCase.TestData.config;
verifyEqual(testCase,index.counts.variables,543);
verifyEqual(testCase,index.counts.equalities,90);
verifyEqual(testCase,index.counts.inequalities,1058);
verifyEqual(testCase,index.counts.constraints,1148);
verifyEqual(testCase,index.counts.full_kkt_dimension,2749);
verifyEqual(testCase,index.counts.fixed_zero,61);

blocks = a2_hour_blocks(index);
verifyEqual(testCase,reshape(blocks.hour_start,1,[]),1:24);
verifyEqual(testCase,reshape(blocks.n_primal,1,[]), ...
    [repmat(19,1,7),repmat(24,1,11),23,repmat(19,1,5)]);
verifyEqual(testCase,reshape(blocks.n_equalities,1,[]), ...
    [repmat(3,1,23),5]);
verifyEqual(testCase,reshape(blocks.kkt_block_dimension,1,[]), ...
    config.expected_hourly_kkt_block_dimensions);
verifyEqual(testCase,sum(blocks.kkt_block_dimension),589);
verifyEqual(testCase,reshape(blocks.terminal_equality_count,1,[]), ...
    [zeros(1,23),2]);
verifyEqual(testCase,index.scope.stage_id,"stage_A2");
verifyEqual(testCase,index.scope.time_scope_type,"formal_24_hour_day");
verifyFalse(testCase,index.scope.is_explicit_window);
verifyNotEqual(testCase,index.scope.window_type, ...
    "synthetic_closed_test_window");
end

function testFixedZeroMapHasExactControlledComposition(testCase)
index = testCase.TestData.index;
fixed = index.fixed_zero_map;
verifyEqual(testCase,height(fixed),61);
verifyEqual(testCase,fixed.fixed_value,zeros(61,1),"AbsTol",0);
verifyEqual(testCase,fixed.fixed_direction_value,zeros(61,1),"AbsTol",0);
verifyEqual(testCase,string(fixed.reason), ...
    repmat("zero_availability",61,1));
verifyEqual(testCase,string(fixed.inequality_status), ...
    repmat("NOT_APPLICABLE_BOTH_BOUNDS",61,1));

solar = fixed(string(fixed.asset_type) == "solar",:);
wind = fixed(string(fixed.asset_type) == "wind",:);
verifyEqual(testCase,height(solar),60);
verifyEqual(testCase,height(wind),1);
verifyEqual(testCase,[wind.day,wind.hour,wind.asset_id],[14,19,3]);
verifyEqual(testCase,string(wind.variable_name),"PW");
verifyTrue(testCase,contains(string(wind.physical_array_index), ...
    "PW(14,3,19)"));
for asset = 1:5
    rows = solar(solar.asset_id == asset,:);
    verifyEqual(testCase,reshape(sort(rows.hour),1,[]),[1:7,20:24]);
    verifyEqual(testCase,string(rows.variable_name),repmat("PP",12,1));
end
end

function testFixedZerosDeleteVariableAndBothBounds(testCase)
index = testCase.TestData.index;
for rowNumber = 1:height(index.fixed_zero_map)
    fixed = index.fixed_zero_map(rowNumber,:);
    active = index.variable_index.day == fixed.day & ...
        index.variable_index.hour == fixed.hour & ...
        string(index.variable_index.asset_type) == string(fixed.asset_type) & ...
        index.variable_index.asset_id == fixed.asset_id & ...
        string(index.variable_index.variable_name) == ...
            string(fixed.variable_name);
    bounds = index.constraint_index.day == fixed.day & ...
        index.constraint_index.hour == fixed.hour & ...
        string(index.constraint_index.constraint_type) == "inequality" & ...
        string(index.constraint_index.asset_type) == string(fixed.asset_type) & ...
        index.constraint_index.asset_id == fixed.asset_id;
    verifyFalse(testCase,any(active));
    verifyFalse(testCase,any(bounds));
end
end

function testFormalSocLinksDoNotCrossDaysAndCloseOnlyAtHour24(testCase)
index = testCase.TestData.index;
links = index.soc_link_map;
first = links(links.hour == 1,:);
verifyEqual(testCase,height(first),2);
verifyTrue(testCase,all(isnan(first.predecessor_hour)));
verifyEqual(testCase,first.predecessor_soc_global_index,zeros(2,1));
verifyEqual(testCase,string(first.boundary_source), ...
    repmat("formal_daily_fixed_half_energy",2,1));
verifyEqual(testCase,first.initial_energy_fraction,0.5*ones(2,1), ...
    "AbsTol",0);

for hour = 2:24
    rows = links(links.hour == hour,:);
    verifyEqual(testCase,rows.predecessor_hour,(hour-1)*ones(2,1));
    verifyTrue(testCase,all(rows.predecessor_soc_global_index > 0));
    verifyEqual(testCase,string(rows.boundary_source), ...
        repmat("previous_physical_hour",2,1));
end
verifyFalse(testCase,any(links.terminal_equality(links.hour < 24)));
verifyTrue(testCase,all(links.terminal_equality(links.hour == 24)));
verifyEqual(testCase,links.terminal_energy_fraction(links.hour == 24), ...
    0.5*ones(2,1),"AbsTol",0);

terminal = index.constraint_index( ...
    string(index.constraint_index.constraint_name) == "terminal_soc",:);
verifyEqual(testCase,height(terminal),2);
verifyEqual(testCase,terminal.hour,24*ones(2,1));
verifyEqual(testCase,terminal.asset_id,[1;2]);
verifyEqual(testCase,terminal.local_row,[4;5]);
verifyFalse(testCase,any(contains(string(terminal.constraint_id),"WINDOW")));
verifyFalse(testCase,any(index.variable_index.hour == 0 & ...
    string(index.variable_index.variable_name) == "SOC"));
end

function testOnlyExactZeroAvailabilityIsRemoved(testCase)
data = testCase.TestData.data;
data.timeseries.solarAvailability(14,1,1) = eps;
index = rkkt.indexing.build_canonical_index_framework(data,14,1:24,[], ...
    "A2_EXACT_ZERO_TEST");
active = index.variable_index.day == 14 & ...
    index.variable_index.hour == 1 & ...
    string(index.variable_index.asset_type) == "solar" & ...
    index.variable_index.asset_id == 1;
fixed = index.fixed_zero_map.day == 14 & ...
    index.fixed_zero_map.hour == 1 & ...
    string(index.fixed_zero_map.asset_type) == "solar" & ...
    index.fixed_zero_map.asset_id == 1;
verifyEqual(testCase,nnz(active),1);
verifyEqual(testCase,nnz(fixed),0);
verifyEqual(testCase,index.counts.fixed_zero,60);
end

function testFixedZeroPhysicalRecoveryIsExactAndNonvacuous(testCase)
index = testCase.TestData.index;
data = testCase.TestData.data;
xi = zeros(height(index.variable_index),1);
deltaXi = zeros(height(index.variable_index),1);
physical = rkkt.model.recover_stage_a_physical_arrays(xi,deltaXi,index,data);
verifyEqual(testCase,physical.fixed_zero_audit.count,61);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_value,0, ...
    "AbsTol",0);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_direction,0, ...
    "AbsTol",0);
verifyTrue(testCase,physical.fixed_zero_audit.values_exact_zero);
verifyTrue(testCase,physical.fixed_zero_audit.directions_exact_zero);
verifyEqual(testCase,physical.value.wind(1,19,3),0,"AbsTol",0);
verifyEqual(testCase,physical.direction.wind(1,19,3),0,"AbsTol",0);
verifyEqual(testCase,physical.value.solar(1,1:7,:),zeros(1,7,5), ...
    "AbsTol",0);
verifyEqual(testCase,physical.direction.solar(1,20:24,:),zeros(1,5,5), ...
    "AbsTol",0);
end

function blocks = a2_hour_blocks(index)
blocks = index.block_index(index.block_index.day == 14 & ...
    ismember(index.block_index.hour_start,1:24),:);
[~,order] = sort(blocks.hour_start);
blocks = blocks(order,:);
end
