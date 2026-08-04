function result = solveStageB2BFullKKTDirection(linearization)
%SOLVESTAGEB2BFULLKKTDIRECTION Delegate the independent B-2B audit solve.

arguments
    linearization (1,1) struct
end

rkkt.contracts.requireFields(linearization,["identity";"milestone_id"], ...
    "rkkt.solver.solveStageB2BFullKKTDirection linearization");
if string(linearization.milestone_id) ~= "B-2B"
    error("rkkt:solver:StageContract", ...
        "solveStageB2BFullKKTDirection requires a B-2B linearization.");
end

[solverDirectory,productionFile] = production_location( ...
    "solver","solve_stage_b2b_full_kkt_direction.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("solve_stage_b2b_full_kkt_direction"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected solve_stage_b2b_full_kkt_direction at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

result = solve_stage_b2b_full_kkt_direction(linearization);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,folder);
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
