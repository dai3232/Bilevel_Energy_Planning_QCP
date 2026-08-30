function baseline = build_stage_b2c_legacy_runtime_audit_package( ...
        data,index,config,identity)
%BUILD_STAGE_B2C_LEGACY_RUNTIME_AUDIT_PACKAGE Build canonical audit baseline.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    identity (1,1) struct
end
template = rkkt.model.build_stage_b2c_recursive_block_template( ...
    data,index,config);
runtime = build_stage_b2c_legacy_runtime_audit_maps( ...
    data,index,template,config);
template.runtime = runtime;
template = remove_fields(template,["index","fixed_zero_map", ...
    "permutation","runtime","config"]);
baseline = struct( ...
    "version","stage-B2C-legacy-runtime-audit-baseline-v1.0", ...
    "schema","stage-b2c-legacy-runtime-audit-cache-v1", ...
    "identity",identity,"scope",runtime.scope,"counts",runtime.counts, ...
    "runtime",runtime,"template",template, ...
    "bootstrap_source","full_canonical_index_audit_object");
assert(~contains_forbidden_field(baseline), ...
    "stageB2C:legacyRuntimeAuditPackage:CanonicalPayload", ...
    "The legacy audit baseline contains a forbidden canonical index field.");
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
