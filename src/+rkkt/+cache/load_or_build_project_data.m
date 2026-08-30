function [data,info] = load_or_build_project_data(projectRoot,options)
%LOAD_OR_BUILD_PROJECT_DATA Reuse the parsed annual controlled inputs.

arguments
    projectRoot (1,1) string = rkkt.projectRoot()
    options.Enabled (1,1) logical = true
    options.ForceRebuild (1,1) logical = false
    options.LoadCorrectionPath (1,1) string = ""
end
projectRoot = canonical_path(projectRoot);
[hashes,passed] = rkkt.data.verify_input_hashes(projectRoot);
assert(passed,"rkkt:cache:InputHash", ...
    "Controlled input hashes do not match their authority values.");
loaderFiles = [ ...
    fullfile(projectRoot,"src","+rkkt","+data","load_project_data.m")
    fullfile(projectRoot,"src","+rkkt","+data","locate_labeled_table.m")
    fullfile(projectRoot,"src","+rkkt","+data", ...
        "apply_stage_b2c_load_corrections.m")];
correctionIdentity = resolve_correction(options.LoadCorrectionPath);
identity = struct( ...
    "schema","annual-project-data-cache-v2", ...
    "input_hashes",join_hashes(hashes), ...
    "load_correction_enabled",correctionIdentity.enabled, ...
    "load_correction_sha256",char(correctionIdentity.sha256), ...
    "loader_hashes",cellstr(source_hashes(loaderFiles)));
key = hash_text(jsonencode(identity));
cachePath = fullfile(projectRoot,"cache","data", ...
    "annual_project_data_"+extractBefore(key,17)+".mat");
info = new_info(options.Enabled,options.ForceRebuild,key,cachePath, ...
    correctionIdentity);

timer = tic;
if options.Enabled && ~options.ForceRebuild && isfile(cachePath)
    loaded = load(cachePath,"data","identity");
    assert(isfield(loaded,"data") && isfield(loaded,"identity") && ...
        isequaln(loaded.identity,identity), ...
        "rkkt:cache:DataIdentity", ...
        "The annual data cache does not match its file identity.");
    data = loaded.data;
    validate_data(data,hashes,correctionIdentity);
    info.hit = true;
    info.status = "HIT";
    info.load_seconds = toc(timer);
    return
end

data = rkkt.data.load_project_data(projectRoot);
if correctionIdentity.enabled
    [data,~] = rkkt.data.apply_stage_b2c_load_corrections( ...
        data,correctionIdentity.path);
else
    data.load_correction = disabled_correction();
end
validate_data(data,hashes,correctionIdentity);
info.build_seconds = toc(timer);
if options.Enabled
    writeTimer = tic;
    rkkt.artifacts.save_mat_artifact(cachePath, ...
        "data",data,"identity",identity);
    info.write_seconds = toc(writeTimer);
    info.status = "BUILT";
else
    info.status = "DISABLED";
end
end

function validate_data(data,hashes,correctionIdentity)
assert(string(data.schemaVersion)=="stage0-data-v1.0" && ...
    data.meta.nDays==365 && data.meta.nHours==24 && ...
    isequal(lower(string(data.hashes.actualSHA256)), ...
        lower(string(hashes.actualSHA256))) && ...
    isfield(data,"load_correction") && ...
    logical(data.load_correction.enabled)==correctionIdentity.enabled && ...
    lower(string(data.load_correction.sha256))== ...
        lower(string(correctionIdentity.sha256)), ...
    "rkkt:cache:DataPayload", ...
    "The cached annual data payload failed its controlled identity check.");
end

function value = join_hashes(hashes)
[~,order] = sort(string(hashes.fileName));
value = char(strjoin(lower(string(hashes.actualSHA256(order))),"|"));
end

function value = source_hashes(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    value(k) = rkkt.data.compute_sha256_file(paths(k));
end
end

function info = new_info(enabled,force,key,pathValue,correction)
info = struct("cache_type","annual_data","enabled",enabled, ...
    "force_rebuild",force,"hit",false,"status","MISS", ...
    "key",string(key),"path",string(pathValue), ...
    "load_seconds",0,"build_seconds",0,"write_seconds",0, ...
    "load_correction_enabled",correction.enabled, ...
    "load_correction_path",correction.path, ...
    "load_correction_sha256",correction.sha256);
end

function value = resolve_correction(pathValue)
if strlength(strip(pathValue))==0
    value = disabled_correction();
    return
end
pathValue = canonical_path(pathValue);
assert(isfile(pathValue),"rkkt:cache:LoadCorrectionMissing", ...
    "The configured load-correction table is missing: %s",pathValue);
value = struct("enabled",true,"path",pathValue, ...
    "sha256",rkkt.data.compute_sha256_file(pathValue));
end

function value = disabled_correction()
value = struct("version","stage-B2C-reviewed-load-correction-v1.0", ...
    "enabled",false,"path","","sha256","NONE","row_count",0, ...
    "days",zeros(1,0),"day_count",0,"total_reduction_mwh",0, ...
    "maximum_single_hour_reduction_mw",0,"rounding_mw",10, ...
    "water_coupled_feasibility_certified",false);
end

function value = hash_text(textValue)
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(unicode2native(char(textValue),"UTF-8"));
bytes = mod(double(engine.digest()),256);
value = lower(string(reshape(dec2hex(bytes,2).',1,[])));
end

function value = canonical_path(pathValue)
value = string(java.io.File(char(pathValue)).getCanonicalPath());
end
