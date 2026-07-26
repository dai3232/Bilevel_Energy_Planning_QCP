function inventory = snapshot_stage_a4_historical_runs(projectRoot,options)
%SNAPSHOT_STAGE_A4_HISTORICAL_RUNS Inventory protected pre-existing runs.
%
% Every path, size, timestamp, and type is recorded.  Files no larger than
% 20 MiB are additionally SHA256-hashed; this covers manifests, reports,
% CSV evidence, and the protected run ZIPs without rereading every large
% historical MAT matrix twice.

arguments
    projectRoot (1,1) string
    options.ExcludeRunIds (:,1) string = strings(0,1)
end
root = fullfile(projectRoot,"runs");
assert(isfolder(root),"stageA4:a43:RunsMissing", ...
    "The historical runs directory is missing.");
entries = dir(fullfile(root,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."]));
n = numel(entries);
relativePath = strings(n,1);
entryType = strings(n,1);
bytes = zeros(n,1);
modifiedDatenum = zeros(n,1);
sha256 = strings(n,1);
for k = 1:n
    absolute = string(fullfile(entries(k).folder,entries(k).name));
    relativePath(k) = replace(extractAfter(absolute, ...
        strlength(string(root))+1),"\","/");
    bytes(k) = entries(k).bytes;
    modifiedDatenum(k) = entries(k).datenum;
    if entries(k).isdir
        entryType(k) = "directory";
    else
        entryType(k) = "file";
        if entries(k).bytes<=20*1024*1024
            sha256(k) = compute_sha256_file(absolute);
        else
            sha256(k) = "NOT_HASHED_OVER_20_MIB";
        end
    end
end
inventory = table(relativePath,entryType,bytes,modifiedDatenum,sha256);
for runId = options.ExcludeRunIds.'
    prefix = strip(runId)+"/";
    inventory = inventory(inventory.relativePath~=strip(runId) & ...
        ~startsWith(inventory.relativePath,prefix),:);
end
inventory = sortrows(inventory,["relativePath","entryType"]);
assert(numel(unique(inventory.relativePath))==height(inventory), ...
    "stageA4:a43:HistoricalInventoryDuplicate", ...
    "Historical runs inventory contains duplicate paths.");
end
