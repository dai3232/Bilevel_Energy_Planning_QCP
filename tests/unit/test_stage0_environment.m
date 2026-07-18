function tests = test_stage0_environment
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repoRoot,'src')));
end

function testMatlabSparseAndParallelAreAvailable(testCase)
environment = inspect_stage0_environment();
status = string(environment.status);
verifyEqual(testCase,status,repmat("PASS",height(environment),1), ...
    strjoin(string(environment.details(status~="PASS")),"; "));
verifyTrue(testCase,any(string(environment.check_id)=="SPARSE_MLDIVIDE"));
verifyTrue(testCase,any(string(environment.check_id)=="SPARSE_LDL"));
verifyTrue(testCase,any(string(environment.check_id)=="PCT_WORKER"));
end
