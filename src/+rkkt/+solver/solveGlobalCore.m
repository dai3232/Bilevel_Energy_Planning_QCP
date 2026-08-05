function core = solveGlobalCore(partition,aggregation,options)
%SOLVEGLOBALCORE Solve the retained 16-dimensional global core.

arguments
    partition (1,1) struct
    aggregation (1,1) struct
    options.SymmetryTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

core = rkkt.solver.solve_stage_a_multiday_core16_ldl( ...
    partition,aggregation, ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResidualRefinementMaxPasses=options.ResidualRefinementMaxPasses);
end
