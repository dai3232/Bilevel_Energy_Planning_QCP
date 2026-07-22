function result = solve_stage_a3_recursive_direction(lin,options)
%SOLVE_STAGE_A3_RECURSIVE_DIRECTION Backward-compatible A3 wrapper.
arguments
    lin (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
end
assert(string(lin.stage_id)=="stage_A3","stageA3:solver:StageId", ...
    "The stage_A3 recursive wrapper requires a stage_A3 linearization.");
result = solve_stage_a_multiday_recursive_direction(lin, ...
    AssemblyTolerance=options.AssemblyTolerance, ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResponseInputOrder=[4,1,7,2,6,3,5]);
end
