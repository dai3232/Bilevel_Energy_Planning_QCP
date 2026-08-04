function result = evaluateStageBDailyHydroWater( ...
        powerMW,waterA,waterB,waterC)
%EVALUATESTAGEBDAILYHYDROWATER Delegate one plant-day water evaluation.

arguments
    powerMW (24,1) double {mustBeReal,mustBeFinite}
    waterA (1,1) double {mustBeReal,mustBeFinite}
    waterB (1,1) double {mustBeReal,mustBeFinite}
    waterC (1,1) double {mustBeReal,mustBeFinite}
end

[modelDirectory,productionFile] = production_location( ...
    "model","evaluate_stage_b_daily_hydro_water.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("evaluate_stage_b_daily_hydro_water"));
if ~same_path(resolved,productionFile)
    error("rkkt:data:ProductionFunctionShadowed", ...
        ["Expected evaluate_stage_b_daily_hydro_water at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

result = evaluate_stage_b_daily_hydro_water( ...
    powerMW,waterA,waterB,waterC);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,folder);
file = fullfile(directory,fileName);
if ~isfile(file)
    error("rkkt:data:ProductionFileMissing", ...
        "Production model file is missing: %s",file);
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
