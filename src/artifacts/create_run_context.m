function context = create_run_context(projectRoot, stageId, varargin)
%CREATE_RUN_CONTEXT Create a new, non-overwriting run artifact directory.
%
% context = create_run_context(projectRoot, stageId) creates a unique
% runs/<run_id> directory, the standard artifact subdirectories, an initial
% RUNNING run_manifest.json, git_state.txt, effective_config.yaml, and the
% empty CSV manifests used by stage_0.
%
% Name-value options:
%   RunId                  Explicit run id. An existing id is an error.
%   ModelContractVersion   Version recorded in run_manifest.json (v1.0).
%   InputHashes            Scalar struct recorded in run_manifest.json.
%   EffectiveConfigPath    YAML file copied into the run directory.
%   ManifestMetadata       Additional immutable run identity metadata.

% Auto-generated ids follow YYYYMMDD_HHMMSS_<stage_id>_<git_short_sha>.
% If that id is already present, a numeric suffix is added. An explicitly
% supplied duplicate id always fails with stage0:artifacts:RunExists.

% This function never changes global git configuration. Git is queried with
% a command-local safe.directory setting and absence of git/a repository is
% recorded as NOT_AVAILABLE rather than preventing run creation.

    projectRoot = validate_text_scalar(projectRoot, 'projectRoot');
    stageId = validate_identifier_text(stageId, 'stageId');

    parser = inputParser;
    parser.FunctionName = mfilename;
    addParameter(parser, 'RunId', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'ModelContractVersion', 'v1.0', ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'InputHashes', struct(), @(x) isstruct(x) && isscalar(x));
    addParameter(parser, 'EffectiveConfigPath', '', ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'ManifestMetadata', struct(), ...
        @(x) isstruct(x) && isscalar(x));
    parse(parser, varargin{:});

    projectRoot = char(java.io.File(projectRoot).getCanonicalPath());
    if ~isfolder(projectRoot)
        error('stage0:artifacts:ProjectRootMissing', ...
            'Project root does not exist: %s', projectRoot);
    end

    gitInfo = capture_git_state(projectRoot);
    runsRoot = fullfile(projectRoot, 'runs');
    ensure_directory(runsRoot);

    requestedRunId = char(string(parser.Results.RunId));
    explicitRunId = ~isempty(requestedRunId);
    if explicitRunId
        runId = validate_identifier_text(requestedRunId, 'RunId');
    else
        timestamp = char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyyMMdd_HHmmss'));
        baseRunId = sprintf('%s_%s_%s', timestamp, stageId, gitInfo.short_commit);
        runId = choose_available_run_id(runsRoot, baseRunId);
    end

    runRoot = fullfile(runsRoot, runId);
    if exist(runRoot, 'file') || isfolder(runRoot)
        error('stage0:artifacts:RunExists', ...
            'Run directory already exists and will not be overwritten: %s', runRoot);
    end

    [created, message, messageId] = mkdir(runRoot);
    if ~created
        error('stage0:artifacts:CreateRunFailed', ...
            'Could not create run directory %s: %s', runRoot, message);
    end
    if strcmp(messageId, 'MATLAB:MKDIR:DirectoryExists')
        error('stage0:artifacts:RunExists', ...
            'Run directory already exists and will not be overwritten: %s', runRoot);
    end

    initializationMarker = fullfile(runRoot, '.initializing');
    markerId = fopen(initializationMarker, 'wb');
    if markerId < 0
        error('stage0:artifacts:InitializationMarkerFailed', ...
            'Could not create initialization marker in %s.', runRoot);
    end
    fclose(markerId);
    cleanupGuard = onCleanup(@() preserve_incomplete_run( ...
        runRoot, initializationMarker));

    context = build_context(projectRoot, runsRoot, runRoot, runId, stageId);
    subdirectories = {
        context.iterations_dir
        context.indices_dir
        context.matrices_dir
        context.checkpoints_dir
        context.tests_dir
        context.issues_dir
        context.acceptance_dir
        context.reports_dir
        };
    for k = 1:numel(subdirectories)
        ensure_directory(subdirectories{k});
    end

    write_text_utf8(context.git_state_path, gitInfo.state_text);
    materialize_effective_config(context, parser.Results.EffectiveConfigPath);
    if strcmp(stageId, 'stage_0')
        write_empty_stage0_manifests(context);
    end

    initialize_run_manifest(context, ...
        'ModelContractVersion', parser.Results.ModelContractVersion, ...
        'InputHashes', parser.Results.InputHashes, ...
        'GitCommit', gitInfo.commit, ...
        'Metadata', parser.Results.ManifestMetadata);

    delete(initializationMarker);
    clear cleanupGuard;
end

function preserve_incomplete_run(runRoot, markerPath)
    % A failed run initialization is still evidence. Preserve the unique
    % directory and replace its transient marker when possible; never
    % delete a failed run directory.
    if isfile(markerPath) && isfolder(runRoot)
        failureMarker = fullfile(runRoot, '.initialization_failed');
        try
            if ~isfile(failureMarker) && ~isfolder(failureMarker)
                movefile(markerPath, failureMarker);
            end
        catch
            % Preserve the original initialization exception.
        end
    end
end

