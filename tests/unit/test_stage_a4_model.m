function tests = test_stage_a4_model
%TEST_STAGE_A4_MODEL Audit the A4 identity, state, and explicit-slack model.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a4_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a4_index(data,"RunId","A4_MODEL_TEST");
state = initialize_stage_a4_state(data,index,config);
linearization = build_stage_a4_linearization(state,data,index,config);
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.state = state;
testCase.TestData.linearization = linearization;
end

function testConfigurationFreezesA41ScopeAndExistingSolverContract(testCase)
config = testCase.TestData.config;
verifyEqual(testCase,config.stage_id,"stage_A4");
verifyEqual(testCase,config.status,"READY");
verifyEqual(testCase,config.current_stage.stage_id,"stage_A4");
verifyEqual(testCase,config.current_stage.status,"READY");
verifyEqual(testCase,config.days,14:20);
verifyEqual(testCase,config.hours,1:24);
verifyEqual(testCase,config.expected_full_kkt_dimension,18836);
verifyTrue(testCase,config.full_ipm_allowed);
verifyEqual(testCase,config.a4_1_iteration_count,1);
verifyFalse(testCase,config.formal_a4_run);
verifyFalse(testCase,config.optimization_executed);
verifyEqual(testCase,config.objective_mode,"investment_cost_only");
verifyEqual(testCase,config.thermal_pass,"first");
verifyEqual(testCase,config.thermal_lower_bound_mode,"zero");
verifyFalse(testCase,config.water_constraints_enabled);
verifyFalse(testCase,config.thermal_second_pass_enabled);
verifyFalse(testCase,config.annual_multiobjective_enabled);
verifyEqual(testCase,config.parallel_mode,"off");
verifyEqual(testCase,config.initialization.centering_sigma,0.1,"AbsTol",0);
verifyEqual(testCase,config.fraction_to_boundary,0.9995,"AbsTol",0);
verifyEqual(testCase,config.tolerances.direction_relative_2norm,1e-10, ...
    "AbsTol",0);
verifyEqual(testCase,config.tolerances.direct_preferred,1e-12,"AbsTol",0);
verifyEqual(testCase,config.tolerances.direct_maximum,1e-10,"AbsTol",0);
verifyEqual(testCase,config.tolerances.symmetry_relative,1e-12,"AbsTol",0);
end

function testCanonicalIndexHasA4IdentityAndControlledDimensions(testCase)
index = testCase.TestData.index;
verifyEqual(testCase,string(index.scope.stage_id),"stage_A4");
verifyEqual(testCase,index.counts.variables,3722);
verifyEqual(testCase,index.counts.equalities,618);
verifyEqual(testCase,index.counts.inequalities,7248);
verifyEqual(testCase,index.counts.full_kkt_dimension,18836);
verifyEqual(testCase,index.counts.fixed_zero,422);
verifyEqual(testCase,index.expected.daily_hourly_chain_dimensions, ...
    [589,590,589,590,590,590,590]);
end

function testInitialStateIsFiniteStrictlyInteriorAndRevisionZero(testCase)
state = testCase.TestData.state;
verifySize(testCase,state.xi,[3722,1]);
verifySize(testCase,state.y,[618,1]);
verifySize(testCase,state.l,[7248,1]);
verifySize(testCase,state.z,[7248,1]);
verifyTrue(testCase,all(isfinite([state.xi;state.y;state.l;state.z])));
verifyGreaterThan(testCase,min(state.l),0);
verifyGreaterThan(testCase,min(state.z),0);
verifyEqual(testCase,state.iteration_index,0);
verifyEqual(testCase,state.state_revision,0);
verifyEqual(testCase,state.fixed_zero_values,zeros(422,1),"AbsTol",0);
verifyEqual(testCase,state.fixed_zero_directions,zeros(422,1),"AbsTol",0);
end

function testLinearizationUsesExactFrozenResidualDefinitions(testCase)
lin = testCase.TestData.linearization;
state = testCase.TestData.state;
verifyEqual(testCase,lin.r_eq,lin.A*state.xi+lin.constraints.eq_offset, ...
    "AbsTol",0);
verifyEqual(testCase,lin.r_ineq, ...
    lin.G*state.xi+lin.constraints.ineq_offset+state.l,"AbsTol",0);
verifyEqual(testCase,lin.r_dual,lin.objective.gradient+ ...
    lin.A.'*state.y+lin.G.'*state.z,"AbsTol",0);
verifyEqual(testCase,lin.complementarity_gap,mean(state.l.*state.z), ...
    "AbsTol",0);
