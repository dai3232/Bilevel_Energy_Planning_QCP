function partition = partitionRecursiveSystem(linearization,reduced,options)
%PARTITIONRECURSIVESYSTEM Partition the seven-day reduced system.

arguments
    linearization (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
end

partition = rkkt.solver.partition_stage_a_multiday_recursive_system( ...
    linearization,reduced,AssemblyTolerance=options.AssemblyTolerance);
end
