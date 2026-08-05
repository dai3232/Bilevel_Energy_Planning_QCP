function index = build(data,config,options)
%BUILD Build the canonical seven-day Stage-A4 index.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_A4_INDEX"
end

index = rkkt.indexing.build_stage_a4_index( ...
    data,config,RunId=options.RunId);
end
