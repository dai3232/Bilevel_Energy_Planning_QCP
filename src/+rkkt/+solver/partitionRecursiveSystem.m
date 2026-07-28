function partition = partitionRecursiveSystem(linearization,reduced,options)
%PARTITIONRECURSIVESYSTEM Delegate seven-day recursive partitioning.

arguments
    linearization (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
end

rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.partitionRecursiveSystem linearization");
rkkt.contracts.requireFields(reduced,"linearization_identity", ...
    "rkkt.solver.partitionRecursiveSystem reduced");
[solverDirectory,productionFile] = production_location( ...
    "partition_stage_a_multiday_recursive_system.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("partition_stage_a_multiday_recursive_system"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected partition_stage_a_multiday_recursive_system at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
partition = partition_stage_a_multiday_recursive_system( ...
    linearization,reduced,AssemblyTolerance=options.AssemblyTolerance);
clear pathGuard
end

function [directory,file] = production_location(fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,"solver");
file = fullfile(directory,fileName);
if ~isfile(file)
    error("rkkt:solver:ProductionFileMissing", ...
        "Production solver file is missing: %s",file);
end
end

function value = same_path(left,right)
left = replace(string(left),"/","\");
right = replace(string(right),"/","\");
if ispc
    value = strcmpi(left,right);
else
    value = strcmp(left,right);
end
end
