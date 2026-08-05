function tests = test_stage_a3_index
%TEST_STAGE_A3_INDEX Audit the unified seven-day A3 model object.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a3_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a3_index(data,"RunId","A3_INDEX_MODEL_TEST");
state = rkkt.model.initialize_stage_a3_state(data,index,config);
linearization = rkkt.model.build_stage_a3_linearization(state,data,index,config);
testCase.TestData.projectRoot = projectRoot;
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.linearization = linearization;
end

function testConfigurationFreezesSevenFormalSerialDays(testCase)
config = testCase.TestData.config;
verifyEqual(testCase,config.days,14:20);
verifyEqual(testCase,config.aggregation_day_order,14:20);
verifyEqual(testCase,config.hours,1:24);
verifyEqual(testCase,config.time_scope_type,"formal_7_day_scope");
verifyEqual(testCase,config.soc_boundary_mode, ...
    "formal_daily_fixed_half_energy");
verifyEqual(testCase,config.expected_full_kkt_dimension,18836);
verifyEqual(testCase,config.expected_daily_hourly_chain_dimensions, ...
    [589,590,589,590,590,590,590]);
verifyEqual(testCase,config.expected_fixed_zero_count,422);
verifyEqual(testCase,config.parallel_mode,"off");
verifyEqual(testCase,config.day_response_side_effects,"none");
verifyFalse(testCase,config.run_full_ipm);
verifyFalse(testCase,config.optimization_executed);
verifyFalse(testCase,config.water_constraints_enabled);
verifyFalse(testCase,config.thermal_second_pass_enabled);
end

function testUnifiedIndexAndCanonicalMapDimensions(testCase)
index = testCase.TestData.index;
lin = testCase.TestData.linearization;
verifyEqual(testCase,index.counts.variables,3722);
verifyEqual(testCase,index.counts.equalities,618);
verifyEqual(testCase,index.counts.inequalities,7248);
verifyEqual(testCase,index.counts.full_kkt_dimension,18836);
verifyEqual(testCase,lin.counts.full_kkt,18836);
verifyEqual(testCase,numel(lin.maps.q_global),14);
verifySize(testCase,lin.maps.q_day,[14,7]);
verifySize(testCase,lin.maps.q_day_by_day,[1,7]);
verifySize(testCase,lin.maps.y_binding_by_day,[1,7]);
verifySize(testCase,lin.maps.x_by_day_hour,[7,24]);
verifySize(testCase,lin.maps.y_by_day_hour,[7,24]);
verifySize(testCase,lin.maps.ineq_by_day_hour,[7,24]);
verifyEqual(testCase,cellfun(@numel,lin.maps.q_day_by_day),14*ones(1,7));
verifyEqual(testCase,cellfun(@numel,lin.maps.y_binding_by_day),14*ones(1,7));
verifyEqual(testCase,numel(lin.maps.y_duration),2);
verifyEqual(testCase,numel(lin.maps.ineq_global),28);
verifyEqual(testCase,lin.maps.days,14:20);
verifyEqual(testCase,lin.layout.days,14:20);
verifyEqual(testCase,lin.layout.hours,1:24);
end

function testGlobalCapacityObjectiveAndBoundsExistOnce(testCase)
lin = testCase.TestData.linearization;
constraints = lin.index.constraint_index;
variables = lin.index.variable_index;
verifyEqual(testCase,height(variables(variables.day == 0 & ...
    variables.hour == 0,:)),14);
for day = 14:20
    verifyEqual(testCase,height(variables(variables.day == day & ...
        variables.hour == 0,:)),14);
end
globalBounds = constraints( ...
    string(constraints.constraint_type) == "inequality" & ...
    constraints.day == 0 & constraints.hour == 0,:);
dailyCopyBounds = constraints( ...
    string(constraints.constraint_type) == "inequality" & ...
    constraints.day > 0 & constraints.hour == 0,:);
verifyEqual(testCase,height(globalBounds),28);
verifyEmpty(testCase,dailyCopyBounds);
verifyEqual(testCase,lin.objective.gradient(lin.maps.q_global), ...
    lin.capacity_parameters.cost,"AbsTol",0);
verifyEqual(testCase,lin.objective.gradient(lin.maps.q_day), ...
    zeros(14,7),"AbsTol",0);
verifyEqual(testCase,nnz(lin.H),0);
end

function testEachDayHasIndependentSocChainAndTerminalClosure(testCase)
lin = testCase.TestData.linearization;
links = lin.index.soc_link_map;
variables = lin.index.variable_index;
equalities = equality_table(lin.index);
verifyEqual(testCase,height(links),7*24*2);
for day = 14:20
    first = links(links.day == day & links.hour == 1,:);
    verifyEqual(testCase,height(first),2);
    verifyTrue(testCase,all(isnan(first.predecessor_hour)));
    verifyEqual(testCase,first.predecessor_soc_global_index,zeros(2,1));
    verifyEqual(testCase,first.initial_energy_fraction,0.5*ones(2,1), ...
        "AbsTol",0);
    for hour = 2:24
        rows = links(links.day == day & links.hour == hour,:);
        verifyEqual(testCase,rows.predecessor_hour,(hour-1)*ones(2,1));
        predecessor = variables(rows.predecessor_soc_global_index,:);
        verifyEqual(testCase,predecessor.day,day*ones(2,1));
        verifyEqual(testCase,predecessor.hour,(hour-1)*ones(2,1));
    end
    terminal = equalities(equalities.day == day & ...
        string(equalities.constraint_name) == "terminal_soc",:);
    verifyEqual(testCase,height(terminal),2);
    verifyEqual(testCase,terminal.hour,24*ones(2,1));
