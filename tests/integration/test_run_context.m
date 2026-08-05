function tests = test_run_context
%TEST_RUN_CONTEXT Integration coverage for stage_0 artifact infrastructure.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    integrationDirectory = fileparts(mfilename('fullpath'));
    repositoryRoot = fileparts(fileparts(integrationDirectory));
    artifactSource = fullfile(repositoryRoot, 'src', '+rkkt', '+artifacts');
    addpath(artifactSource);
    testCase.addTeardown(@() rmpath(artifactSource));
end

function testCreatesCompleteNonOverwritingRun(testCase)
    projectRoot = create_temporary_project(testCase);
    runId = '20260718_120000_stage_0_test0001';

    context = rkkt.artifacts.create_run_context(projectRoot, 'stage_0', 'RunId', runId);

    testCase.verifyEqual(context.run_id, runId);
    testCase.verifyEqual(context.stage_id, 'stage_0');
    testCase.verifyTrue(isfolder(context.root));
    expectedDirectories = {
        'iterations', 'indices', 'matrices', 'checkpoints', ...
        'issues', 'acceptance', 'reports'};
    for k = 1:numel(expectedDirectories)
        testCase.verifyTrue(isfolder(fullfile(context.root, expectedDirectories{k})));
    end

    expectedFiles = {
        'run_manifest.json'
        'environment.csv'
        'input_hashes.csv'
        'effective_config.yaml'
        'git_state.txt'
        fullfile('matrices', 'matrix_manifest.csv')
        fullfile('checkpoints', 'checkpoint_manifest.csv')
        fullfile('issues', 'issue_log.csv')
        fullfile('issues', 'decision_log.csv')
        fullfile('acceptance', 'acceptance_results.csv')
        };
    for k = 1:numel(expectedFiles)
        testCase.verifyTrue(isfile(fullfile(context.root, expectedFiles{k})));
    end

    manifest = jsondecode(fileread(context.run_manifest_path));
    testCase.verifyEqual(manifest.status, 'RUNNING');
    testCase.verifyEqual(manifest.run_id, runId);
    testCase.verifyEqual(manifest.stage_id, 'stage_0');
    testCase.verifyEqual(manifest.effective_config, 'effective_config.yaml');
    testCase.verifyTrue(contains(fileread(context.run_manifest_path), ...
        '"ended_at": null'));

    sentinelPath = fullfile(context.root, 'sentinel.txt');
    local_write_bytes(sentinelPath, uint8('preserve-me'));
    testCase.verifyError( ...
        @() rkkt.artifacts.create_run_context(projectRoot, 'stage_0', 'RunId', runId), ...
        'stage0:artifacts:RunExists');
    testCase.verifyEqual(char(local_read_bytes(sentinelPath)), 'preserve-me');

    autoContext1 = rkkt.artifacts.create_run_context(projectRoot, 'stage_0');
    autoContext2 = rkkt.artifacts.create_run_context(projectRoot, 'stage_0');
    testCase.verifyNotEqual(autoContext1.run_id, autoContext2.run_id);
    testCase.verifyTrue(isfolder(autoContext1.root));
    testCase.verifyTrue(isfolder(autoContext2.root));
end

function testManifestTerminalTransition(testCase)
    projectRoot = create_temporary_project(testCase);
    context = rkkt.artifacts.create_run_context(projectRoot, 'stage_0', ...
        'RunId', '20260718_120001_stage_0_test0002');
    updates = struct('input_hashes', struct('input_xlsx', 'abc123'), ...
        'acceptance_summary', struct('blocking_passed', true));

    manifest = rkkt.artifacts.finalize_run_manifest(context, 'PASS', updates);

    testCase.verifyEqual(manifest.status, 'PASS');
    testCase.verifyNotEmpty(manifest.ended_at);
    persisted = jsondecode(fileread(context.run_manifest_path));
    testCase.verifyEqual(persisted.status, 'PASS');
    testCase.verifyEqual(persisted.input_hashes.input_xlsx, 'abc123');
    testCase.verifyError(@() rkkt.artifacts.finalize_run_manifest(context, 'PASS'), ...
        'stage0:artifacts:ManifestAlreadyFinal');
    testCase.verifyError(@() rkkt.artifacts.finalize_run_manifest(context, 'RUNNING'), ...
        'stage0:artifacts:InvalidFinalStatus');
