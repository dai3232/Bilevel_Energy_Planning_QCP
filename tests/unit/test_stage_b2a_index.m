function tests = test_stage_b2a_index
%TEST_STAGE_B2A_INDEX Fixed canonical daily-water index tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
testCase.TestData.root = root;
testCase.TestData.config = rkkt.model.load_stage_b2a_configuration(root);
testCase.TestData.data = rkkt.data.load_project_data(root);
testCase.TestData.index = rkkt.indexing.build_stage_b_index( ...
    testCase.TestData.data,testCase.TestData.config,"RunId","B2A_INDEX_TEST");
end

function testStageBConfigurationIsAssembleOnly(testCase)
c = testCase.TestData.config;
verifyEqual(testCase,string(c.stage_id),"stage_B");
verifyEqual(testCase,string(c.milestone_id),"B-2A");
verifyEqual(testCase,string(c.current_stage.status),"READY");
verifyTrue(testCase,c.water_constraints_enabled);
verifyTrue(testCase,c.full_kkt_assemble_only);
verifyFalse(testCase,c.full_kkt_solve_enabled);
verifyFalse(testCase,c.recursive_direction_enabled);
verifyFalse(testCase,c.ipm_enabled);
verifyEqual(testCase,string(c.parallel_mode),"off");
end

function testExactlyFiftySixWaterRowsAndDerivedDimension(testCase)
idx = testCase.TestData.index;
verifyEqual(testCase,idx.counts.variables,3722);
verifyEqual(testCase,idx.counts.equalities,618);
verifyEqual(testCase,idx.counts.inequalities,7304);
verifyEqual(testCase,idx.counts.water_inequalities,56);
verifyEqual(testCase,idx.counts.full_kkt_dimension,18948);
verifyEqual(testCase,height(idx.water_constraint_index),56);
end

function testStableDayHydroUpperLowerOrdering(testCase)
w = testCase.TestData.index.water_constraint_index;
verifyEqual(testCase,w.row_position,(1:56).');
verifyEqual(testCase,w.day,repelem((14:20).',8,1));
verifyEqual(testCase,w.hydro_id,repmat(repelem((1:4).',2,1),7,1));
verifyEqual(testCase,w.bound_type,repmat(["upper";"lower"],28,1));
verifyEqual(testCase,numel(unique(w.constraint_id)),56);
verifyEqual(testCase,numel(unique(w.global_row)),56);
verifyEqual(testCase,w.inequality_position,(7249:7304).');
verifyEqual(testCase,w.global_row,(7867:7922).');
end

function testEachWaterRowTouchesOnlyTwentyFourLocalHydroHours(testCase)
idx = testCase.TestData.index;
v = idx.variable_index;
w = idx.water_constraint_index;
for k = 1:height(w)
    touched = str2double(split(string(w.touched_variable_indices(k)),"|"));
    target = v.day==w.day(k) & v.hour>0 & ...
        string(v.asset_type)=="hydro" & v.asset_id==w.hydro_id(k) & ...
        string(v.variable_name)=="PH";
    expected = sort(v.global_index_start(target));
    verifyEqual(testCase,sort(touched),expected);
    verifyEqual(testCase,w.touched_hour_count(k),24);
    verifyEqual(testCase,w.touched_variable_count(k),24);
    verifyEqual(testCase,w.touched_variable_names(k),"PH");
end
end

function testStageAPrefixFixedZeroAndSocMapsAreUnchanged(testCase)
root = testCase.TestData.root;
d = testCase.TestData.data;
idx = testCase.TestData.index;
base = rkkt.indexing.build_canonical_index_framework(d,14:20,1:24,[] ,"B2A_INDEX_TEST");
verifyEqual(testCase,idx.variable_index,base.variable_index);
verifyEqual(testCase,idx.block_index,base.block_index);
verifyEqual(testCase,idx.fixed_zero_map,base.fixed_zero_map);
verifyEqual(testCase,idx.soc_link_map,base.soc_link_map);
prefix = idx.constraint_index(1:height(base.constraint_index),:);
verifyEqual(testCase,prefix,base.constraint_index);
verifyEqual(testCase,height(idx.fixed_zero_map),422);
verifyEqual(testCase,root,string(testCase.TestData.root));
end

function testExtendedInequalityPermutationIsBijection(testCase)
p = testCase.TestData.index.permutation_map;
rows = p(string(p.space_name)=="inequality",:);
verifyEqual(testCase,height(rows),7304);
verifyEqual(testCase,rows.canonical_index,(1:7304).');
verifyEqual(testCase,sort(rows.solver_index),(1:7304).');
verifyEqual(testCase,string(rows.object_name(end-55)), ...
    "INEQ-WATER-D014-HYDRO01-UPPER");
verifyEqual(testCase,string(rows.object_name(end)), ...
    "INEQ-WATER-D020-HYDRO04-LOWER");
end
