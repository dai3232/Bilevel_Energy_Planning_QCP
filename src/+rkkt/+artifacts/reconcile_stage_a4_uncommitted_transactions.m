function audit = reconcile_stage_a4_uncommitted_transactions( ...
        runContext,committedRevision)
%RECONCILE_STAGE_A4_UNCOMMITTED_TRANSACTIONS Preserve incomplete revisions.
%
% A checkpoint transaction publishes an immutable revision snapshot, then
% a checkpoint MAT, then checkpoint_manifest.csv.  If execution stops
% between those atomic publishes, every snapshot and MAT newer than the
% latest committed manifest revision is moved together into this run's
% recovery archive.  Nothing is deleted or overwritten.

arguments
    runContext (1,1) struct
    committedRevision (1,1) double {mustBeInteger,mustBeNonnegative}
end
required = ["root","iterations_dir","checkpoints_dir"];
assert(all(isfield(runContext,required)) && ...
    isfolder(runContext.root) && ...
    isfolder(runContext.iterations_dir) && ...
    isfolder(runContext.checkpoints_dir), ...
    "stageA4:a43:OrphanRunContext", ...
    "A valid A4-3 run context is required.");

revisions = zeros(0,1);
sourcePaths = strings(0,1);
archivePaths = strings(0,1);
artifactTypes = strings(0,1);

revisionRoot = fullfile(runContext.iterations_dir,"revisions");
entries = dir(fullfile(revisionRoot,"revision_*"));
entries = entries([entries.isdir]);
for k = 1:numel(entries)
    token = regexp(entries(k).name,"^revision_(\d{3})$", ...
        "tokens","once");
    if isempty(token)
        continue
    end
    revision = str2double(token{1});
    if revision<=committedRevision
        continue
    end
    source = fullfile(entries(k).folder,entries(k).name);
    target = quarantine_orphan(runContext,source,entries(k).name, ...
        "revision_snapshot");
    revisions(end+1,1) = revision; %#ok<AGROW>
    sourcePaths(end+1,1) = string(source); %#ok<AGROW>
    archivePaths(end+1,1) = string(target); %#ok<AGROW>
    artifactTypes(end+1,1) = "revision_snapshot"; %#ok<AGROW>
end

checkpointEntries = dir(fullfile(runContext.checkpoints_dir, ...
    "stage_A4_checkpoint_*.mat"));
for k = 1:numel(checkpointEntries)
    token = regexp(checkpointEntries(k).name, ...
        "^stage_A4_checkpoint_(\d{3})\.mat$","tokens","once");
    if isempty(token)
        continue
    end
    revision = str2double(token{1});
    if revision<=committedRevision
        continue
    end
    source = fullfile(checkpointEntries(k).folder, ...
        checkpointEntries(k).name);
    target = quarantine_orphan(runContext,source, ...
        checkpointEntries(k).name,"checkpoint_mat");
    revisions(end+1,1) = revision; %#ok<AGROW>
    sourcePaths(end+1,1) = string(source); %#ok<AGROW>
    archivePaths(end+1,1) = string(target); %#ok<AGROW>
    artifactTypes(end+1,1) = "checkpoint_mat"; %#ok<AGROW>
end

audit = struct( ...
    "orphan_count",numel(revisions), ...
    "orphan_revisions",revisions, ...
    "source_paths",sourcePaths, ...
    "quarantine_paths",archivePaths, ...
    "artifact_types",artifactTypes, ...
    "paired_revision_count",numel(unique(revisions)), ...
    "passed",all(revisions>committedRevision) && ...
        all(isfile(archivePaths) | isfolder(archivePaths)) && ...
        ~any(isfile(sourcePaths) | isfolder(sourcePaths)));
assert(audit.passed,"stageA4:a43:OrphanQuarantine", ...
    "An uncommitted A4-3 checkpoint transaction was not preserved.");
end

function target = quarantine_orphan(context,source,name,artifactType)
quarantineRoot = fullfile(context.root,"recovery", ...
    "orphaned_checkpoint_transactions");
if ~isfolder(quarantineRoot)
    [created,message] = mkdir(quarantineRoot);
    assert(created,"stageA4:a43:OrphanQuarantineCreate","%s",message);
end
safeType = matlab.lang.makeValidName(char(artifactType));
target = fullfile(quarantineRoot,string(name)+"_"+safeType+"_uncommitted");
suffix = 1;
while isfile(target)||isfolder(target)
    suffix = suffix+1;
    target = fullfile(quarantineRoot,string(name)+"_"+safeType+ ...
        "_uncommitted_"+compose("%03d",suffix));
end
[moved,message] = movefile(source,target);
assert(moved,"stageA4:a43:OrphanQuarantineMove","%s",message);
end
