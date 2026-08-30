function [runtimePackage,info] = ...
        load_or_build_stage_b2c_recursive_runtime_package( ...
        projectRoot,data,config,options)
%LOAD_OR_BUILD_STAGE_B2C_RECURSIVE_RUNTIME_PACKAGE Load compact runtime.

arguments
    projectRoot (1,1) string
    data (1,1) struct
    config (1,1) struct
    options.Enabled (1,1) logical = true
    options.ForceRebuild (1,1) logical = false
    options.BootstrapCanonicalIndexAllowed (1,1) logical = true
end
projectRoot = string(java.io.File(char(projectRoot)).getCanonicalPath());
identity = build_identity(projectRoot,data,config);
key = hash_text(jsonencode(identity));
if numel(config.days)==config.days(end)-config.days(1)+1
    scopeName = compose("days_%03d_%03d",config.days(1),config.days(end));
else
    scopeName = compose("set_%03d_%03d_n%03d", ...
        config.days(1),config.days(end),numel(config.days));
end
cachePath = fullfile(projectRoot,"cache","recursive_runtime", ...
    scopeName+"_"+extractBefore(key,17)+".mat");
info = new_info(options.Enabled,options.ForceRebuild,key,cachePath);

timer = tic;
if options.Enabled && ~options.ForceRebuild && isfile(cachePath)
    loaded = load(cachePath,"runtimePackage","identity");
    assert(isfield(loaded,"runtimePackage") && isfield(loaded,"identity") && ...
        isequaln(loaded.identity,identity), ...
        "rkkt:cache:RecursiveRuntimeIdentity", ...
        "The recursive runtime cache identity changed.");
    runtimePackage = attach_runtime(loaded.runtimePackage,config);
    validate_package(runtimePackage,config);
    info.hit = true;
    info.status = "HIT";
    info.load_seconds = toc(timer);
    info.bytes = file_bytes(cachePath);
    return
end

assert(options.BootstrapCanonicalIndexAllowed, ...
    "rkkt:cache:RecursiveRuntimeBootstrapForbidden", ...
    "The runtime cache is missing and canonical-index bootstrap was forbidden.");
fprintf("%s\n","递推 runtime package 缓存 MISS：进入 "+ ...
    "BOOTSTRAP_BUILD_ONLY；本次将读取 canonical index 构建紧凑包。");
canonicalTimer = tic;
[index,indexInfo] = rkkt.cache.load_or_build_stage_b2c_index( ...
    projectRoot,data,config,Enabled=options.Enabled,ForceRebuild=false);
info.canonical_index_loaded = true;
info.canonical_index_load_seconds = indexInfo.load_seconds;
info.canonical_index_access_seconds = toc(canonicalTimer);
info.canonical_index_cache_status = string(indexInfo.status);
info.canonical_index_cache_path = string(indexInfo.path);
info.bootstrap_mode = "BOOTSTRAP_BUILD_ONLY";

buildTimer = tic;
runtimePackage = rkkt.model.build_stage_b2c_recursive_runtime_package( ...
    data,index,config,identity);
info.build_seconds = toc(buildTimer);
runtimePackage = attach_runtime(runtimePackage,config);
validate_package(runtimePackage,config);
if options.Enabled
    folder = fileparts(cachePath);
    if ~isfolder(folder), mkdir(folder); end
    cachedPackage = detach_runtime(runtimePackage);
    writeTimer = tic;
    rkkt.artifacts.save_mat_artifact(cachePath, ...
        "runtimePackage",cachedPackage,"identity",identity);
    info.write_seconds = toc(writeTimer);
    info.status = "BUILT";
    info.bytes = file_bytes(cachePath);
else
    info.status = "DISABLED_BOOTSTRAP_BUILD";
end
end

function identity = build_identity(projectRoot,data,config)
indexingFiles = [ ...
    fullfile(projectRoot,"src","+rkkt","+indexing", ...
        "build_canonical_index_framework.m")
    fullfile(projectRoot,"src","+rkkt","+indexing","build_stage_b_index.m")
    fullfile(projectRoot,"src","+rkkt","+indexing","build_stage_b2b_index.m")
    fullfile(projectRoot,"src","+rkkt","+indexing","build_stage_b2c_index.m")];
runtimeFiles = [ ...
    fullfile(projectRoot,"src","+rkkt","+model", ...
        "build_stage_b2c_recursive_block_template.m")
    fullfile(projectRoot,"src","+rkkt","+model", ...
        "build_stage_b2c_recursive_runtime_maps.m")
    fullfile(projectRoot,"src","+rkkt","+model", ...
        "build_stage_b2c_recursive_runtime_package.m")];
