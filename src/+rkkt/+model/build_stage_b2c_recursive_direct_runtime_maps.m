function runtime = build_stage_b2c_recursive_direct_runtime_maps(data,config)
%BUILD_STAGE_B2C_RECURSIVE_DIRECT_RUNTIME_MAPS Build maps without an index.

% Canonical-index audit templates still need the compact recovery metadata.
% Rebuild that metadata through the formal direct structural builder so the
% retained audit template never depends on legacy tools or canonical map
% compression.

arguments
    data (1,1) struct
    config (1,1) struct
end
fingerprint = struct( ...
    "version","stage-B2C-structural-topology-fingerprint-v1.0", ...
    "sha256","uncached-direct-runtime-maps", ...
    "descriptor",struct("purpose","uncached_direct_runtime_maps"));
structure = rkkt.model.build_stage_b2c_recursive_structure( ...
    data,config,fingerprint);
runtime = structure.runtime;
end
