function state = initializeStageB2B(data,index,config)
%INITIALIZESTAGEB2B Build the canonical Stage B-2B initial state.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

state = rkkt.model.initialize_stage_b2b_state(data,index,config);
end
