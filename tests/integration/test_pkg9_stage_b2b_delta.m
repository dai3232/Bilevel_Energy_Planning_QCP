function tests = test_pkg9_stage_b2b_delta
%TEST_PKG9_STAGE_B2B_DELTA Execute one recursive/full audit direction pair.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
artifactPaths = solver_artifact_paths(root);
beforeRuns = inventory(fullfile(root,"runs"));
beforeArtifacts = file_facts(artifactPaths);
result = rkkt.solver.validation.runStageB2B( ...
    ProjectRoot=root,Interactive=false,WriteArtifacts=false);
testCase.TestData.root = root;
testCase.TestData.result = result;
testCase.TestData.runsUnchanged = isequal(beforeRuns, ...
    inventory(fullfile(root,"runs")));
testCase.TestData.artifactsUnchanged = isequal(beforeArtifacts, ...
    file_facts(artifactPaths));
end

function testDailyBordersResponsesAndCoreHaveFrozenDimensions(testCase)
summary = testCase.TestData.result.intermediate.dailySummary;
verifyEqual(testCase,summary.day,(14:20).');
verifyEqual(testCase,summary.hourly_chain_dimension, ...
    [589;590;589;590;590;590;590]);
verifyEqual(testCase,summary.water_border_dimension,repmat(8,7,1));
verifyEqual(testCase,summary.daily_response_dimension,repmat(14,7,1));
verifyEqual(testCase,summary.global_core_dimension,repmat(16,7,1));
verifyEqual(testCase,summary.status,repmat("PASS",7,1));
end

function testOneDirectionPairSharesTheSameLinearizationIdentity(testCase)
result = testCase.TestData.result;
recursive = result.output.recursiveResult;
fullAudit = result.output.fullAuditResult;
audit = result.output.equivalenceAudit;
identity = string(result.input.linearization_identity);
verifyEqual(testCase,string(recursive.linearization_identity),identity);
verifyEqual(testCase,string(fullAudit.linearization_identity),identity);
verifyEqual(testCase,string(audit.linearization_identity),identity);
verifyEqual(testCase,fullAudit.kkt.dimension,18948);
verifyEqual(testCase,numel(recursive.direction),18948);
verifyEqual(testCase,numel(fullAudit.direction),18948);
end

function testDirectionAndKktResidualsMeetFrozenB2BThresholds(testCase)
result = testCase.TestData.result;
audit = result.output.equivalenceAudit;
verifyLessThanOrEqual(testCase,audit.direction_relative_error,1e-10);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase, ...
        audit.component_relative_errors.(name),1e-10);
end
verifyLessThanOrEqual(testCase, ...
    audit.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual,1e-10);
verifyTrue(testCase,audit.all_pass);
verifyTrue(testCase,all(result.intermediate.metricSummary.passed));
end

function testFixedZeroAndNoFallbackContractsRemainExact(testCase)
result = testCase.TestData.result;
recursive = result.output.recursiveResult;
fullAudit = result.output.fullAuditResult;
verifyEqual(testCase,recursive.fixed_zero.count,422);
verifyTrue(testCase,recursive.fixed_zero.all_exact_zero);
verifyEqual(testCase,recursive.fixed_zero.value,zeros(422,1));
verifyEqual(testCase,recursive.fixed_zero.direction,zeros(422,1));
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyFalse(testCase,recursive.full_direction_consumed);
verifyTrue(testCase,fullAudit.audit_only);
verifyFalse(testCase,fullAudit.recursive_direction_consumed);
verifyFalse(testCase,result.diagnostics.full_ipm_executed);
verifyFalse(testCase,result.diagnostics.optimization_executed);
verifyFalse(testCase,result.diagnostics.state_update_executed);
verifyFalse(testCase,result.diagnostics.parallel_executed);
end

function testValidationCallsEachDirectionFacadeOnceAndWritesNothing(testCase)
result = testCase.TestData.result;
source = noncomment_source(fileread(fullfile(testCase.TestData.root, ...
    "src","+rkkt","+solver","+validation","runStageB2B.m")));
functionNames = ["rkkt.solver.solveStageB2BRecursiveDirection"; ...
    "rkkt.solver.solveStageB2BFullKKTDirection"];
for functionName = functionNames.'
    pattern = "(?m)^\s*[A-Za-z][A-Za-z0-9_]*\s*=\s*"+ ...
        regexptranslate("escape",functionName)+"\s*\(";
    verifyEqual(testCase,numel(regexp(source,pattern)),1);
end
verifyFalse(testCase,contains(source,"main_stage_B_2B"));
verifyFalse(testCase,contains(source,"rkkt.ipm."));
verifyFalse(testCase,result.diagnostics.artifacts_written);
verifyEmpty(testCase,result.tableFiles);
verifyEmpty(testCase,result.figureFiles);
verifyTrue(testCase,testCase.TestData.runsUnchanged);
verifyTrue(testCase,testCase.TestData.artifactsUnchanged);
end

function value = solver_artifact_paths(root)
directory = fullfile(root,"src","+rkkt","+solver","+validation");
value = fullfile(directory,[ ...
    "Stage_B2B求解器验证输出.mat"; ...
    "Stage_B2B每日边框与响应维数.csv"; ...
    "Stage_B2B方向误差与KKT残差.csv"; ...
    "Stage_B2B_16维核心稀疏结构.fig"; ...
    "Stage_B2B_16维核心稀疏结构.png"]);
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