function context = build_context(projectRoot, runsRoot, runRoot, runId, stageId)
    context = struct();
    context.project_root = projectRoot;
    context.runs_root = runsRoot;
    context.root = runRoot;
    context.run_dir = runRoot;
    context.run_id = runId;
    context.stage_id = stageId;

    context.iterations_dir = fullfile(runRoot, 'iterations');
    context.indices_dir = fullfile(runRoot, 'indices');
    context.matrices_dir = fullfile(runRoot, 'matrices');
    context.checkpoints_dir = fullfile(runRoot, 'checkpoints');
    context.tests_dir = fullfile(runRoot, 'tests');
    context.issues_dir = fullfile(runRoot, 'issues');
    context.acceptance_dir = fullfile(runRoot, 'acceptance');
    context.reports_dir = fullfile(runRoot, 'reports');

    context.run_manifest_path = fullfile(runRoot, 'run_manifest.json');
    context.environment_csv_path = fullfile(runRoot, 'environment.csv');
    context.input_hashes_csv_path = fullfile(runRoot, 'input_hashes.csv');
    context.effective_config_path = fullfile(runRoot, 'effective_config.yaml');
    context.git_state_path = fullfile(runRoot, 'git_state.txt');
    context.matrix_manifest_path = fullfile(context.matrices_dir, 'matrix_manifest.csv');
    context.checkpoint_manifest_path = fullfile(context.checkpoints_dir, 'checkpoint_manifest.csv');
    context.test_inventory_path = fullfile(context.tests_dir, 'test_inventory.csv');
    context.test_results_csv_path = fullfile(context.tests_dir, 'test_results.csv');
    context.test_results_xml_path = fullfile(context.tests_dir, 'test_results.xml');
    context.test_console_log_path = fullfile(context.tests_dir, 'matlab_test_console.log');
    context.test_command_path = fullfile(context.tests_dir, 'test_command.txt');
    context.test_summary_path = fullfile(context.tests_dir, 'test_summary.json');
    context.test_evidence_manifest_path = fullfile(context.tests_dir, 'test_evidence_manifest.csv');
    context.issue_log_path = fullfile(context.issues_dir, 'issue_log.csv');
    context.decision_log_path = fullfile(context.issues_dir, 'decision_log.csv');
    context.acceptance_results_path = fullfile(context.acceptance_dir, 'acceptance_results.csv');

    context.paths = struct( ...
        'run_manifest', context.run_manifest_path, ...
        'environment', context.environment_csv_path, ...
        'input_hashes', context.input_hashes_csv_path, ...
        'effective_config', context.effective_config_path, ...
        'git_state', context.git_state_path, ...
        'iterations', context.iterations_dir, ...
        'indices', context.indices_dir, ...
        'matrices', context.matrices_dir, ...
        'checkpoints', context.checkpoints_dir, ...
        'tests', context.tests_dir, ...
        'issues', context.issues_dir, ...
        'acceptance', context.acceptance_dir, ...
        'reports', context.reports_dir);
end

function materialize_effective_config(context, configuredPath)
    configuredPath = char(string(configuredPath));
    isExplicit = ~isempty(configuredPath);
    if ~isExplicit
        configuredPath = fullfile(context.project_root, 'config', ...
            [context.stage_id, '.yaml']);
    end

    if isfile(configuredPath)
        [copied, message] = copyfile(configuredPath, context.effective_config_path);
        if ~copied
            error('stage0:artifacts:ConfigCopyFailed', ...
                'Could not copy effective config %s: %s', configuredPath, message);
        end
    elseif isExplicit
        error('stage0:artifacts:ConfigMissing', ...
            'Effective config file does not exist: %s', configuredPath);
    else
        placeholder = sprintf([ ...
            'stage_id: "%s"\r\n', ...
            'source: "NOT_PROVIDED"\r\n'], context.stage_id);
        write_text_utf8(context.effective_config_path, placeholder);
    end
end

function runId = choose_available_run_id(runsRoot, baseRunId)
    runId = baseRunId;
    suffix = 1;
    while exist(fullfile(runsRoot, runId), 'file') || isfolder(fullfile(runsRoot, runId))
        suffix = suffix + 1;
        runId = sprintf('%s_%03d', baseRunId, suffix);
    end
end

function ensure_directory(pathValue)
    if isfolder(pathValue)
        return;
    end
    if exist(pathValue, 'file')
        error('stage0:artifacts:PathConflict', ...
            'A file exists where a directory is required: %s', pathValue);
    end
    [created, message] = mkdir(pathValue);
    if ~created
        error('stage0:artifacts:CreateDirectoryFailed', ...
            'Could not create directory %s: %s', pathValue, message);
    end
end

function value = validate_text_scalar(value, argumentName)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('stage0:artifacts:InvalidText', '%s must be a text scalar.', argumentName);
    end
    value = char(string(value));
    if isempty(strtrim(value)) || any(value == char(0))
        error('stage0:artifacts:InvalidText', '%s must not be empty.', argumentName);
    end
end

function value = validate_identifier_text(value, argumentName)
    value = validate_text_scalar(value, argumentName);
    if isempty(regexp(value, '^[A-Za-z0-9][A-Za-z0-9._-]*$', 'once')) || ...
            strcmp(value, '.') || strcmp(value, '..')
        error('stage0:artifacts:InvalidIdentifier', ...
            '%s contains characters that are unsafe in a run path: %s', ...
            argumentName, value);
    end
end
