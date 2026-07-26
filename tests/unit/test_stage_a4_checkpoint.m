function tests = test_stage_a4_checkpoint
%TEST_STAGE_A4_CHECKPOINT Fast, solver-free A4 checkpoint tests.
tests = functiontests(localfunctions);
end

function setup(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(projectRoot,"src")));

temporaryRoot = string(tempname);
runRoot = fullfile(temporaryRoot,"runs","A4_CHECKPOINT_TEST");
checkpointRoot = fullfile(runRoot,"checkpoints");
mkdir(checkpointRoot);
iterationRoot = fullfile(runRoot,"iterations");
mkdir(fullfile(iterationRoot,"revisions"));
for directory = ["indices","matrices","acceptance","issues","reports"]
    mkdir(fullfile(runRoot,directory));
end
configPath = fullfile(runRoot,"effective_config.yaml");
write_text(configPath, ...
    "stage_id: ""stage_A4"""+newline+ ...
    "run_purpose: ""a4_3_checkpoint_test"""+newline);

context = struct( ...
    "project_root",temporaryRoot, ...
    "root",runRoot, ...
    "run_dir",runRoot, ...
    "run_id","A4_CHECKPOINT_TEST", ...
    "stage_id","stage_A4", ...
    "iterations_dir",iterationRoot, ...
    "indices_dir",fullfile(runRoot,"indices"), ...
    "matrices_dir",fullfile(runRoot,"matrices"), ...
    "acceptance_dir",fullfile(runRoot,"acceptance"), ...
    "issues_dir",fullfile(runRoot,"issues"), ...
    "reports_dir",fullfile(runRoot,"reports"), ...
    "checkpoints_dir",checkpointRoot, ...
    "checkpoint_manifest_path", ...
        fullfile(checkpointRoot,"checkpoint_manifest.csv"), ...
    "run_manifest_path",fullfile(runRoot,"run_manifest.json"), ...
    "effective_config_path",configPath);
inputHashes = struct( ...
    "base_parameters",repmat('a',1,64), ...
    "timeseries",repmat('b',1,64));
runManifest = struct( ...
    "run_id",context.run_id, ...
    "stage_id","stage_A4", ...
    "status","RUNNING", ...
    "run_purpose","seven_day_full_primal_dual_ipm_convergence_candidate", ...
    "maximum_iterations",100, ...
    "parallel_executed",false, ...
    "optimization_executed",false, ...
    "full_ipm_executed",false, ...
    "git_commit",repmat('c',1,40), ...
    "input_hashes",inputHashes);
write_json_file(context.run_manifest_path,runManifest);

state0 = make_state(0);
testCase.TestData.temporary_root = temporaryRoot;
testCase.TestData.context = context;
testCase.TestData.input_hashes = inputHashes;
testCase.TestData.config_sha256 = ...
    compute_sha256_file(string(configPath));
testCase.TestData.git_commit = string(runManifest.git_commit);
testCase.TestData.initial_state_fingerprint = state_fingerprint(state0);
end

function teardown(testCase)
root = testCase.TestData.temporary_root;
if isfolder(root)
    rmdir(root,"s");
end
end

