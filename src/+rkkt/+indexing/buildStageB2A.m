function index = buildStageB2A(data,config,options)
%BUILDSTAGEB2A Build the canonical Stage B-2A index.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2A_INDEX"
end

index = rkkt.indexing.build_stage_b_index( ...
    data,config,RunId=options.RunId);
end
