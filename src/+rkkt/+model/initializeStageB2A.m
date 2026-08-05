function state = initializeStageB2A(data,index,config)
%INITIALIZESTAGEB2A Build the canonical Stage B-2A initial state.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

state = rkkt.model.initialize_stage_b2a_state(data,index,config);
end