function testRoundTripAtomicHashChainAndLatestLoad(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
metadata0 = make_metadata(testCase,state0,0);
record0 = write_stage_a4_checkpoint(context,state0,metadata0);
verifyEqual(testCase,height(record0),1);
verifyTrue(testCase,isfile(fullfile(context.checkpoints_dir, ...
    "stage_A4_checkpoint_000.mat")));
verifyTrue(testCase,isfile(context.checkpoint_manifest_path));

state1 = make_state(1);
metadata1 = make_metadata(testCase,state1,1);
record1 = write_stage_a4_checkpoint(context,state1,metadata1);
verifyEqual(testCase,string(record1.previous_checkpoint_sha256), ...
    string(record0.sha256));

[checkpoint,selected,audit] = load_stage_a4_checkpoint(context, ...
    "ExpectedMetadata",stable_expected(testCase), ...
    "RebuiltLinearizationFingerprint", ...
        metadata1.linearization_fingerprint);
verifyTrue(testCase,audit.passed);
verifyEqual(testCase,audit.revision_count,2);
verifyEqual(testCase,audit.latest_revision,1);
verifyEqual(testCase,audit.selected_revision,1);
verifyEqual(testCase,audit.orphan_file_count,0);
verifyEqual(testCase,double(selected.iteration),1);
verifyEqual(testCase,checkpoint.state,state1);
verifyEqual(testCase,string(checkpoint.metadata.state_fingerprint), ...
    state_fingerprint(state1));

failure = struct("present",true,"iteration",2, ...
    "identifier","stageA4:test:InjectedNumericalFailure", ...
    "message","deterministic injected diagnostic failure", ...
    "state_revision",1,"evidence_path", ...
    "checkpoints/numerical_failure_inv001_iter002_rev001_test.mat", ...
    "state_fingerprint",state_fingerprint(state1), ...
    "report","test-only failure report");
failurePath = fullfile(context.root, ...
    strrep(failure.evidence_path,"/",filesep));
save_mat_artifact(failurePath,"state_before_failure",state1, ...
    "failure",failure);
failureSha = compute_sha256_file(string(failurePath));
failureLedger = table(1,string(context.run_id),1,2,1, ...
    "NUMERICAL_FAILURE",string(failure.identifier), ...
    string(failure.message),string(failure.state_fingerprint), ...
    string(failure.evidence_path),string(failureSha), ...
    "2026-07-26T00:00:00.000Z", ...
    'VariableNames',{'failure_sequence','run_id','solver_invocation', ...
    'iteration','state_revision','terminal_state','identifier','message', ...
    'state_fingerprint','relative_path','sha256','recorded_at_utc'});
write_table_csv_17g(context.checkpoints_dir+ ...
    filesep+"failure_ledger.csv",failureLedger);
failureAudit = validate_stage_a4_checkpoint(context);
verifyTrue(testCase,failureAudit.failure_ledger_audit.passed);
verifyEqual(testCase,failureAudit.failure_ledger_audit.failure_count,1);
failureLedger.sha256(1) = string(repmat('0',1,64));
write_table_csv_17g(context.checkpoints_dir+ ...
    filesep+"failure_ledger.csv",failureLedger);
verifyError(testCase,@()validate_stage_a4_checkpoint(context), ...
    "stageA4:checkpoint:FailureEvidenceHashMismatch");
end

function testNoncontiguousRevisionAndWrongStateFingerprintRejected(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
write_stage_a4_checkpoint(context,state0, ...
    make_metadata(testCase,state0,0));

state2 = make_state(2);
metadata2 = make_metadata(testCase,state2,2);
verifyError(testCase,@()write_stage_a4_checkpoint( ...
    context,state2,metadata2), ...
    "stageA4:checkpoint:NoncontiguousRevision");

state1 = make_state(1);
metadata1 = make_metadata(testCase,state1,1);
metadata1.state_fingerprint = repmat('f',1,64);
verifyError(testCase,@()write_stage_a4_checkpoint( ...
    context,state1,metadata1), ...
    "stageA4:checkpoint:StateFingerprintMismatch");
end

function testExpectedAndRebuiltLinearizationIdentityMismatchRejected(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
metadata0 = make_metadata(testCase,state0,0);
write_stage_a4_checkpoint(context,state0,metadata0);

expected = stable_expected(testCase);
expected.config_sha256 = repmat('0',1,64);
verifyError(testCase,@()validate_stage_a4_checkpoint( ...
    context,"ExpectedMetadata",expected), ...
    "stageA4:checkpoint:ExpectedIdentityMismatch");
expected = stable_expected(testCase);
expected.git_commit = repmat('0',1,40);
verifyError(testCase,@()validate_stage_a4_checkpoint( ...
    context,"ExpectedMetadata",expected), ...
    "stageA4:checkpoint:ExpectedIdentityMismatch");
expected = stable_expected(testCase);
expected.input_hashes.timeseries = repmat('f',1,64);
verifyError(testCase,@()validate_stage_a4_checkpoint( ...
    context,"ExpectedMetadata",expected), ...
    "stageA4:checkpoint:ExpectedIdentityMismatch");
verifyError(testCase,@()validate_stage_a4_checkpoint( ...
    context,"RebuiltLinearizationFingerprint",repmat('0',1,64)), ...
    "stageA4:checkpoint:RebuiltLinearizationMismatch");
end

function testManifestHashTamperDetected(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
write_stage_a4_checkpoint(context,state0, ...
    make_metadata(testCase,state0,0));
manifest = readtable(context.checkpoint_manifest_path, ...
    TextType="string",VariableNamingRule="preserve");
manifest.sha256(1) = string(repmat('0',1,64));
write_table_csv_17g(context.checkpoint_manifest_path,manifest);
verifyError(testCase,@()validate_stage_a4_checkpoint(context), ...
    "stageA4:checkpoint:FileHashMismatch");
end

function testMatchingOrphanIsAdoptedWithoutOverwrite(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
metadata0 = make_metadata(testCase,state0,0);
first = write_stage_a4_checkpoint(context,state0,metadata0);
checkpointPath = fullfile(context.checkpoints_dir, ...
    "stage_A4_checkpoint_000.mat");
firstSha = compute_sha256_file(string(checkpointPath));
delete(context.checkpoint_manifest_path);

adopted = write_stage_a4_checkpoint(context,state0,metadata0);
secondSha = compute_sha256_file(string(checkpointPath));
verifyEqual(testCase,secondSha,firstSha);
verifyEqual(testCase,string(adopted.sha256),string(first.sha256));
audit = validate_stage_a4_checkpoint(context);
verifyEqual(testCase,audit.revision_count,1);
verifyEqual(testCase,audit.orphan_file_count,0);
end

function testWriterRejectsTerminalRun(testCase)
context = testCase.TestData.context;
manifest = jsondecode(fileread(context.run_manifest_path));
manifest.status = "PASS";
write_json_file(context.run_manifest_path,manifest);
state0 = make_state(0);
verifyError(testCase,@()write_stage_a4_checkpoint( ...
    context,state0,make_metadata(testCase,state0,0)), ...
    "stageA4:checkpoint:RunNotRunning");
end

function testStableV2AndEffectiveConfigIdentityAreMandatory(testCase)
context = testCase.TestData.context;
state0 = make_state(0);
metadata0 = make_metadata(testCase,state0,0);
metadata0.recursive_refinement_max_passes = 0;
verifyError(testCase,@()write_stage_a4_checkpoint( ...
    context,state0,metadata0), ...
    "stageA4:checkpoint:StableV2Passes");

metadata0 = make_metadata(testCase,state0,0);
write_text(context.effective_config_path, ...
    "stage_id: ""stage_A4"""+newline+ ...
    "run_purpose: ""tampered_after_identity_capture"""+newline);
verifyError(testCase,@()write_stage_a4_checkpoint( ...
    context,state0,metadata0), ...
    "stageA4:checkpoint:EffectiveConfigMismatch");
end

function testOrphanCheckpointAndSnapshotAreQuarantinedTogether(testCase)
context = testCase.TestData.context;
snapshot = fullfile(context.iterations_dir,"revisions","revision_001");
mkdir(snapshot);
write_text(fullfile(snapshot,"partial.txt"),"preserved");
checkpointPath = fullfile(context.checkpoints_dir, ...
    "stage_A4_checkpoint_001.mat");
checkpoint = struct("partial",true);
save(checkpointPath,"checkpoint");

audit = reconcile_stage_a4_uncommitted_transactions(context,0);
verifyTrue(testCase,audit.passed);
verifyEqual(testCase,audit.orphan_count,2);
verifyEqual(testCase,sort(audit.artifact_types), ...
    sort(["revision_snapshot";"checkpoint_mat"]));
verifyEqual(testCase,unique(audit.orphan_revisions),1);
verifyFalse(testCase,isfolder(snapshot));
verifyFalse(testCase,isfile(checkpointPath));
verifyTrue(testCase,all(isfile(audit.quarantine_paths) | ...
    isfolder(audit.quarantine_paths)));
end

function testPostprocessRecoveryRecreatesMissingAndMovedDirectories(testCase)
context = testCase.TestData.context;
write_text(fullfile(context.indices_dir,"partial.csv"),"a,b"+newline);
resultsRoot = fullfile(context.root,"results");
verifyFalse(testCase,isfolder(resultsRoot));

audit = prepare_stage_a4_postprocess_resume(context);
verifyTrue(testCase,audit.passed);
verifyTrue(testCase,isfolder(context.indices_dir));
verifyTrue(testCase,isfolder(resultsRoot));
verifyFalse(testCase,isfile(fullfile(context.indices_dir,"partial.csv")));
verifyTrue(testCase,all(isfolder(audit.required_directories)));
verifyGreaterThanOrEqual(testCase,numel(audit.moved_targets),1);
verifyTrue(testCase,all(isfile(audit.moved_targets) | ...
    isfolder(audit.moved_targets)));
end

function testFullIpmExecutionMarkerIsOneWayAndCountsResume(testCase)
context = testCase.TestData.context;
first = mark_stage_a4_full_ipm_execution(context);
verifyTrue(testCase,logical(first.optimization_executed));
verifyTrue(testCase,logical(first.full_ipm_executed));
verifyTrue(testCase,logical(first.solver_invocation_started));
verifyEqual(testCase,double(first.solver_invocation_count),1);

second = mark_stage_a4_full_ipm_execution(context);
verifyTrue(testCase,logical(second.optimization_executed));
verifyTrue(testCase,logical(second.full_ipm_executed));
verifyEqual(testCase,double(second.solver_invocation_count),2);
end

function state = make_state(revision)
state = struct();
state.xi = [1;2;3]+revision/10;
state.y = [-1;2]+revision/20;
state.l = [4;5;6]+revision/30;
state.z = [7;8;9]+revision/40;
state.stage_id = "stage_A4";
state.iteration_index = double(revision);
state.state_revision = double(revision);
state.newton_direction_number = double(revision);
state.completed_newton_direction_count = double(revision);
state.initialization_version = "stageA4-checkpoint-test";
end

function metadata = make_metadata(testCase,state,revision)
hexDigits = "0123456789abcdef";
linearizationCharacter = extractBetween( ...
    hexDigits,mod(revision+12,16)+1,mod(revision+12,16)+1);
metadata = struct( ...
    "iteration",double(revision), ...
    "state_revision",double(revision), ...
    "input_hashes",testCase.TestData.input_hashes, ...
    "config_sha256",testCase.TestData.config_sha256, ...
    "git_commit",testCase.TestData.git_commit, ...
    "linearization_fingerprint", ...
        repmat(char(linearizationCharacter),1,64), ...
    "state_fingerprint",state_fingerprint(state), ...
    "iteration_csv_sha256",repmat('e',1,64), ...
    "direction_csv_sha256",repmat('d',1,64), ...
    "refinement_csv_sha256",repmat('f',1,64), ...
    "initial_state_fingerprint", ...
        testCase.TestData.initial_state_fingerprint, ...
    "recursive_refinement_max_passes",3, ...
    "solve_pass","first", ...
    "model_contract_version","v1.0", ...
    "index_contract_version","stage_A4_test_index_v1", ...
    "solver_version","stable-v2-maxpasses-3");
end

function expected = stable_expected(testCase)
expected = struct( ...
    "input_hashes",testCase.TestData.input_hashes, ...
    "config_sha256",testCase.TestData.config_sha256, ...
    "git_commit",testCase.TestData.git_commit, ...
    "initial_state_fingerprint", ...
        testCase.TestData.initial_state_fingerprint, ...
    "recursive_refinement_max_passes",3, ...
    "solve_pass","first", ...
    "model_contract_version","v1.0", ...
    "index_contract_version","stage_A4_test_index_v1", ...
    "solver_version","stable-v2-maxpasses-3");
end

function digest = state_fingerprint(state)
names = ["xi","y","l","z"];
payload = zeros(0,1);
lengths = zeros(numel(names),1);
for k = 1:numel(names)
    value = state.(names(k));
    lengths(k) = numel(value);
    payload = [payload;value]; %#ok<AGROW>
end
counters = [state.iteration_index;state.state_revision; ...
    state.newton_direction_number; ...
    state.completed_newton_direction_count];
bytes = typecast([lengths;counters;payload],"uint8");
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
messageDigest.update(typecast(bytes,"int8"));
digestBytes = mod(double(messageDigest.digest()),256);
digest = lower(join(compose("%02x",digestBytes),""));
digest = reshape(digest,1,1);
end

function write_text(pathValue,textValue)
fileId = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0);
guard = onCleanup(@()close_if_open(fileId));
fwrite(fileId,unicode2native(char(textValue),"UTF-8"),"uint8");
status = fclose(fileId);
clear guard
assert(status==0);
end

function close_if_open(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end
