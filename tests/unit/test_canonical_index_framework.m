function tests = test_canonical_index_framework
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repoRoot,'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testRealDataFrameworkHasNoGapsOrOverlaps(testCase)
data = rkkt.data.load_project_data(testCase.TestData.repoRoot);
index = rkkt.indexing.build_canonical_index_framework(data,1,1:24,[],"UNIT_INDEX");
audit = rkkt.indexing.validate_canonical_index_framework(index);
verifyTrue(testCase,all(audit.passed),strjoin(audit.actual_value(audit.status=="FAIL"),"; "));
verifyEqual(testCase,index.counts.global_capacity_bounds,28);
verifyEqual(testCase,index.variable_index.global_index_start,(1:height(index.variable_index))');
verifyGreaterThan(testCase,height(index.fixed_zero_map),0);
verifyTrue(testCase,all(index.fixed_zero_map.fixed_value==0));
end

function testThermalMaskRemovesVariablesExactly(testCase)
data = rkkt.data.load_project_data(testCase.TestData.repoRoot);
mask = true(data.meta.nDays,data.meta.nHours,data.meta.nThermal);
mask(1,1,1) = false;
index = rkkt.indexing.build_canonical_index_framework(data,1,1,mask,"UNIT_MASK");
row = index.fixed_zero_map(index.fixed_zero_map.day==1 & ...
    index.fixed_zero_map.hour==1 & string(index.fixed_zero_map.asset_type)=="thermal" & ...
    index.fixed_zero_map.asset_id==1,:);
verifyEqual(testCase,height(row),1);
verifyEqual(testCase,string(row.reason),"thermal_pass2_mask");
active = index.variable_index(index.variable_index.day==1 & ...
    index.variable_index.hour==1 & string(index.variable_index.asset_type)=="thermal" & ...
    index.variable_index.asset_id==1,:);
verifyEmpty(testCase,active);
end
