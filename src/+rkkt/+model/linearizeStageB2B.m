function linearization = linearizeStageB2B(state,data,index,config)
%LINEARIZESTAGEB2B Build the shared Stage B-2B linearization.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

linearization = rkkt.model.build_stage_b2b_multiday_linearization( ...
    state,data,index,config);
end
