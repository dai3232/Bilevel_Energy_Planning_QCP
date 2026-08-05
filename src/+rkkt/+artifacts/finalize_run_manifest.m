function manifest = finalize_run_manifest(runContext, finalStatus, updates)
%FINALIZE_RUN_MANIFEST Transition a RUNNING manifest to one terminal state.
%
% manifest = rkkt.artifacts.finalize_run_manifest(context, status) accepts only PASS,
% FAIL_RETRYABLE, BLOCKED_EXTERNAL, or NEEDS_MODEL_DECISION. Optional scalar
% struct updates are merged before status and ended_at are set. Run identity
% and lifecycle fields cannot be changed through updates.

    if nargin < 3
        updates = struct();
    end
    if ~isstruct(runContext) || ~isscalar(runContext) || ...
            ~isfield(runContext, 'run_manifest_path')
        error('stage0:artifacts:InvalidRunContext', 'Invalid run context.');
    end
    if ~(ischar(finalStatus) || (isstring(finalStatus) && isscalar(finalStatus)))
        error('stage0:artifacts:InvalidFinalStatus', 'Final status must be text.');
    end
    finalStatus = char(string(finalStatus));
    allowed = {'PASS', 'FAIL_RETRYABLE', 'BLOCKED_EXTERNAL', 'NEEDS_MODEL_DECISION'};
    if ~ismember(finalStatus, allowed)
        error('stage0:artifacts:InvalidFinalStatus', ...
            'Invalid terminal status: %s', finalStatus);
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
        statusText = '<missing>';
        if isfield(manifest, 'status')
            statusText = char(string(manifest.status));
        end
        error('stage0:artifacts:ManifestAlreadyFinal', ...
            'Run manifest is not RUNNING (current status: %s).', statusText);
    end
    if ~isfield(manifest, 'run_id') || ~isfield(runContext, 'run_id') || ...
            ~strcmp(char(string(manifest.run_id)), char(string(runContext.run_id))) || ...
            ~isfield(manifest, 'stage_id') || ~isfield(runContext, 'stage_id') || ...
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

    manifest.status = finalStatus;
    manifest.ended_at = rkkt.artifacts.current_utc_iso8601();
    rkkt.artifacts.write_json_file(manifestPath, manifest);
end
