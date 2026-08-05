function manifest = update_running_run_manifest(runContext, updates)
%UPDATE_RUNNING_RUN_MANIFEST Persist observed facts before terminalization.
%
% Only a RUNNING manifest can be updated. Run identity and lifecycle fields
% remain immutable; use finalize_run_manifest for the one terminal state
% transition. This supports evidence-driven report generation without
% declaring PASS before the report package has itself been validated.

    if ~isstruct(runContext) || ~isscalar(runContext) || ...
            ~isfield(runContext, 'run_manifest_path') || ...
            ~isfield(runContext, 'run_id') || ~isfield(runContext, 'stage_id')
        error('stage0:artifacts:InvalidRunContext', 'Invalid run context.');
    end
    if ~isstruct(updates) || ~isscalar(updates)
        error('stage0:artifacts:InvalidManifestUpdates', ...
            'Manifest updates must be a scalar struct.');
    end

    manifestPath = runContext.run_manifest_path;
    if ~isfile(manifestPath)
        error('stage0:artifacts:ManifestMissing', ...
            'Run manifest does not exist: %s', manifestPath);
    end
    try
        manifest = jsondecode(fileread(manifestPath));
    catch exception
        error('stage0:artifacts:ManifestInvalid', ...
            'Could not decode run manifest %s: %s', manifestPath, exception.message);
    end
    if ~isfield(manifest, 'status') || ~strcmp(manifest.status, 'RUNNING')
        error('stage0:artifacts:ManifestAlreadyFinal', ...
            'Only a RUNNING run manifest can be updated.');
    end
    if ~isfield(manifest, 'run_id') || ...
            ~strcmp(char(string(manifest.run_id)), char(string(runContext.run_id))) || ...
            ~isfield(manifest, 'stage_id') || ...
            ~strcmp(char(string(manifest.stage_id)), char(string(runContext.stage_id)))
        error('stage0:artifacts:ManifestIdentityMismatch', ...
            'Run context identity does not match the persisted run manifest.');
    end

    protected = {'run_id', 'stage_id', 'status', 'started_at', 'ended_at', ...
        'model_contract_version', 'git_commit', 'effective_config', ...
        'run_purpose', 'parent_run_id', 'historical_baseline_commit', ...
        'actual_test_command', 'optimization_executed', ...
        'a1_solver_executed'};
    updateNames = fieldnames(updates);
    forbidden = intersect(updateNames, protected, 'stable');
    if ~isempty(forbidden)
        error('stage0:artifacts:ImmutableManifestField', ...
            'Manifest updates cannot replace immutable field: %s', forbidden{1});
    end
    for k = 1:numel(updateNames)
        manifest.(updateNames{k}) = updates.(updateNames{k});
    end
    rkkt.artifacts.write_json_file(manifestPath, manifest);
end
