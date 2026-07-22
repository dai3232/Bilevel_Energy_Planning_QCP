function linearization = build_stage_a3_linearization(state,data,index,config)
%BUILD_STAGE_A3_LINEARIZATION Preserve the validated A3 public interface.

if string(config.stage_id) ~= "stage_A3"
    error("stageA3:linearization:StageId", ...
        "build_stage_a3_linearization requires a stage_A3 configuration.");
end
linearization = build_stage_a_multiday_linearization( ...
    state,data,index,config,"SlackMode","initialize");
end
