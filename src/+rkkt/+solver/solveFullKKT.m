function result = solveFullKKT(linearization)
%SOLVEFULLKKT Delegate the sparse full-KKT audit direction to production.
%   The result is an audit baseline only; this facade updates no state.

arguments
    linearization (1,1) struct
end

rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.solveFullKKT linearization");
[solverDirectory,productionFile] = production_location( ...
    "solve_stage_a_multiday_full_kkt_direction.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("solve_stage_a_multiday_full_kkt_direction"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected solve_stage_a_multiday_full_kkt_direction at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
result = solve_stage_a_multiday_full_kkt_direction(linearization);
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
