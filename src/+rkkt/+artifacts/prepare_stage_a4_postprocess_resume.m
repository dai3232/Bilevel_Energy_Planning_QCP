function audit = prepare_stage_a4_postprocess_resume(context)
%PREPARE_STAGE_A4_POSTPROCESS_RESUME Archive disposable partial outputs.
%
% Numeric trajectory, checkpoints and immutable iteration revisions are
% never touched.  Partial postprocessing products are preserved inside the
% same run, and every required destination directory is recreated even
% when an earlier interruption happened after a directory move.

arguments
    context (1,1) struct
end
required = ["root","indices_dir","matrices_dir","acceptance_dir", ...
    "issues_dir","reports_dir"];
assert(all(isfield(context,required)) && isfolder(context.root), ...
    "stageA4:a43:PostprocessContext", ...
    "A valid A4-3 run context is required.");

archiveRoot = fullfile(context.root,"recovery", ...
    "postprocess_"+string(datetime("now","TimeZone","UTC", ...
    "Format","yyyyMMdd_HHmmss_SSS")));
[created,message] = mkdir(archiveRoot);
assert(created,"stageA4:a43:PostprocessArchive","%s",message);
directoryTargets = [string(context.indices_dir); ...
    string(context.matrices_dir);fullfile(context.root,"results"); ...
    fullfile(context.root,"diagnostics");string(context.acceptance_dir); ...
    string(context.issues_dir);string(context.reports_dir)];
movedSources = strings(0,1);
movedTargets = strings(0,1);
for source = directoryTargets.'
    if ~isfolder(source)
        [recreated,createMessage] = mkdir(source);
        assert(recreated,"stageA4:a43:PostprocessRecreate", ...
            "%s",createMessage);
        continue
    end
    entries = dir(fullfile(source,"*"));
    entries = entries(~ismember(string({entries.name}),[".",".."]));
    if isempty(entries)
        continue
    end
    [~,name,extension] = fileparts(source);
    target = unique_target(archiveRoot,string(name)+string(extension));
    [moved,moveMessage] = movefile(source,target);
    assert(moved,"stageA4:a43:PostprocessArchive","%s",moveMessage);
    movedSources(end+1,1) = string(source); %#ok<AGROW>
    movedTargets(end+1,1) = string(target); %#ok<AGROW>
    [recreated,createMessage] = mkdir(source);
    assert(recreated,"stageA4:a43:PostprocessRecreate","%s",createMessage);
end
fileTargets = [fullfile(context.root,"a4_3_solver_result.mat"); ...
    fullfile(context.root,"historical_runs_audit.json")];
for source = fileTargets.'
    if ~isfile(source)
        continue
    end
    [~,name,extension] = fileparts(source);
    target = unique_target(archiveRoot,string(name)+string(extension));
    [moved,moveMessage] = movefile(source,target);
    assert(moved,"stageA4:a43:PostprocessArchive","%s",moveMessage);
    movedSources(end+1,1) = string(source); %#ok<AGROW>
    movedTargets(end+1,1) = string(target); %#ok<AGROW>
end
rkkt.artifacts.write_json_file(fullfile(archiveRoot,"archive_reason.json"),struct( ...
    "reason","resume_after_interrupted_postprocessing", ...
    "run_id",string(context.run_id), ...
    "archived_at",string(datetime("now","TimeZone","Asia/Shanghai", ...
        "Format","yyyy-MM-dd'T'HH:mm:ssXXX"))));
audit = struct( ...
    "archive_root",string(archiveRoot), ...
    "moved_sources",movedSources, ...
    "moved_targets",movedTargets, ...
    "required_directories",directoryTargets, ...
    "passed",all(isfolder(directoryTargets)) && ...
        all(isfile(movedTargets) | isfolder(movedTargets)));
assert(audit.passed,"stageA4:a43:PostprocessRecovery", ...
    "The A4-3 postprocessing recovery transaction is incomplete.");
end

function target = unique_target(root,name)
target = fullfile(root,name);
suffix = 1;
while isfile(target)||isfolder(target)
    suffix = suffix+1;
    target = fullfile(root,name+"_"+compose("%03d",suffix));
end
end