identity = struct();
identity.schema = "stage-b2c-recursive-runtime-cache-v1";
identity.model_contract_version = "1.0";
identity.days = double(config.days);
identity.hours = double(config.hours);
identity.soc_boundary_mode = char(config.soc_boundary_mode);
identity.time_scope_type = char(config.time_scope_type);
identity.water_constraints_enabled = config.water_constraints_enabled;
identity.water_bound_order = cellstr(string(config.water_bound_order));
identity.thermal_pass = "pass_1";
identity.expected_counts = [config.expected_stage_a_primal_dimension, ...
    config.expected_stage_a_equality_dimension, ...
    config.expected_stage_a_inequality_dimension, ...
    config.expected_water_inequality_count, ...
    config.expected_stage_a_fixed_zero_count, ...
    config.expected_full_kkt_dimension];
identity.input_hashes = cellstr(lower(string(data.hashes.actualSHA256)));
identity.load_correction_sha256 = char(lower(string( ...
    data.load_correction.sha256)));
identity.indexing_builder_hashes = cellstr(file_hashes(indexingFiles));
identity.runtime_builder_hashes = cellstr(file_hashes(runtimeFiles));
end

function value = file_hashes(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    value(k) = rkkt.data.compute_sha256_file(paths(k));
end
end

function value = attach_runtime(value,config)
value.template.config = config;
value.template.runtime = value.runtime;
end

function value = detach_runtime(value)
if isfield(value.template,"config"), value.template=rmfield(value.template,"config"); end
if isfield(value.template,"runtime"), value.template=rmfield(value.template,"runtime"); end
end

function validate_package(value,config)
forbidden = ["index","stage_a_base_index","variable_index", ...
    "constraint_index","permutation_map"];
assert(string(value.version)== ...
        "stage-B2C-recursive-runtime-package-v1.0" && ...
    string(value.runtime.version)== ...
        "stage-B2C-compact-recursive-runtime-v1.0" && ...
    string(value.template.version)== ...
        "stage-B2C-recursive-block-template-v1.0" && ...
    isequal(double(value.scope.days),double(config.days)) && ...
    isequal(double(value.scope.hours),double(config.hours)) && ...
    value.counts.variables==config.expected_stage_a_primal_dimension && ...
    value.counts.equalities==config.expected_stage_a_equality_dimension && ...
    value.counts.base_inequalities== ...
        config.expected_stage_a_inequality_dimension && ...
    value.counts.water_inequalities== ...
        config.expected_water_inequality_count && ...
    value.counts.fixed_zero==config.expected_stage_a_fixed_zero_count && ...
    value.counts.full_kkt_dimension==config.expected_full_kkt_dimension && ...
    ~has_forbidden(value,forbidden), ...
    "rkkt:cache:RecursiveRuntimePayload", ...
    "The recursive runtime package failed its compact payload contract.");
end

function found = has_forbidden(value,forbidden)
found = false;
if ~isstruct(value), return; end
for item = reshape(value,1,[])
    names = string(fieldnames(item));
    if any(ismember(names,forbidden)), found=true; return; end
    for k = 1:numel(names)
        child = item.(names(k));
        if isstruct(child) && has_forbidden(child,forbidden)
            found=true; return
        end
    end
end
end

function info = new_info(enabled,force,key,pathValue)
info = struct("cache_type","recursive_runtime_package", ...
    "enabled",enabled,"force_rebuild",force,"hit",false, ...
    "status","MISS","key",string(key),"path",string(pathValue), ...
    "load_seconds",0,"build_seconds",0,"write_seconds",0,"bytes",0, ...
    "canonical_index_loaded",false,"canonical_index_load_seconds",0, ...
    "canonical_index_access_seconds",0, ...
    "canonical_index_cache_status","NOT_ACCESSED", ...
    "canonical_index_cache_path","","bootstrap_mode","NONE");
end

function value = file_bytes(pathValue)
listing = dir(pathValue);
assert(isscalar(listing),"rkkt:cache:RecursiveRuntimeFile", ...
    "The recursive runtime cache file is missing after write.");
value = double(listing.bytes);
end

function value = hash_text(textValue)
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(unicode2native(char(textValue),"UTF-8"));
bytes = mod(double(engine.digest()),256);
value = lower(string(reshape(dec2hex(bytes,2).',1,[])));
end
