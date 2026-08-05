function exported = export( ...
        runContext,data,index,finalState,physicalAudit,options)
%EXPORT Persist the final A4 result artifacts.

arguments
    runContext (1,1) struct
    data (1,1) struct
    index (1,1) struct
    finalState (1,1) struct
    physicalAudit table
    options.SolvePass (1,1) string = "pass_1"
    options.PhysicalTolerance (1,1) double ...
        {mustBeFinite,mustBeNonnegative} = 1.0e-8
end

exported = rkkt.artifacts.export_stage_a4_result_artifacts( ...
    runContext,data,index,finalState,physicalAudit, ...
    SolvePass=options.SolvePass, ...
    PhysicalTolerance=options.PhysicalTolerance);
end
