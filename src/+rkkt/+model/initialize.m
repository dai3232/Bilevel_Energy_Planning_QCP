function state = initialize(data,index,config)
%INITIALIZE Build the canonical Stage-A4 initial state.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

state = rkkt.model.initialize_stage_a4_state(data,index,config);
end
