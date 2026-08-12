function index = build_stage_b2c_index(data,config,options)
%BUILD_STAGE_B2C_INDEX Retag the audited Stage-B water extension for B-2C.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2C_INDEX"
end
assert(string(config.milestone_id)=="B-2C", ...
    "stageB2C:index:Milestone","B-2C configuration is required.");
compat = config;
compat.milestone_id = "B-2B";
compat.run_purpose = "stage_B_2C_index_compatibility_build";
index = rkkt.indexing.build_stage_b2b_index(data,compat,"RunId",options.RunId);
index.version = "stage-B2C-water-index-v1.0";
index.scope.milestone_id = "B-2C";
index.scope.run_purpose = config.run_purpose;
index.water_constraint_index.milestone_id(:) = "B-2C";
assert(height(index.water_constraint_index)== ...
        config.expected_water_inequality_count && ...
    index.counts.full_kkt_dimension==config.expected_full_kkt_dimension && ...
    height(index.fixed_zero_map)==config.expected_stage_a_fixed_zero_count, ...
    "stageB2C:index:Dimensions","The B-2C canonical index changed.");
end
