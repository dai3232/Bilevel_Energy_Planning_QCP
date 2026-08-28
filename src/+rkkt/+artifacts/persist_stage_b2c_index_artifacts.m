function persist_stage_b2c_index_artifacts(context,index)
%PERSIST_STAGE_B2C_INDEX_ARTIFACTS Persist the canonical index evidence.

arguments
    context (1,1) struct
    index (1,1) struct
end
index = rkkt.artifacts.retag_index_run_id(index,string(context.run_id));
names = ["variable_index","constraint_index","block_index", ...
    "fixed_zero_map","permutation_map","soc_link_map", ...
    "water_constraint_index"];
for name = names
    pathValue = fullfile(context.indices_dir,name+".csv");
    assert(~isfile(pathValue) && ~isfolder(pathValue), ...
        "stageB2C:index:ArtifactExists", ...
        "Refusing to overwrite %s.",pathValue);
    rkkt.artifacts.write_table_csv_17g(pathValue,index.(name));
end
end
