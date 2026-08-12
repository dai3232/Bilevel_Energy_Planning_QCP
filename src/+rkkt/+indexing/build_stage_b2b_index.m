function index = build_stage_b2b_index(data,config,options)
%BUILD_STAGE_B2B_INDEX Reuse and retag the frozen B-2A canonical extension.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2B_INDEX"
end
assert(string(config.milestone_id)=="B-2B", ...
    "stageB2B:index:Milestone","B-2B configuration is required.");
index = rkkt.indexing.build_stage_b_index(data,config,"RunId",options.RunId);
index.version = "stage-B2B-water-index-v1.0";
index.scope.milestone_id = "B-2B";
index.scope.run_purpose = config.run_purpose;
index.water_constraint_index.milestone_id(:) = "B-2B";
assert(height(index.water_constraint_index)== ...
        config.expected_water_inequality_count && ...
    index.counts.full_kkt_dimension==config.expected_full_kkt_dimension, ...
    "stageB2B:index:Dimensions","The B-2B canonical index changed.");
end
