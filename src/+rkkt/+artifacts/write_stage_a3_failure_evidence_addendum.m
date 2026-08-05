function evidence = write_stage_a3_failure_evidence_addendum(runContext)
%WRITE_STAGE_A3_FAILURE_EVIDENCE_ADDENDUM Hash post-failure immutable evidence.
% This never overwrites the primary PASS-candidate inventory. It includes
% that inventory as prior evidence and excludes only the mutable manifest
% and its own self-referential target.

arguments
    runContext (1,1) struct
end
target=fullfile(runContext.acceptance_dir, ...
    "evidence_hashes_failure_addendum.csv");
if isfile(target)||isfolder(target)
    error("stageA3:artifacts:FailureAddendumExists", ...
        "Failure evidence addendum already exists: %s",target);
end
listing=dir(fullfile(runContext.root,"**","*"));
relativePath=strings(0,1); absolutePath=strings(0,1); scope=strings(0,1);
for k=1:numel(listing)
    if listing(k).isdir, continue; end
    pathValue=string(fullfile(listing(k).folder,listing(k).name));
    relative=replace(extractAfter(pathValue, ...
        strlength(string(runContext.root))+1),'\','/');
    if ismember(relative,["run_manifest.json", ...
            "acceptance/evidence_hashes_failure_addendum.csv",".initializing"])
        continue
    end
    absolutePath(end+1,1)=pathValue; %#ok<AGROW>
    relativePath(end+1,1)=relative; %#ok<AGROW>
    first=extractBefore(relative,"/"); if strlength(first)==0, first="run_root"; end
    scope(end+1,1)=first; %#ok<AGROW>
end
[relativePath,order]=sort(relativePath);
absolutePath=absolutePath(order); scope=scope(order);
assert(~isempty(relativePath)&&numel(unique(relativePath))==numel(relativePath), ...
    "stageA3:artifacts:FailureAddendumInventory", ...
    "Failure evidence paths must be nonempty and unique.");
n=numel(relativePath); bytes=zeros(n,1); sha256=strings(n,1);
status=repmat("PASS",n,1);
checkedAt=repmat(string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX')),n,1);
for k=1:n
    info=dir(absolutePath(k)); assert(isscalar(info)&&~info.isdir, ...
        "stageA3:artifacts:FailureEvidenceMissing", ...
        "Missing failure evidence: %s",absolutePath(k));
    bytes(k)=info.bytes; sha256(k)=lower(string(rkkt.data.compute_sha256_file(absolutePath(k))));
    if strlength(sha256(k))~=64, status(k)="FAIL"; end
end
evidence=table(relativePath,scope,bytes,sha256,status,checkedAt, ...
    'VariableNames',{'relative_path','scope','bytes','sha256','status','checked_at'});
assert(all(status=="PASS"),"stageA3:artifacts:FailureEvidenceHashFailure", ...
    "One or more post-failure files could not be hashed.");
rkkt.artifacts.write_table_csv_17g(target,evidence);
end
