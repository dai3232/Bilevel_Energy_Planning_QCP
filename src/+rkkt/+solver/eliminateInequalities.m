function reduced = eliminateInequalities(linearization)
%ELIMINATEINEQUALITIES Delegate exact inequality elimination to production.
%   This facade forms no recursive partition and solves no reduced system.

arguments
    linearization (1,1) struct
end

rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.eliminateInequalities linearization");
[solverDirectory,productionFile] = production_location( ...
    "eliminate_stage_a_multiday_inequality_directions.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which( ...
    "eliminate_stage_a_multiday_inequality_directions"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected eliminate_stage_a_multiday_inequality_directions " ...
        "at '%s'; MATLAB resolved '%s'."],productionFile,resolved);
end
reduced = eliminate_stage_a_multiday_inequality_directions( ...
    linearization);
clear pathGuard
end

function [directory,file] = production_location(fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
rkktDirectory = string(fileparts(packageDirectory));
sourceDirectory = string(fileparts(rkktDirectory));
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
