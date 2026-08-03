function tests = test_stage_b2a_stage_a_regression
%TEST_STAGE_B2A_STAGE_A_REGRESSION Read-only Stage-A prefix regression.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
c = load_stage_b2a_configuration(root);
d = load_project_data(root);
idx = build_stage_b_index(d,c,"RunId","B2A_STAGE_A_REGRESSION");
base = build_canonical_index_framework(d,14:20,1:24,[], ...
    "B2A_STAGE_A_REGRESSION");
testCase.TestData.root = root;
testCase.TestData.data = d;
testCase.TestData.config = c;
testCase.TestData.index = idx;
testCase.TestData.base = base;
end

function testFrozenCountsRemainA4Values(testCase)
b = testCase.TestData.base;
verifyEqual(testCase,[b.counts.variables,b.counts.equalities, ...
    b.counts.inequalities,b.counts.full_kkt_dimension,b.counts.fixed_zero], ...
    [3722,618,7248,18836,422]);
end

function testFrozenVariablePrefixIsExact(testCase)
verifyEqual(testCase,testCase.TestData.index.variable_index, ...
    testCase.TestData.base.variable_index);
end

function testFrozenEqualitySocAndBlockMapsAreExact(testCase)
idx = testCase.TestData.index;
b = testCase.TestData.base;
verifyEqual(testCase,idx.block_index,b.block_index);
verifyEqual(testCase,idx.soc_link_map,b.soc_link_map);
verifyEqual(testCase,idx.constraint_index(1:height(b.constraint_index),:), ...
    b.constraint_index);
end

function testFrozenFixedZeroMapIsExact(testCase)
verifyEqual(testCase,testCase.TestData.index.fixed_zero_map, ...
    testCase.TestData.base.fixed_zero_map);
verifyEqual(testCase,height(testCase.TestData.index.fixed_zero_map),422);
end

function testFrozenBuildIsDeterministicAndNoStageASolverIsCalled(testCase)
root = testCase.TestData.root;
c = testCase.TestData.config;
d = testCase.TestData.data;
one = build_stage_b_index(d,c,"RunId","B2A_STAGE_A_REGRESSION");
two = build_stage_b_index(d,c,"RunId","B2A_STAGE_A_REGRESSION");
verifyEqual(testCase,one.variable_index,two.variable_index);
verifyEqual(testCase,one.constraint_index,two.constraint_index);
current = string(fileread(fullfile(root,"CURRENT_STAGE.md")));
token = regexp(current, ...
    "(?m)^\s*-\s*`stage_id`\s*:\s*`([^`]+)`","tokens","once");
verifyEqual(testCase,string(token{1}),"stage_B");
verifyFalse(testCase,c.full_kkt_solve_enabled);
verifyFalse(testCase,c.recursive_direction_enabled);
end
