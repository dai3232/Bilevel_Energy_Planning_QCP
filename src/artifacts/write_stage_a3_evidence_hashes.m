function evidence = write_stage_a3_evidence_hashes(runContext)
%WRITE_STAGE_A3_EVIDENCE_HASHES Hash every finalized immutable run artifact.
% run_manifest.json and this inventory are excluded to avoid self-reference.

arguments
    runContext (1,1) struct
end
target=fullfile(runContext.acceptance_dir,"evidence_hashes.csv");
if isfile(target) || isfolder(target)
    error("stageA3:artifacts:RefuseOverwrite", ...
        "Evidence hash target already exists: %s",target);
end
listing=dir(fullfile(runContext.root,"**","*"));
relativePath=strings(0,1); absolutePath=strings(0,1); scope=strings(0,1);
for k=1:numel(listing)
    if listing(k).isdir, continue; end
    pathValue=string(fullfile(listing(k).folder,listing(k).name));
    relative=replace(extractAfter(pathValue, ...
        strlength(string(runContext.root))+1),'\','/');
    if ismember(relative,["run_manifest.json", ...
            "acceptance/evidence_hashes.csv",".initializing"])
        continue
    end
    absolutePath(end+1,1)=pathValue; %#ok<AGROW>
    relativePath(end+1,1)=relative; %#ok<AGROW>
    first=extractBefore(relative,"/");
    if strlength(first)==0, first="run_root"; end
    scope(end+1,1)=first; %#ok<AGROW>
end
[relativePath,order]=sort(relativePath);
absolutePath=absolutePath(order); scope=scope(order);
assert(~isempty(relativePath) && numel(unique(relativePath))==numel(relativePath), ...
    "stageA3:artifacts:EvidenceInventory", ...
    "A3 evidence paths must be nonempty and unique.");
n=numel(relativePath); bytes=zeros(n,1); sha256=strings(n,1);
status=repmat("PASS",n,1);
checkedAt=repmat(string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')),n,1);
for k=1:n
    info=dir(absolutePath(k));
    assert(isscalar(info) && ~info.isdir, ...
        "stageA3:artifacts:EvidenceMissing","Missing evidence: %s",absolutePath(k));
    bytes(k)=info.bytes;
    sha256(k)=lower(string(compute_sha256_file(absolutePath(k))));
    if strlength(sha256(k))~=64, status(k)="FAIL"; end
end
evidence=table(relativePath,scope,bytes,sha256,status,checkedAt, ...
    'VariableNames',{'relative_path','scope','bytes','sha256','status','checked_at'});
assert(all(status=="PASS"),"stageA3:artifacts:EvidenceHashFailure", ...
    "One or more A3 evidence files could not be hashed.");
write_table_csv_17g(target,evidence);
end
