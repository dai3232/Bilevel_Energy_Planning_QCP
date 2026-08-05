function manifest = initialize_run_manifest(runContext, varargin)
%INITIALIZE_RUN_MANIFEST Write the immutable initial RUNNING run manifest.

    validate_run_context(runContext);

    parser = inputParser;
    parser.FunctionName = mfilename;
    addParameter(parser, 'ModelContractVersion', 'v1.0', ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'InputHashes', struct(), @(x) isstruct(x) && isscalar(x));
    addParameter(parser, 'GitCommit', 'NOT_AVAILABLE', ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'Metadata', struct(), ...
        @(x) isstruct(x) && isscalar(x));
    parse(parser, varargin{:});

    manifestPath = runContext.run_manifest_path;
    if isfile(manifestPath) || isfolder(manifestPath)
        error('stage0:artifacts:ManifestExists', ...
            'Initial run manifest already exists and will not be overwritten: %s', ...
            manifestPath);
    end

    manifest = struct();
    manifest.run_id = runContext.run_id;
    manifest.stage_id = runContext.stage_id;
    manifest.status = 'RUNNING';
    manifest.started_at = rkkt.artifacts.current_utc_iso8601();
    % jsonencode emits scalar NaN as JSON null, matching the run schema.
    manifest.ended_at = NaN;
    manifest.model_contract_version = char(string(parser.Results.ModelContractVersion));
    manifest.input_hashes = parser.Results.InputHashes;
    manifest.git_commit = char(string(parser.Results.GitCommit));
    manifest.effective_config = 'effective_config.yaml';
    manifest.thermal_pass = 'none';

    metadata = parser.Results.Metadata;
    protected = {'run_id', 'stage_id', 'status', 'started_at', 'ended_at', ...
        'model_contract_version', 'input_hashes', 'git_commit', ...
        'effective_config', 'thermal_pass'};
    metadataNames = fieldnames(metadata);
    forbidden = intersect(metadataNames, protected, 'stable');
    if ~isempty(forbidden)
        error('stage0:artifacts:ReservedManifestMetadata', ...
            'Manifest metadata cannot replace reserved field: %s', forbidden{1});
    end
    for k = 1:numel(metadataNames)
        manifest.(metadataNames{k}) = metadata.(metadataNames{k});
    end

    rkkt.artifacts.write_json_file(manifestPath, manifest);
end

function validate_run_context(runContext)
    required = {'run_id', 'stage_id', 'root', 'run_manifest_path'};
    if ~isstruct(runContext) || ~isscalar(runContext) || ...
            ~all(isfield(runContext, required))
        error('stage0:artifacts:InvalidRunContext', ...
            'runContext does not contain the required run identity and paths.');
    end
    if ~isfolder(runContext.root)
        error('stage0:artifacts:RunRootMissing', ...
            'Run root does not exist: %s', runContext.root);
    end
end
