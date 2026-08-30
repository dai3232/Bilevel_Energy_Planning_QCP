function runtimePackage = build_stage_b2c_recursive_runtime_package( ...
        data,index,config,identity)
%BUILD_STAGE_B2C_RECURSIVE_RUNTIME_PACKAGE Build compact production payload.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    identity (1,1) struct
end
template = rkkt.model.build_stage_b2c_recursive_block_template( ...
    data,index,config);
runtime = template.runtime;
template = remove_fields(template,["index","fixed_zero_map", ...
    "permutation","runtime","config"]);
runtimePackage = struct( ...
    "version","stage-B2C-recursive-runtime-package-v1.0", ...
    "schema","stage-b2c-recursive-runtime-cache-v1", ...
    "identity",identity,"scope",runtime.scope,"counts",runtime.counts, ...
    "runtime",runtime,"template",template, ...
    "bootstrap_source","full_canonical_index_audit_object");
assert(~contains_forbidden_field(runtimePackage), ...
    "stageB2C:runtimePackage:CanonicalPayload", ...
    "The compact runtime package contains a forbidden canonical index field.");
end

function value = remove_fields(value,names)
present = names(isfield(value,cellstr(names)));
if ~isempty(present), value = rmfield(value,cellstr(present)); end
end

function found = contains_forbidden_field(value)
found = false;
if ~isstruct(value), return; end
for item = reshape(value,1,[])
    names = string(fieldnames(item));
    if any(ismember(names,["index","stage_a_base_index", ...
            "variable_index","constraint_index","permutation_map"]))
        found = true;
        return
    end
    for k = 1:numel(names)
        child = item.(names(k));
        if isstruct(child) && contains_forbidden_field(child)
            found = true;
            return
        end
    end
end
end
