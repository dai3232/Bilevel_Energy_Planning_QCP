function assembly = assembleFullKKT(linearization)
%ASSEMBLEFULLKKT Delegate formal full-KKT assembly to production code.
%   The supplied shared linearization is passed through unchanged.

arguments
    linearization (1,1) struct
end

rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.assembleFullKKT linearization");
[solverDirectory,productionFile] = production_location( ...
    "assemble_stage_a_multiday_full_kkt.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("assemble_stage_a_multiday_full_kkt"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected assemble_stage_a_multiday_full_kkt at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
assembly = assemble_stage_a_multiday_full_kkt(linearization);
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
