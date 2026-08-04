function result = solveStageB2BRecursiveDirection(linearization,options)
%SOLVESTAGEB2BRECURSIVEDIRECTION Delegate one official B-2B direction.

arguments
    linearization (1,1) struct
    options.SymmetryTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
    options.UseCongruenceScaling (1,1) logical = false
end

require_linearization(linearization, ...
    "rkkt.solver.solveStageB2BRecursiveDirection");
[solverDirectory,productionFile] = production_location( ...
    "solver","solve_stage_b2b_recursive_direction.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("solve_stage_b2b_recursive_direction"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected solve_stage_b2b_recursive_direction at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

result = solve_stage_b2b_recursive_direction(linearization, ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResidualRefinementMaxPasses=options.ResidualRefinementMaxPasses, ...
    UseCongruenceScaling=options.UseCongruenceScaling);
clear pathGuard
end

function require_linearization(linearization,context)
rkkt.contracts.requireFields(linearization,["identity";"milestone_id"], ...
    context+" linearization");
if string(linearization.milestone_id) ~= "B-2B"
    error("rkkt:solver:StageContract", ...
        "%s requires a B-2B linearization.",context);
end
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
