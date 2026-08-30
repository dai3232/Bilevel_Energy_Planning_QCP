function fingerprint = build_stage_b2c_structural_topology_fingerprint( ...
        projectRoot,data,config)
%BUILD_STAGE_B2C_STRUCTURAL_TOPOLOGY_FINGERPRINT Hash recursive topology.

% The fingerprint intentionally excludes every numerical model value whose
% change leaves the active-variable topology unchanged.  In particular it
% excludes load, nonzero wind/solar capacity factors, water bounds, costs,
% efficiencies, and the reviewed load-correction identity.

arguments
    projectRoot (1,1) string
    data (1,1) struct
    config (1,1) struct
end
projectRoot = string(java.io.File(char(projectRoot)).getCanonicalPath());
days = reshape(double(config.days),1,[]);
hours = reshape(double(config.hours),1,[]);
assert(isequal(hours,1:24) && string(config.milestone_id)=="B-2C", ...
    "stageB2C:recursiveTopology:Scope", ...
    "The recursive structural topology requires complete B-2C days.");

windActive = data.timeseries.windAvailability(days,hours,:)~=0;
solarActive = data.timeseries.solarAvailability(days,hours,:)~=0;
thermalActive = true(numel(days),numel(hours),data.meta.nThermal);
builderFiles = [ ...
    fullfile(projectRoot,"src","+rkkt","+model", ...
        "build_stage_b2c_structural_topology_fingerprint.m")
    fullfile(projectRoot,"src","+rkkt","+model", ...
        "build_stage_b2c_recursive_structure.m")];
builderHashes = strings(numel(builderFiles),1);
for k = 1:numel(builderFiles)
    builderHashes(k) = rkkt.data.compute_sha256_file(builderFiles(k));
end

descriptor = struct();
descriptor.schema = "stage-b2c-recursive-topology-v1";
descriptor.structural_schema_version = ...
    "stage-B2C-recursive-structure-v1.0";
descriptor.model_contract_version = "1.0";
descriptor.stage_id = "stage_B";
descriptor.milestone_id = "B-2C";
descriptor.days = days;
descriptor.hours = hours;
descriptor.asset_counts = double([data.meta.nWind,data.meta.nSolar, ...
    data.meta.nHydro,data.meta.nThermal,data.meta.nStorage]);
descriptor.wind_active_mask_size = double(size(windActive));
descriptor.wind_active_mask_sha256 = char(hash_logical(windActive));
descriptor.solar_active_mask_size = double(size(solarActive));
descriptor.solar_active_mask_sha256 = char(hash_logical(solarActive));
descriptor.thermal_active_mask_size = double(size(thermalActive));
descriptor.thermal_active_mask_sha256 = char(hash_logical(thermalActive));
descriptor.thermal_pass = "pass_1_all_active";
descriptor.storage_topology = "Pch_Pdis_SOC_two_independent_assets";
descriptor.hydro_topology = "four_hourly_outputs";
descriptor.soc_boundary_mode = char(config.soc_boundary_mode);
descriptor.soc_predecessor_topology = ...
    "hour1_fixed_half_then_previous_hour_no_interday";
descriptor.terminal_soc_topology = "hour24_fixed_half_energy";
descriptor.water_constraints_enabled = ...
    logical(config.water_constraints_enabled);
descriptor.water_rows_per_day = 2*data.meta.nHydro;
descriptor.water_bound_order = cellstr(string(config.water_bound_order));
descriptor.constraint_switches = struct( ...
    "capacity_bounds",true,"wind_solar_bounds",true, ...
    "hydro_hourly_bounds",true,"thermal_pass1_bounds",true, ...
    "storage_bounds",true,"daily_water_bounds", ...
        logical(config.water_constraints_enabled), ...
    "thermal_second_pass",false,"annual_aggregate",false);
descriptor.expected_counts = double([ ...
    config.expected_stage_a_primal_dimension, ...
    config.expected_stage_a_equality_dimension, ...
    config.expected_stage_a_inequality_dimension, ...
    config.expected_water_inequality_count, ...
    config.expected_stage_a_fixed_zero_count, ...
    config.expected_full_kkt_dimension]);
descriptor.structural_builder_hashes = cellstr(lower(builderHashes));

fingerprint = struct( ...
    "version","stage-B2C-structural-topology-fingerprint-v1.0", ...
    "sha256",hash_text(jsonencode(descriptor)), ...
    "descriptor",descriptor);
end

function value = hash_logical(mask)
value = hash_text(char('0'+reshape(uint8(mask),1,[])));
end

function value = hash_text(textValue)
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(unicode2native(char(textValue),"UTF-8"));
bytes = mod(double(engine.digest()),256);
value = lower(string(reshape(dec2hex(bytes,2).',1,[])));
end
