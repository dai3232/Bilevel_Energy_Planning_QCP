function thomas = solveDayChain(dayPartition,options)
%SOLVEDAYCHAIN Solve one 24-hour retained chain with multiple RHS.

arguments
    dayPartition (1,1) struct
    options.SymmetryTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

thomas = rkkt.solver.solve_block_thomas_ldl(dayPartition, ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResidualRefinementMaxPasses=options.ResidualRefinementMaxPasses);
end
