function response = buildDayResponse(dayPartition,thomas)
%BUILDDAYRESPONSE Delegate side-effect-free daily response formation.

arguments
    dayPartition (1,1) struct
    thomas (1,1) struct
end

rkkt.contracts.requireFields(dayPartition,"linearization_identity", ...
    "rkkt.solver.buildDayResponse dayPartition");
rkkt.contracts.requireFields(thomas,"linearization_identity", ...
    "rkkt.solver.buildDayResponse thomas");
[solverDirectory,productionFile] = production_location( ...
    "form_stage_a_multiday_day_response.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("form_stage_a_multiday_day_response"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected form_stage_a_multiday_day_response at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
response = form_stage_a_multiday_day_response(dayPartition,thomas);
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
