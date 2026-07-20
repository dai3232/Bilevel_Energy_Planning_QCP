function evidence = write_stage_a2_evidence_hashes(runContext)
%WRITE_STAGE_A2_EVIDENCE_HASHES Hash every finalized immutable run artifact.
% run_manifest.json and this inventory are excluded to avoid self-reference.

arguments
    runContext (1,1) struct
end
target = fullfile(runContext.acceptance_dir,"evidence_hashes.csv");
if isfile(target) || isfolder(target)
    error("stageA2:artifacts:RefuseOverwrite", ...
        "Evidence hash target already exists: %s",target);
end
listing = dir(fullfile(runContext.root,"**","*"));
relativePath = strings(0,1); absolutePath = strings(0,1);
scope = strings(0,1);
for k = 1:numel(listing)
    if listing(k).isdir, continue; end
    pathValue = string(fullfile(listing(k).folder,listing(k).name));
    relative = normalize_relative(pathValue,runContext.root);
    if ismember(relative,["run_manifest.json", ...
            "acceptance/evidence_hashes.csv",".initializing"])
        continue
    end
    absolutePath(end+1,1)=pathValue; %#ok<AGROW>
    relativePath(end+1,1)=relative; %#ok<AGROW>
    scope(end+1,1)=classify_scope(relative); %#ok<AGROW>
end
[relativePath,order] = sort(relativePath);
absolutePath = absolutePath(order); scope = scope(order);
assert(~isempty(relativePath) && numel(unique(relativePath))==numel(relativePath), ...
    "stageA2:artifacts:EvidenceInventory", ...
    "A2 evidence paths must be nonempty and unique.");
n = numel(relativePath); bytes=zeros(n,1); sha256=strings(n,1);
status=repmat("PASS",n,1);
checkedAt=repmat(string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')),n,1);
for k = 1:n
    info=dir(absolutePath(k));
    assert(isscalar(info) && ~info.isdir, ...
        "stageA2:artifacts:EvidenceMissing","Missing evidence: %s",absolutePath(k));
    bytes(k)=info.bytes; sha256(k)=lower(string(compute_sha256_file(absolutePath(k))));
    if strlength(sha256(k))~=64, status(k)="FAIL"; end
end
evidence=table(relativePath,scope,bytes,sha256,status,checkedAt, ...
    'VariableNames',{'relative_path','scope','bytes','sha256','status','checked_at'});
assert(all(status=="PASS"),"stageA2:artifacts:EvidenceHashFailure", ...
    "One or more A2 evidence files could not be hashed.");
write_table_csv_17g(target,evidence);
end

function value = normalize_relative(pathValue,root)
value=replace(extractAfter(string(pathValue),strlength(string(root))+1),'\','/');
end
function value = classify_scope(relative)
value=extractBefore(relative,"/"); if strlength(value)==0, value="run_root"; end
end