end
end

function testNaturalDailyChainDimensionsComeFromActivity(testCase)
lin = testCase.TestData.linearization;
verifyEqual(testCase,lin.layout.daily_chain_dimensions, ...
    [589,590,589,590,590,590,590]);
verifyEqual(testCase,lin.layout.total_hourly_chain_dimension,4128);
verifyEqual(testCase,[lin.layout.day.hourly_chain_dimension], ...
    [589,590,589,590,590,590,590]);
for dayPosition = 1:7
    hours = lin.layout.day(dayPosition).hour;
    verifyEqual(testCase,numel(hours),24);
    verifyEqual(testCase,[hours.day_id], ...
        repmat(13+dayPosition,1,24));
    verifyEqual(testCase,[hours.physical_hour],1:24);
    verifyEqual(testCase,[hours.terminal_equality_count], ...
        [zeros(1,23),2]);
end
verifyEqual(testCase,lin.layout.day(1).hour(19).kkt_dimension,26);
verifyEqual(testCase,lin.layout.day(3).hour(5).kkt_dimension,21);
end

function testFixedZeroMapIsExactDeletedAndRecoverable(testCase)
lin = testCase.TestData.linearization;
data = testCase.TestData.data;
fixed = lin.fixed_zero_map;
verifyEqual(testCase,height(fixed),422);
verifyEqual(testCase,splitapply(@numel,fixed.day, ...
    findgroups(fixed.day)).',[61,60,61,60,60,60,60]);
verifyEqual(testCase,fixed.fixed_value,zeros(422,1),"AbsTol",0);
verifyEqual(testCase,fixed.fixed_direction_value,zeros(422,1),"AbsTol",0);
wind = fixed(string(fixed.asset_type) == "wind",:);
solar = fixed(string(fixed.asset_type) == "solar",:);
verifyEqual(testCase,height(solar),420);
verifyEqual(testCase,height(wind),2);
verifyEqual(testCase,[wind.day,wind.hour,wind.asset_id], ...
    [14,19,3;16,5,4]);

variables = lin.index.variable_index;
inequalities = lin.index.constraint_index( ...
    string(lin.index.constraint_index.constraint_type) == "inequality",:);
for rowNumber = 1:height(fixed)
    row = fixed(rowNumber,:);
    active = variables.day == row.day & variables.hour == row.hour & ...
        string(variables.asset_type) == string(row.asset_type) & ...
        variables.asset_id == row.asset_id;
    bounds = inequalities.day == row.day & ...
        inequalities.hour == row.hour & ...
        string(inequalities.asset_type) == string(row.asset_type) & ...
        inequalities.asset_id == row.asset_id;
    verifyFalse(testCase,any(active));
    verifyFalse(testCase,any(bounds));
end
physical = rkkt.model.recover_stage_a_physical_arrays( ...
    lin.state.xi,zeros(lin.counts.primal,1),lin.index,data);
verifyEqual(testCase,physical.fixed_zero_audit.count,422);
verifyEqual(testCase,physical.fixed_zero_audit.maximum_absolute_value,0, ...
    "AbsTol",0);
verifyEqual(testCase, ...
    physical.fixed_zero_audit.maximum_absolute_direction,0,"AbsTol",0);
end

function testSharedLinearizationIsSparseCanonicalAndDeterministic(testCase)
lin = testCase.TestData.linearization;
config = testCase.TestData.config;
data = testCase.TestData.data;
index = testCase.TestData.index;
verifyTrue(testCase,issparse(lin.H));
verifyTrue(testCase,issparse(lin.A));
verifyTrue(testCase,issparse(lin.G));
verifyEqual(testCase,lin.counts.primal,3722);
verifyEqual(testCase,lin.counts.equalities,618);
verifyEqual(testCase,lin.counts.inequalities,7248);
verifyEqual(testCase,lin.r_ineq,zeros(7248,1),"AbsTol",0);
verifyGreaterThan(testCase,min(lin.l),0);
verifyGreaterThan(testCase,min(lin.z),0);
verifyTrue(testCase,contains(lin.identity,"stageA3-linearization-v1.0"));
verifyTrue(testCase,contains(lin.identity,"day14-20|hours1-24"));
for hash = lower(string(data.hashes.actualSHA256)).'
    verifyTrue(testCase,contains(lin.identity,hash));
end
again = rkkt.model.build_stage_a3_linearization(lin.state,data,index,config);
verifyEqual(testCase,again.identity,lin.identity);
verifyEqual(testCase,again.A,lin.A,"AbsTol",0);
verifyEqual(testCase,again.G,lin.G,"AbsTol",0);
verifyEqual(testCase,again.r_dual,lin.r_dual,"AbsTol",0);
end

function testOnlyExactZeroAvailabilityIsRemoved(testCase)
data = testCase.TestData.data;
data.timeseries.solarAvailability(14,1,1) = eps;
index = rkkt.indexing.build_canonical_index_framework( ...
    data,14:20,1:24,[],"A3_EXACT_ZERO_TEST");
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
verifyEqual(testCase,index.counts.fixed_zero,421);
end

function equalities = equality_table(index)
equalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "equality",:);
end
