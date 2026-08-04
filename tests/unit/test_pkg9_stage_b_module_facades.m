function tests = test_pkg9_stage_b_module_facades
%TEST_PKG9_STAGE_B_MODULE_FACADES Compare thin facades with legacy calls.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
data = rkkt.data.load(root);

power = linspace(25,250,24).';
waterA = data.base.hydro.waterA(1);
waterB = data.base.hydro.waterB(1);
waterC = data.base.hydro.waterC(1);
waterPublic = rkkt.data.evaluateStageBDailyHydroWater( ...
    power,waterA,waterB,waterC);
waterLegacy = evaluate_stage_b_daily_hydro_water( ...
    power,waterA,waterB,waterC);

config2A = load_stage_b2a_configuration(root);
index2APublic = rkkt.indexing.buildStageB2A( ...
    data,config2A,RunId="PKG9_B2A_EQUIVALENCE");
index2ALegacy = build_stage_b_index( ...
    data,config2A,RunId="PKG9_B2A_EQUIVALENCE");
state2APublic = rkkt.model.initializeStageB2A( ...
    data,index2APublic,config2A);
state2ALegacy = initialize_stage_b2a_state( ...
    data,index2ALegacy,config2A);
lin2APublic = rkkt.model.linearizeStageB2A( ...
    state2APublic,data,index2APublic,config2A);
lin2ALegacy = build_stage_b_multiday_linearization( ...
    state2ALegacy,data,index2ALegacy,config2A);
kkt2APublic = rkkt.solver.assembleStageB2AFullKKT( ...
    lin2APublic,config2A);
kkt2ALegacy = assemble_stage_b_multiday_full_kkt( ...
    lin2ALegacy,config2A);

config2B = load_stage_b2b_configuration(root);
index2BPublic = rkkt.indexing.buildStageB2B( ...
    data,config2B,RunId="PKG9_B2B_EQUIVALENCE");
index2BLegacy = build_stage_b2b_index( ...
    data,config2B,RunId="PKG9_B2B_EQUIVALENCE");
state2BPublic = rkkt.model.initializeStageB2B( ...
    data,index2BPublic,config2B);
state2BLegacy = initialize_stage_b2b_state( ...
    data,index2BLegacy,config2B);
lin2BPublic = rkkt.model.linearizeStageB2B( ...
    state2BPublic,data,index2BPublic,config2B);
lin2BLegacy = build_stage_b2b_multiday_linearization( ...
    state2BLegacy,data,index2BLegacy,config2B);

testCase.TestData.root = root;
testCase.TestData.equal = struct( ...
    "water",isequaln(waterPublic,waterLegacy), ...
    "index2A",isequaln(index2APublic,index2ALegacy), ...
    "state2A",isequaln(state2APublic,state2ALegacy), ...
    "linearization2A",isequaln(lin2APublic,lin2ALegacy), ...
    "assembly2A",isequaln(kkt2APublic,kkt2ALegacy), ...
    "index2B",isequaln(index2BPublic,index2BLegacy), ...
    "state2B",isequaln(state2BPublic,state2BLegacy), ...
    "linearization2B",isequaln(lin2BPublic,lin2BLegacy));
testCase.TestData.dimensions = struct( ...
    "waterHessian",size(waterPublic.hessian), ...
    "waterHessianNnz",nnz(waterPublic.hessian), ...
    "waterRows",height(index2APublic.water_constraint_index), ...
    "b2aFullKkt",kkt2APublic.dimension, ...
    "b2bFullKkt",lin2BPublic.counts.full_kkt, ...
    "fixedZero",height(index2BPublic.fixed_zero_map));
end

function testDailyWaterValueGradientHessianFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.water);
verifyEqual(testCase,testCase.TestData.dimensions.waterHessian,[24,24]);
verifyEqual(testCase,testCase.TestData.dimensions.waterHessianNnz,24);
end

function testB2AIndexFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.index2A);
verifyEqual(testCase,testCase.TestData.dimensions.waterRows,56);
end

function testB2AStateFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.state2A);
end

function testB2ALinearizationFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.linearization2A);
end

function testB2AFullKktAssemblyFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.assembly2A);
verifyEqual(testCase,testCase.TestData.dimensions.b2aFullKkt,18948);
end

function testB2BIndexFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.index2B);
verifyEqual(testCase,testCase.TestData.dimensions.fixedZero,422);
end

function testB2BStateFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.state2B);
end

function testB2BLinearizationFacadeIsExact(testCase)
verifyTrue(testCase,testCase.TestData.equal.linearization2B);
verifyEqual(testCase,testCase.TestData.dimensions.b2bFullKkt,18948);
end

function testB2BSolverFacadesAreSingleDirectDelegates(testCase)
directory = fullfile(testCase.TestData.root,"src","+rkkt","+solver");
contracts = [ ...
    "solveStageB2BRecursiveDirection","solve_stage_b2b_recursive_direction"; ...
    "solveStageB2BFullKKTDirection","solve_stage_b2b_full_kkt_direction"; ...
    "verifyStageB2BDirectionEquivalence", ...
        "verify_stage_b2b_direction_equivalence"];
for k = 1:size(contracts,1)
    source = noncomment_source(fileread(fullfile( ...
        directory,contracts(k,1)+".m")));
    verifyTrue(testCase,contains(source,"which("));
    verifyTrue(testCase,contains(source,"ProductionFunctionShadowed"));
    pattern = "(^|[^A-Za-z0-9_])"+contracts(k,2)+"\s*\(";
    verifyEqual(testCase,numel(regexp(source,pattern)),1);
    verifyEmpty(testCase,regexp(source, ...
        '(^|[^A-Za-z0-9_])(inv|pinv|full)\s*\(',"once"));
end
end

function value = noncomment_source(inputValue)
lines = splitlines(string(inputValue));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end