end

function testCsvWriterUsesStableRfc4180And17Digits(testCase)
    projectRoot = create_temporary_project(testCase);
    csvPath = fullfile(projectRoot, 'audit.csv');
    values = [pi; -0.0];
    notes = ["comma,value"; "quote""value"];
    data = table(values, notes, 'VariableNames', {'double_value', 'note'});

    rkkt.artifacts.write_table_csv_17g(csvPath, data);

    bytes = local_read_bytes(csvPath);
    csvText = native2unicode(bytes, 'UTF-8');
    expectedPrefix = sprintf('double_value,note\r\n%.17g,"comma,value"\r\n', pi);
    testCase.verifyTrue(startsWith(csvText, expectedPrefix));
    testCase.verifyTrue(contains(csvText, '"quote""value"'));
    crlfCount = sum(bytes(1:end-1) == uint8(13) & bytes(2:end) == uint8(10));
    lfCount = sum(bytes == uint8(10));
    testCase.verifyEqual(crlfCount, 3);
    testCase.verifyEqual(lfCount, 3);
end

function testJsonMatAndEmptyManifests(testCase)
    projectRoot = create_temporary_project(testCase);
    context = rkkt.artifacts.create_run_context(projectRoot, 'stage_0', ...
        'RunId', '20260718_120002_stage_0_test0003');

    jsonPath = fullfile(context.root, 'sample.json');
    rkkt.artifacts.write_json_file(jsonPath, struct('description', '真实值', 'number', pi));
    decoded = jsondecode(fileread(jsonPath));
    testCase.verifyEqual(decoded.description, '真实值');
    testCase.verifyEqual(decoded.number, pi, 'AbsTol', eps(pi));

    matrix = sparse([1, 3], [2, 1], [pi, -2], 3, 3);
    matPath = fullfile(context.matrices_dir, 'sample.mat');
    rkkt.artifacts.save_mat_artifact(matPath, 'matrix', matrix, 'description', 'sparse test');
    loaded = load(matPath);
    testCase.verifyTrue(issparse(loaded.matrix));
    testCase.verifyEqual(loaded.matrix, matrix);
    testCase.verifyEqual(loaded.description, 'sparse test');

    issuePath = context.issue_log_path;
    local_write_bytes(issuePath, uint8('sentinel'));
    rkkt.artifacts.write_empty_stage0_manifests(context);
    testCase.verifyEqual(char(local_read_bytes(issuePath)), 'sentinel');
end

function projectRoot = create_temporary_project(testCase)
    projectRoot = tempname(tempdir);
    [created, message] = mkdir(projectRoot);
    testCase.assertTrue(created, message);
    testCase.addTeardown(@() remove_temporary_project(projectRoot));
end

function remove_temporary_project(projectRoot)
    % The test owns this temp directory. It never points at repository runs.
    if isfolder(projectRoot)
        rmdir(projectRoot, 's');
    end
end

function local_write_bytes(filePath, bytes)
    fileId = fopen(filePath, 'wb');
    assert(fileId >= 0, 'Could not open test file for writing.');
    cleanup = onCleanup(@() local_close_file(fileId));
    fwrite(fileId, bytes, 'uint8');
    fclose(fileId);
    clear cleanup;
end

function local_close_file(fileId)
    try
        openName = fopen(fileId);
        if ischar(openName) && ~isempty(openName)
            fclose(fileId);
        end
    catch
    end
end

function bytes = local_read_bytes(filePath)
    fileId = fopen(filePath, 'rb');
    assert(fileId >= 0, 'Could not open test file for reading.');
    cleanup = onCleanup(@() fclose(fileId));
    bytes = fread(fileId, Inf, '*uint8')';
end
