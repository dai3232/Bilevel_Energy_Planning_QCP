function aggregation = aggregateDayResponses(responses,expectedDays)
%AGGREGATEDAYRESPONSES Delegate fixed-order seven-day aggregation.

arguments
    responses (:,1) struct
    expectedDays (1,:) double = 14:20
end

[solverDirectory,productionFile] = production_location( ...
    "aggregate_stage_a_multiday_day_responses.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("aggregate_stage_a_multiday_day_responses"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected aggregate_stage_a_multiday_day_responses at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
aggregation = aggregate_stage_a_multiday_day_responses( ...
    responses,expectedDays);
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