verifyEqual(testCase,lin.raw_complementarity,state.l.'*state.z,"AbsTol",0);
verifyEqual(testCase,lin.mu,0.1*mean(state.l.*state.z),"AbsTol",0);
verifyEqual(testCase,lin.physical_inequality_violation, ...
    max([lin.G*state.xi+lin.constraints.ineq_offset;0]),"AbsTol",0);
verifyEqual(testCase,lin.slack_consistency.state_minus_implied, ...
    lin.r_ineq,"AbsTol",0);
verifyEqual(testCase,lin.slack_consistency.audit_error,zeros(7248,1), ...
    "AbsTol",0);
verifyTrue(testCase,lin.explicit_slack_consumed);
end

function testExplicitSlackIsConsumedWithoutBeingOverwritten(testCase)
state = testCase.TestData.state;
state.l = state.l + 0.125;
state.state_revision = 1;
lin = build_stage_a4_linearization(state,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.config);
verifyEqual(testCase,lin.l,state.l,"AbsTol",0);
verifyEqual(testCase,lin.state.l,state.l,"AbsTol",0);
verifyEqual(testCase,lin.r_ineq,0.125*ones(7248,1),"AbsTol",1e-13);
verifyEqual(testCase,lin.slack_consistency.state_minus_implied, ...
    lin.r_ineq,"AbsTol",0);
verifyNotEqual(testCase,lin.identity, ...
    testCase.TestData.linearization.identity);
verifyTrue(testCase,contains(lin.identity,"revision1"));
end

function testEveryDayHasIndependentHalfEnergyBoundaries(testCase)
index = testCase.TestData.index;
variables = index.variable_index;
lin = testCase.TestData.linearization;
for day = 14:20
    first = index.soc_link_map(index.soc_link_map.day == day & ...
        index.soc_link_map.hour == 1,:);
    verifyEqual(testCase,height(first),2);
    verifyTrue(testCase,all(isnan(first.predecessor_hour)));
    verifyEqual(testCase,first.predecessor_soc_global_index,zeros(2,1));
    verifyEqual(testCase,first.initial_energy_fraction,0.5*ones(2,1));
    for hour = 2:24
        links = index.soc_link_map(index.soc_link_map.day == day & ...
            index.soc_link_map.hour == hour,:);
        predecessor = variables(links.predecessor_soc_global_index,:);
        verifyEqual(testCase,predecessor.day,day*ones(2,1));
        verifyEqual(testCase,predecessor.hour,(hour-1)*ones(2,1));
    end
    terminal = index.soc_link_map(index.soc_link_map.day == day & ...
        index.soc_link_map.terminal_equality,:);
    verifyEqual(testCase,height(terminal),2);
    verifyEqual(testCase,terminal.hour,24*ones(2,1));
    verifyEqual(testCase,terminal.terminal_energy_fraction,0.5*ones(2,1));
    dayPosition = find(lin.maps.days == day,1);
    for storage = 1:2
        qEnergy = lin.maps.q_day(12+storage,dayPosition);
        socRows = variables.day == day & ...
            ismember(variables.hour,[1,24]) & ...
            string(variables.asset_type) == "storage" & ...
            variables.asset_id == storage & ...
            string(variables.variable_name) == "SOC";
        socIndices = variables.global_index_start(socRows);
        verifyEqual(testCase,numel(socIndices),2);
        verifyEqual(testCase,lin.state.xi(socIndices), ...
            0.5*lin.state.xi(qEnergy)*ones(2,1),"AbsTol",0);
    end
end
end

function testFixedZeroMapRemainsExactAndRemoved(testCase)
index = testCase.TestData.index;
fixed = index.fixed_zero_map;
verifyEqual(testCase,height(fixed),422);
verifyEqual(testCase,fixed.fixed_value,zeros(422,1),"AbsTol",0);
verifyEqual(testCase,fixed.fixed_direction_value,zeros(422,1),"AbsTol",0);
variables = index.variable_index;
inequalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "inequality",:);
for rowNumber = 1:height(fixed)
    row = fixed(rowNumber,:);
    active = variables.day == row.day & variables.hour == row.hour & ...
        string(variables.asset_type) == string(row.asset_type) & ...
        variables.asset_id == row.asset_id;
    bounds = inequalities.day == row.day & inequalities.hour == row.hour & ...
        string(inequalities.asset_type) == string(row.asset_type) & ...
        inequalities.asset_id == row.asset_id;
    verifyFalse(testCase,any(active));
    verifyFalse(testCase,any(bounds));
end
end

function testA4RejectsMissingOrNonpositiveExplicitSlack(testCase)
state = testCase.TestData.state;
state.l = state.l(1:end-1);
verifyError(testCase,@() build_stage_a4_linearization(state, ...
    testCase.TestData.data,testCase.TestData.index, ...
    testCase.TestData.config),"stageA4:linearization:ExplicitSlack");
state = testCase.TestData.state;
state.l(10) = 0;
verifyError(testCase,@() build_stage_a4_linearization(state, ...
    testCase.TestData.data,testCase.TestData.index, ...
    testCase.TestData.config),"stageA4:linearization:ExplicitSlack");
end
