function entry = update_run_index(runContext,manifest)
%UPDATE_RUN_INDEX Register one immutable run in the compact history view.

arguments
    runContext (1,1) struct
    manifest (1,1) struct
end

requiredContext = ["runs_root","root","run_id","stage_id", ...
    "effective_config_path","project_root"];
requiredManifest = ["run_id","stage_id","status","started_at", ...
    "git_commit","input_hashes"];
assert(all(isfield(runContext,requiredContext)) && ...
    all(isfield(manifest,requiredManifest)), ...
    "rkkt:runs:IndexContract","Run index input is incomplete.");
assert(string(runContext.run_id)==string(manifest.run_id) && ...
    string(runContext.stage_id)==string(manifest.stage_id), ...
    "rkkt:runs:IndexIdentity", ...
    "Run context and manifest identities differ.");

runsRoot = string(runContext.runs_root);
assert(isfolder(runsRoot),"rkkt:runs:IndexRoot", ...
    "The runs directory does not exist: %s",runsRoot);
indexPath = fullfile(runsRoot,"运行索引.csv");
latestPath = fullfile(runsRoot,"LATEST_PASS.json");

configSha256 = rkkt.data.compute_sha256_file( ...
    string(runContext.effective_config_path));
codeSignature = package_code_signature(string(runContext.project_root));
inputSignature = sha256_text(jsonencode(orderfields(manifest.input_hashes)));
runSignature = sha256_text(strjoin([ ...
    string(manifest.stage_id)
    lower(string(codeSignature))
    lower(string(configSha256))
    lower(string(inputSignature))],"|"));

if isfile(indexPath)
    index = readtable(indexPath,"TextType","string", ...
        "VariableNamingRule","preserve","Delimiter",",");
    assert(isequal(string(index.Properties.VariableNames), ...
        index_columns()),"rkkt:runs:IndexSchema", ...
        "runs/运行索引.csv has an unexpected schema.");
else
    index = empty_index();
end

runId = string(manifest.run_id);
index(index.run_id==runId,:) = [];
prior = index(index.run_signature==runSignature & index.status=="PASS",:);
if isempty(prior)
    repeatClass = "ORIGINAL";
    repeatOf = "";
else
    prior = sortrows(prior,["started_at","run_id"]);
    repeatClass = "REPEAT";
    repeatOf = prior.run_id(1);
end

endedAt = text_field(manifest,"ended_at");
iterationCount = numeric_field(manifest,"iteration_count");
elapsedSeconds = numeric_field(manifest,"elapsed_seconds");
entry = table(runId,string(manifest.stage_id), ...
    string(manifest.status),string(manifest.started_at),endedAt, ...
    lower(string(manifest.git_commit)),lower(string(codeSignature)), ...
    lower(string(configSha256)),lower(string(inputSignature)), ...
    lower(string(runSignature)), ...
    repeatClass,repeatOf,iterationCount,elapsedSeconds, ...
    "runs/"+runId, ...
    'VariableNames',cellstr(index_columns()));
index = [index;entry];
index = sortrows(index,["started_at","run_id"]);
rkkt.artifacts.write_table_csv_17g_atomic(indexPath,index);

passed = index(index.status=="PASS",:);
if ~isempty(passed)
    passed = sortrows(passed,["ended_at","run_id"]);
    latest = passed(end,:);
    pointer = struct( ...
        "run_id",char(latest.run_id), ...
        "stage_id",char(latest.stage_id), ...
        "status","PASS", ...
        "git_commit",char(latest.git_commit), ...
        "code_signature",char(latest.code_signature), ...
        "run_signature",char(latest.run_signature), ...
        "repeat_class",char(latest.repeat_class), ...
        "run_path",char(latest.run_path), ...
        "ended_at",char(latest.ended_at));
    rkkt.artifacts.write_json_file(latestPath,pointer);
end
end

function value = empty_index()
value = table(strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),zeros(0,1),zeros(0,1),strings(0,1), ...
    'VariableNames',cellstr(index_columns()));
end

function value = index_columns()
value = ["run_id","stage_id","status","started_at","ended_at", ...
    "git_commit","code_signature","config_sha256","input_signature", ...
    "run_signature","repeat_class","repeat_of_run_id","iteration_count", ...
    "elapsed_seconds","run_path"];
end

function value = package_code_signature(projectRoot)
packageRoot = fullfile(projectRoot,"src","+rkkt");
assert(isfolder(packageRoot),"rkkt:runs:PackageRoot", ...
    "The rkkt package directory does not exist: %s",packageRoot);
files = dir(fullfile(packageRoot,"**","*.m"));
files = files(~[files.isdir]);
assert(~isempty(files),"rkkt:runs:PackageFiles", ...
    "The rkkt package contains no MATLAB source files.");

rootCanonical = canonical_path(projectRoot);
relativePath = strings(numel(files),1);
sha256 = strings(numel(files),1);
for k = 1:numel(files)
    absolute = canonical_path(fullfile(files(k).folder,files(k).name));
    relativePath(k) = replace(extractAfter(absolute, ...
        strlength(rootCanonical)+1),"\","/");
    sha256(k) = rkkt.data.compute_sha256_file(absolute);
end
[relativePath,order] = sort(relativePath);
sha256 = sha256(order);
value = sha256_text(strjoin(relativePath+"="+lower(sha256),newline));
end

function value = text_field(source,name)
if ~isfield(source,name) || isempty(source.(name))
    value = "";
else
    value = string(source.(name));
end
end

function value = numeric_field(source,name)
if ~isfield(source,name) || isempty(source.(name))
    value = NaN;
else
    value = double(source.(name));
end
end

function value = sha256_text(textValue)
digest = java.security.MessageDigest.getInstance("SHA-256");
bytes = unicode2native(char(textValue),"UTF-8");
byteVector = typecast(uint8(bytes(:)),"int8");
digest.update(byteVector,0,int32(numel(byteVector)));
digestBytes = mod(double(digest.digest()),256);
value = lower(join(compose("%02x",digestBytes),""));
value = reshape(value,1,1);
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end
