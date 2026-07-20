function tests = test_stage_a2_linearization
%TEST_STAGE_A2_LINEARIZATION Audit the shared model on the formal A2 day.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = load_stage_a2_configuration(projectRoot);
data = load_project_data(projectRoot);
index = build_stage_a2_index(data,"RunId","A2_LINEARIZATION_TEST");
state = initialize_stage_a2_state(data,index,config);
linearization = build_stage_a2_linearization(state,data,index,config);
testCase.TestData.projectRoot = projectRoot;
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.linearization = linearization;
end

function testCanonicalDimensionsSparseContractAndIdentity(testCase)
lin = testCase.TestData.linearization;
config = testCase.TestData.config;
verifyEqual(testCase,lin.counts.primal,543);
verifyEqual(testCase,lin.counts.equalities,90);
verifyEqual(testCase,lin.counts.inequalities,1058);
verifyEqual(testCase,lin.counts.full_kkt,2749);
verifyEqual(testCase,[lin.layout.hour.kkt_dimension], ...
    config.expected_hourly_kkt_block_dimensions);
verifyEqual(testCase,sum([lin.layout.hour.kkt_dimension]),589);
verifyTrue(testCase,issparse(lin.H));
verifyTrue(testCase,issparse(lin.A));
verifyTrue(testCase,issparse(lin.G));
verifyEqual(testCase,nnz(lin.H),0);
verifyEqual(testCase,lin.stage_id,"stage_A2");
verifyEqual(testCase,lin.layout.time_scope_type,"formal_24_hour_day");
verifyFalse(testCase,contains(lin.identity,"synthetic"));
verifyTrue(testCase,contains(lin.identity,"day14|hours1-24"));
end

function testHourOneUsesFormalHalfEnergyWithoutPreviousDay(testCase)
lin = testCase.TestData.linearization;
data = testCase.TestData.data;
eq = equality_table(lin.index);
variables = lin.index.variable_index;
for storage = 1:2
    row = find(eq.hour == 1 & ...
        string(eq.constraint_name) == "soc_dynamics" & ...
        eq.asset_id == storage);
    currentSoc = variable_index(variables,1,"storage",storage,"SOC");
    pch = variable_index(variables,1,"storage",storage,"Pch");
    pdis = variable_index(variables,1,"storage",storage,"Pdis");
    verifyEqual(testCase,numel(row),1);
    verifyEqual(testCase,full(lin.A(row,currentSoc)),1,"AbsTol",0);
    verifyEqual(testCase,full(lin.A(row,pch)), ...
        -data.base.storage.chargeEfficiency(storage)*data.meta.dtHours, ...
        "AbsTol",0);
    verifyEqual(testCase,full(lin.A(row,pdis)), ...
        data.meta.dtHours/data.base.storage.dischargeEfficiency(storage), ...
        "AbsTol",0);
    verifyEqual(testCase,full(lin.A(row,lin.maps.q_day(12+storage))), ...
        -0.5,"AbsTol",0);
end
verifyFalse(testCase,any(variables.day == 13));
verifyFalse(testCase,any(variables.day == 14 & variables.hour == 0 & ...
    string(variables.variable_name) == "SOC"));
end

function testHoursTwoThroughTwentyFourUseAdjacentSocOnly(testCase)
lin = testCase.TestData.linearization;
eq = equality_table(lin.index);
variables = lin.index.variable_index;
for hour = 2:24
    for storage = 1:2
        row = find(eq.hour == hour & ...
            string(eq.constraint_name) == "soc_dynamics" & ...
            eq.asset_id == storage);
        predecessor = variable_index( ...
            variables,hour-1,"storage",storage,"SOC");
        verifyEqual(testCase,full(lin.A(row,predecessor)),-1,"AbsTol",0);
        older = variables.global_index_start(variables.day == 14 & ...
            variables.hour < hour-1 & ...
            string(variables.asset_type) == "storage" & ...
            variables.asset_id == storage & ...
            string(variables.variable_name) == "SOC");
        if ~isempty(older)
            verifyEqual(testCase,nnz(lin.A(row,older)),0);
        end
    end
end
end

function testHourTwentyFourHasExactlyTwoFormalTerminalRows(testCase)
lin = testCase.TestData.linearization;
eq = equality_table(lin.index);
variables = lin.index.variable_index;
terminal = find(string(eq.constraint_name) == "terminal_soc");
verifyEqual(testCase,numel(terminal),2);
verifyEqual(testCase,eq.hour(terminal),24*ones(2,1));
verifyFalse(testCase,any(eq.hour(terminal) == 10));
for storage = 1:2
    row = find(eq.hour == 24 & ...
        string(eq.constraint_name) == "terminal_soc" & ...
        eq.asset_id == storage);
    soc = variable_index(variables,24,"storage",storage,"SOC");
    verifyEqual(testCase,full(lin.A(row,soc)),1,"AbsTol",0);
    verifyEqual(testCase,full(lin.A(row,lin.maps.q_day(12+storage))), ...
        -0.5,"AbsTol",0);
