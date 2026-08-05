function tests = test_stage_a3_linearization
%TEST_STAGE_A3_LINEARIZATION Audit the single shared seven-day object.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a3_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a3_index(data,"RunId","A3_LINEARIZATION_TEST");
state = rkkt.model.initialize_stage_a3_state(data,index,config);
lin = rkkt.model.build_stage_a3_linearization(state,data,index,config);
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.lin = lin;
end

function testCanonicalMatricesAndResidualsHaveExactDimensions(testCase)
lin = testCase.TestData.lin;
verifySize(testCase,lin.H,[3722 3722]);
verifySize(testCase,lin.A,[618 3722]);
verifySize(testCase,lin.G,[7248 3722]);
verifyTrue(testCase,issparse(lin.H));
verifyTrue(testCase,issparse(lin.A));
verifyTrue(testCase,issparse(lin.G));
verifyEqual(testCase,numel(lin.r_dual),3722);
verifyEqual(testCase,numel(lin.r_eq),618);
verifyEqual(testCase,numel(lin.r_ineq),7248);
verifyEqual(testCase,numel(lin.r_comp),7248);
verifyEqual(testCase,lin.counts.full_kkt,18836);
verifyEqual(testCase,lin.r_ineq,zeros(7248,1),"AbsTol",0);
verifyGreaterThan(testCase,min(lin.l),0);
verifyGreaterThan(testCase,min(lin.z),0);
end

function testInvestmentObjectiveAndCapacityBoundsAreGlobalOnly(testCase)
lin = testCase.TestData.lin;
constraints = lin.index.constraint_index;
verifyEqual(testCase,lin.objective.gradient(lin.maps.q_global), ...
    lin.capacity_parameters.cost,"AbsTol",0);
verifyEqual(testCase,lin.objective.gradient(lin.maps.q_day), ...
    zeros(14,7),"AbsTol",0);
verifyEqual(testCase,nnz(lin.H),0);
globalBounds = constraints( ...
    string(constraints.constraint_type)=="inequality" & ...
    constraints.day==0 & constraints.hour==0,:);
dailyCapacityBounds = constraints( ...
    string(constraints.constraint_type)=="inequality" & ...
    constraints.day>0 & constraints.hour==0,:);
verifyEqual(testCase,height(globalBounds),28);
verifyEmpty(testCase,dailyCapacityBounds);
end

function testDailyBindingsHaveExactQDayMinusQSigns(testCase)
lin = testCase.TestData.lin;
for d = 1:7
    rows = lin.maps.y_binding_by_day{d};
    q = lin.maps.q_global;
    qd = lin.maps.q_day_by_day{d};
    verifyEqual(testCase,lin.A(rows,q),-speye(14),"AbsTol",0);
    verifyEqual(testCase,lin.A(rows,qd),speye(14),"AbsTol",0);
    other = setdiff((1:lin.counts.primal).',[q;qd],"stable");
    verifyEqual(testCase,nnz(lin.A(rows,other)),0);
end
end

function testEveryDayStartsFromHalfEnergyWithoutPriorDay(testCase)
lin = testCase.TestData.lin;
equalities = equality_table(lin.index);
for d = 1:7
    day = lin.layout.days(d);
    for storage = 1:2
        row = find(equalities.day==day & equalities.hour==1 & ...
            string(equalities.constraint_name)=="soc_dynamics" & ...
            equalities.asset_id==storage);
        qEnergy = lin.maps.q_day_by_day{d}(12+storage);
        verifyEqual(testCase,numel(row),1);
        coefficient = lin.A(row,qEnergy);
        verifyEqual(testCase,nnz(coefficient),1);
        verifyEqual(testCase,nonzeros(coefficient),-0.5,"AbsTol",0);
        link = lin.index.soc_link_map( ...
            lin.index.soc_link_map.day==day & ...
            lin.index.soc_link_map.hour==1 & ...
            lin.index.soc_link_map.storage_id==storage,:);
        verifyEqual(testCase,height(link),1);
        verifyTrue(testCase,isnan(link.predecessor_hour));
        verifyEqual(testCase,link.predecessor_soc_global_index,0);
    end
end
end

function testSocLinksStayInsideEachDayAndCloseOnlyAtHour24(testCase)
lin = testCase.TestData.lin;
variables = lin.index.variable_index;
equalities = equality_table(lin.index);
for day = 14:20
    for hour = 2:24
        links = lin.index.soc_link_map( ...
            lin.index.soc_link_map.day==day & ...
            lin.index.soc_link_map.hour==hour,:);
        verifyEqual(testCase,height(links),2);
        predecessor = variables(links.predecessor_soc_global_index,:);
        verifyEqual(testCase,predecessor.day,day*ones(2,1));
        verifyEqual(testCase,predecessor.hour,(hour-1)*ones(2,1));
    end
    terminal = equalities(equalities.day==day & ...
        string(equalities.constraint_name)=="terminal_soc",:);
    verifyEqual(testCase,height(terminal),2);
    verifyEqual(testCase,terminal.hour,24*ones(2,1));
end
verifyEqual(testCase,height(equalities( ...
    string(equalities.constraint_name)=="terminal_soc",:)),14);
end

function testRebuildingConsumesTheSameCanonicalOrdering(testCase)
lin = testCase.TestData.lin;
again = rkkt.model.build_stage_a3_linearization( ...
    lin.state,testCase.TestData.data,testCase.TestData.index, ...
    testCase.TestData.config);
verifyEqual(testCase,again.identity,lin.identity);
verifyEqual(testCase,again.index_version,lin.index_version);
verifyEqual(testCase,again.maps.direction,lin.maps.direction);
verifyEqual(testCase,again.A,lin.A,"AbsTol",0);
verifyEqual(testCase,again.G,lin.G,"AbsTol",0);
verifyEqual(testCase,again.r_dual,lin.r_dual,"AbsTol",0);
verifyEqual(testCase,again.r_eq,lin.r_eq,"AbsTol",0);
end

function equalities = equality_table(index)
equalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type)=="equality",:);
end
