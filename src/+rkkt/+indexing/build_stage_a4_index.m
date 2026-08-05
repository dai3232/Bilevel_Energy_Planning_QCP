function index = build_stage_a4_index(data,config,options)
%BUILD_STAGE_A4_INDEX Build the formal seven-day A4 canonical index.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_A4_INDEX"
end

index = rkkt.indexing.build_stage_a_multiday_index(data,config,"RunId",options.RunId);
if string(index.scope.stage_id) ~= "stage_A4" || ...
        index.counts.full_kkt_dimension ~= 18836 || ...
        index.counts.fixed_zero ~= 422
    error("stageA4:index:Identity", ...
        "The A4 canonical index identity or controlled counts are invalid.");
end
end
