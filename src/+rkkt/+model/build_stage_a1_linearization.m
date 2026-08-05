function linearization = build_stage_a1_linearization(state,data,index,config)
%BUILD_STAGE_A1_LINEARIZATION Compatibility wrapper for the shared model.
linearization = rkkt.model.build_stage_a_linearization(state,data,index,config);
end
