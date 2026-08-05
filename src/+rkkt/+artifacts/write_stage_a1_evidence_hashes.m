function evidence = write_stage_a1_evidence_hashes(runContext,stagedReports)
%WRITE_STAGE_A1_EVIDENCE_HASHES Hash finalized evidence before manifest close.
% The mutable run_manifest.json and this hash table itself are excluded to
% avoid self-reference. Staged reports are hashed under their final paths.

arguments
    runContext (1,1) struct
    stagedReports (1,1) struct
end
target = fullfile(runContext.acceptance_dir,"evidence_hashes.csv");
refuse_existing(target);

listing = dir(fullfile(runContext.root,"**","*"));
absolutePath = strings(0,1);
relativePath = strings(0,1);
scope = strings(0,1);
for k = 1:numel(listing)
    if listing(k).isdir
        continue
    end
    pathValue = string(fullfile(listing(k).folder,listing(k).name));
    relative = normalize_relative(pathValue,runContext.root);
    if ismember(relative,["run_manifest.json", ...
            "acceptance/evidence_hashes.csv",".initializing"])
        continue
    end
    absolutePath(end+1,1) = pathValue; %#ok<AGROW>
    relativePath(end+1,1) = relative; %#ok<AGROW>
    scope(end+1,1) = classify_scope(relative); %#ok<AGROW>
end

reportFields = fieldnames(stagedReports);
for k = 1:numel(reportFields)
    pathValue = string(stagedReports.(reportFields{k}));
    assert(isfile(pathValue),"stageA1:artifacts:StagedReportMissing", ...
        "Staged report is missing: %s",pathValue);
    relative = "reports/" + string(get_file_name(pathValue));
    assert(~any(relativePath == relative), ...
        "stageA1:artifacts:DuplicateEvidencePath", ...
        "Evidence path is duplicated: %s",relative);
    absolutePath(end+1,1) = pathValue; %#ok<AGROW>
    relativePath(end+1,1) = relative; %#ok<AGROW>
    scope(end+1,1) = "report"; %#ok<AGROW>
end

[relativePath,order] = sort(relativePath);
absolutePath = absolutePath(order);
scope = scope(order);
assert(numel(unique(relativePath)) == numel(relativePath) && ...
    ~isempty(relativePath),"stageA1:artifacts:EvidenceInventory", ...
    "Evidence paths must be nonempty and unique.");

n = numel(relativePath);
sha256 = strings(n,1);
bytes = zeros(n,1);
status = repmat("PASS",n,1);
checkedAt = repmat(string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')),n,1);
for k = 1:n
    info = dir(absolutePath(k));
    assert(isscalar(info) && ~info.isdir, ...
        "stageA1:artifacts:EvidenceFileMissing", ...
        "Evidence file is not readable: %s",absolutePath(k));
    bytes(k) = info.bytes;
    sha256(k) = lower(string(rkkt.data.compute_sha256_file(absolutePath(k))));
    if strlength(sha256(k)) ~= 64
        status(k) = "FAIL";
    end
end
evidence = table(relativePath,scope,bytes,sha256,status,checkedAt, ...
    'VariableNames',{'relative_path','scope','bytes','sha256','status', ...
    'checked_at'});
assert(all(evidence.status == "PASS"), ...
    "stageA1:artifacts:EvidenceHashFailure", ...
    "One or more evidence files could not be hashed.");
rkkt.artifacts.write_table_csv_17g(target,evidence);
end

function value = normalize_relative(pathValue,root)
value = replace(extractAfter(string(pathValue),strlength(string(root))+1),'\','/');
end

function scope = classify_scope(relative)
first = extractBefore(relative,"/");
if strlength(first) == 0 || first == relative
    scope = "run_root";
else
    scope = first;
end
end

function name = get_file_name(pathValue)
[~,base,extension] = fileparts(pathValue);
name = string(base) + string(extension);
end

function refuse_existing(pathValue)
if isfile(pathValue) || isfolder(pathValue)
    error("stageA1:artifacts:RefuseOverwrite", ...
        "Evidence target already exists: %s",pathValue);
end
end
