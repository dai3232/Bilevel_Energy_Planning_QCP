function tests = test_pkg9_validation_entries
%TEST_PKG9_VALIDATION_ENTRIES Run three lightweight entries without writes.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
trackedPaths = fixed_artifact_paths(root);
beforeRuns = inventory(fullfile(root,"runs"));
beforeArtifacts = file_facts(trackedPaths);

b1 = rkkt.data.validation.runStageB1( ...
    ProjectRoot=root,Interactive=false,WriteArtifacts=false);
b2aIndex = rkkt.indexing.validation.runStageB2A( ...
    ProjectRoot=root,Interactive=false,WriteArtifacts=false);
b2aModel = rkkt.model.validation.runStageB2A( ...
    ProjectRoot=root,Interactive=false,WriteArtifacts=false);

testCase.TestData.root = root;
testCase.TestData.b1 = b1;
testCase.TestData.b2aIndex = b2aIndex;
testCase.TestData.b2aModel = b2aModel;
testCase.TestData.runsUnchanged = isequal(beforeRuns, ...
    inventory(fullfile(root,"runs")));
testCase.TestData.artifactsUnchanged = isequal(beforeArtifacts, ...
    file_facts(trackedPaths));
end

function testStageB1ValidationReturnsDerivativeSummaryWithoutWrites(testCase)
result = testCase.TestData.b1;
verifyEqual(testCase,result.meta.stage_id,"stage_B");
verifyEqual(testCase,result.diagnostics.sample_count,28);
verifyTrue(testCase,result.diagnostics.all_values_finite);
verifyTrue(testCase,result.diagnostics.all_gradients_finite);
verifyTrue(testCase,result.diagnostics.all_hessians_sparse);
verifyTrue(testCase,result.diagnostics.all_hessians_diagonal);
verifyFalse(testCase,result.diagnostics.optimization_executed);
verifyFalse(testCase,result.diagnostics.state_update_executed);
verifyFalse(testCase,result.diagnostics.artifacts_written);
verifyEmpty(testCase,result.tableFiles);
verifyEmpty(testCase,result.figureFiles);
end

function testStageB2AIndexValidationReturnsFiftySixRowsWithoutWrites(testCase)
result = testCase.TestData.b2aIndex;
verifyEqual(testCase,result.meta.stage_id,"stage_B");
verifyEqual(testCase,result.diagnostics.water_constraint_count,56);
verifyEqual(testCase,result.diagnostics.stage_a_variable_count,3722);
verifyEqual(testCase,result.diagnostics.stage_a_equality_count,618);
verifyEqual(testCase,result.diagnostics.total_inequality_count,7304);
verifyEqual(testCase,result.diagnostics.full_kkt_dimension,18948);
verifyTrue(testCase,all(structfun(@logical, ...
    result.diagnostics.objective_facts)));
verifyFalse(testCase,result.diagnostics.optimization_executed);
verifyFalse(testCase,result.diagnostics.state_update_executed);
verifyFalse(testCase,result.diagnostics.artifacts_written);
end

function testStageB2AModelValidationReturnsSparseChainWithoutWrites(testCase)
result = testCase.TestData.b2aModel;
summary = result.output.dimensionSummary;
verifyEqual(testCase,result.meta.stage_id,"stage_B");
verifyTrue(testCase,all(structfun(@logical, ...
    result.diagnostics.objective_facts)));
verifyEqual(testCase,result.diagnostics.fixed_zero_count,422);
verifyGreaterThan(testCase,result.diagnostics.hessian_nonzeros,0);
verifyEqual(testCase,summary.rowCount(summary.objectName=="H"),3722);
verifyEqual(testCase,summary.rowCount(summary.objectName=="A"),618);
verifyEqual(testCase,summary.rowCount(summary.objectName=="G"),7304);
verifyFalse(testCase,result.diagnostics.full_ipm_executed);
verifyFalse(testCase,result.diagnostics.optimization_executed);
verifyFalse(testCase,result.diagnostics.state_update_executed);
verifyFalse(testCase,result.diagnostics.artifacts_written);
end

function testWriteArtifactsFalseLeavesRunsAndFixedFilesUnchanged(testCase)
verifyTrue(testCase,testCase.TestData.runsUnchanged);
verifyTrue(testCase,testCase.TestData.artifactsUnchanged);
end

function testThreeEntriesContainNoWorkflowIpmOrStateUpdateCall(testCase)
root = testCase.TestData.root;
paths = [ ...
    "src/+rkkt/+data/+validation/runStageB1.m"; ...
    "src/+rkkt/+indexing/+validation/runStageB2A.m"; ...
    "src/+rkkt/+model/+validation/runStageB2A.m"];
for relative = paths.'
    source = noncomment_source(fileread(fullfile( ...
        root,replace(relative,"/",filesep))));
    verifyFalse(testCase,contains(source,"main_stage_B_"));
    verifyFalse(testCase,contains(source,"rkkt.workflows."));
    verifyFalse(testCase,contains(source,"rkkt.ipm."));
    verifyEmpty(testCase,regexp(source, ...
        '(^|[^A-Za-z0-9_])update_primal_dual_state\s*\(',"once"));
end
end

function value = fixed_artifact_paths(root)
value = [ ...
    fullfile(root,"src","+rkkt","+data","+validation", ...
        "阶段B-1水量函数验证输出.mat"); ...
    fullfile(root,"src","+rkkt","+data","+validation", ...
        "阶段B-1水量值与导数摘要.csv"); ...
    fullfile(root,"src","+rkkt","+indexing","+validation", ...
        "阶段B-2A索引验证输出.mat"); ...
    fullfile(root,"src","+rkkt","+indexing","+validation", ...
        "阶段B-2A水量约束索引摘要.csv"); ...
    fullfile(root,"src","+rkkt","+model","+validation", ...
        "阶段B-2A模型验证输出.mat"); ...
    fullfile(root,"src","+rkkt","+model","+validation", ...
        "阶段B-2A线性化维数摘要.csv")];
end

function value = inventory(directory)
entries = dir(fullfile(directory,"**","*"));
entries = entries(~ismember({entries.name},{'.','..'}));
relative_path = strings(numel(entries),1);
is_directory = false(numel(entries),1);
bytes = zeros(numel(entries),1);
date_number = zeros(numel(entries),1);
prefix = replace(string(directory),"/","\")+"\";
for k = 1:numel(entries)
    pathValue = fullfile(string(entries(k).folder),string(entries(k).name));
    relative_path(k) = extractAfter(replace(pathValue,"/","\"), ...
        strlength(prefix));
    is_directory(k) = entries(k).isdir;
    bytes(k) = entries(k).bytes;
    date_number(k) = entries(k).datenum;
end
value = sortrows(table(relative_path,is_directory,bytes,date_number), ...
    "relative_path");
end

function value = file_facts(paths)
exists = false(numel(paths),1);
bytes = zeros(numel(paths),1);
date_number = zeros(numel(paths),1);
for k = 1:numel(paths)
    exists(k) = isfile(paths(k));
    if exists(k)
        item = dir(paths(k));
        bytes(k) = item.bytes;
        date_number(k) = item.datenum;
    end
end
value = table(paths,exists,bytes,date_number);
end

function value = noncomment_source(inputValue)
lines = splitlines(string(inputValue));
value = strjoin(lines(~startsWith(strip(lines),"%")),newline);
end
