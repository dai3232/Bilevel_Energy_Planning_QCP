function linearization = linearize(state,data,index,config)
%LINEARIZE Build the shared Stage-A4 linearization.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

linearization = rkkt.model.build_stage_a4_linearization( ...
    state,data,index,config);
end