end
verifyEqual(testCase,lin.layout.hour(24).terminal_equality_count,2);
verifyEqual(testCase,lin.layout.hour(24).kkt_dimension,24);
end

function testPowerBalanceAndFixedZeroBoundDeletion(testCase)
lin = testCase.TestData.linearization;
eq = equality_table(lin.index);
variables = lin.index.variable_index;
balance = find(eq.hour == 19 & ...
    string(eq.constraint_name) == "hourly_power_balance");
pch = variable_index(variables,19,"storage",1,"Pch");
pdis = variable_index(variables,19,"storage",1,"Pdis");
verifyEqual(testCase,full(lin.A(balance,pch)),-1,"AbsTol",0);
verifyEqual(testCase,full(lin.A(balance,pdis)),1,"AbsTol",0);

fixed = lin.fixed_zero_map;
verifyEqual(testCase,height(fixed),61);
for rowNumber = 1:height(fixed)
    row = fixed(rowNumber,:);
    active = variables.day == row.day & variables.hour == row.hour & ...
        string(variables.asset_type) == string(row.asset_type) & ...
        variables.asset_id == row.asset_id & ...
        string(variables.variable_name) == string(row.variable_name);
    verifyFalse(testCase,any(active));
    ineq = lin.index.constraint_index( ...
        string(lin.index.constraint_index.constraint_type) == "inequality",:);
    bounds = ineq.day == row.day & ineq.hour == row.hour & ...
        string(ineq.asset_type) == string(row.asset_type) & ...
        ineq.asset_id == row.asset_id;
    verifyFalse(testCase,any(bounds));
end
end

function testStrictInteriorAndResidualIdentity(testCase)
lin = testCase.TestData.linearization;
verifyGreaterThan(testCase,min(lin.l),0);
verifyGreaterThan(testCase,min(lin.z),0);
verifyGreaterThan(testCase,lin.mu,0);
verifyEqual(testCase,lin.r_ineq,zeros(1058,1),"AbsTol",0);
verifyEqual(testCase,lin.r_dual, ...
    lin.objective.gradient + lin.A.'*lin.state.y + lin.G.'*lin.z, ...
    "AbsTol",0);
verifyEqual(testCase,lin.r_eq,lin.A*lin.state.xi + ...
    lin.constraints.eq_offset,"AbsTol",0);
end

function testSharedBuilderIsDeterministicAndA2WrapperIsThin(testCase)
config = testCase.TestData.config;
data = testCase.TestData.data;
index = testCase.TestData.index;
state = initialize_stage_a_state(data,index,config);
shared = build_stage_a_linearization(state,data,index,config);
wrapped = build_stage_a2_linearization(state,data,index,config);
verifyEqual(testCase,shared.identity,wrapped.identity);
verifyEqual(testCase,shared.A,wrapped.A,"AbsTol",0);
verifyEqual(testCase,shared.G,wrapped.G,"AbsTol",0);
verifyEqual(testCase,shared.r_dual,wrapped.r_dual,"AbsTol",0);
for k = 1:height(data.hashes)
    verifyTrue(testCase,contains(shared.identity, ...
        lower(string(data.hashes.actualSHA256(k)))));
end
end

function testExecutionRestrictionsAreFrozen(testCase)
config = testCase.TestData.config;
verifyEqual(testCase,config.newton_direction_count,1);
verifyFalse(testCase,config.run_full_ipm);
verifyFalse(testCase,config.optimization_executed);
verifyEqual(testCase,config.parallel_mode,"off");
verifyFalse(testCase,config.physical_dispatch_interpretation);
verifyFalse(testCase,config.capacity_planning_interpretation);
verifyFalse(testCase,config.economic_interpretation);
verifyFalse(testCase,config.linear_algebra.automatic_regularization);
verifyFalse(testCase,config.linear_algebra.automatic_symmetrization);
verifyFalse(testCase,config.linear_algebra.recursive_fallback_to_full_kkt);
verifyEqual(testCase,config.tolerances.direction_relative_2norm,1e-10);
verifyEqual(testCase, ...
    config.tolerances.recursive_full_kkt_relative_residual,1e-10);
end

function eq = equality_table(index)
eq = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "equality",:);
end

function value = variable_index(variables,hour,assetType,assetId,name)
mask = variables.day == 14 & variables.hour == hour & ...
    string(variables.asset_type) == string(assetType) & ...
    variables.asset_id == assetId & ...
    string(variables.variable_name) == string(name);
assert(nnz(mask) == 1);
value = variables.global_index_start(mask);
end
