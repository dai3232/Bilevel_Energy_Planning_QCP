function partition = partition_stage_a3_recursive_system(lin,reduced,options)
%PARTITION_STAGE_A3_RECURSIVE_SYSTEM Backward-compatible A3 wrapper.
arguments
    lin (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
end
assert(string(lin.stage_id)=="stage_A3","stageA3:solver:StageId", ...
    "The stage_A3 partition wrapper requires a stage_A3 linearization.");
partition = partition_stage_a_multiday_recursive_system(lin,reduced, ...
    AssemblyTolerance=options.AssemblyTolerance);
end
