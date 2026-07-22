function state = initialize_stage_a3_state(data,index,config)
%INITIALIZE_STAGE_A3_STATE Preserve the validated A3 public initializer.

if string(config.stage_id) ~= "stage_A3"
    error("stageA3:state:StageId", ...
        "initialize_stage_a3_state requires a stage_A3 configuration.");
end
state = initialize_stage_a_multiday_state(data,index,config);
end
