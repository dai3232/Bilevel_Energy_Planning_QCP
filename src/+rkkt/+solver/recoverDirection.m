function recovery = recoverDirection( ...
        linearization,partition,responses,core)
%RECOVERDIRECTION Delegate strict reverse-order canonical recovery.

arguments
    linearization (1,1) struct
    partition (1,1) struct
    responses (:,1) struct
    core (1,1) struct
end

rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.recoverDirection linearization");
rkkt.contracts.requireFields(partition,"linearization_identity", ...
    "rkkt.solver.recoverDirection partition");
rkkt.contracts.requireFields(core,"linearization_identity", ...
    "rkkt.solver.recoverDirection core");
[solverDirectory,productionFile] = production_location( ...
    "recover_stage_a_multiday_recursive_direction.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which( ...
    "recover_stage_a_multiday_recursive_direction"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected recover_stage_a_multiday_recursive_direction " ...
        "at '%s'; MATLAB resolved '%s'."],productionFile,resolved);
end
recovery = recover_stage_a_multiday_recursive_direction( ...
    linearization,partition,responses,core);
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
