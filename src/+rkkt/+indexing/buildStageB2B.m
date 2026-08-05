function index = buildStageB2B(data,config,options)
%BUILDSTAGEB2B Build the canonical Stage B-2B index.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2B_INDEX"
end

index = rkkt.indexing.build_stage_b2b_index( ...
    data,config,RunId=options.RunId);
end
