function exported = export( ...
        runContext,data,index,finalState,physicalAudit,options)
%EXPORT Delegate final A4 result persistence to the production backend.

arguments
    runContext (1,1) struct
    data (1,1) struct
    index (1,1) struct
    finalState (1,1) struct
    physicalAudit table
    options.SolvePass (1,1) string = "pass_1"
    options.PhysicalTolerance (1,1) double ...
        {mustBeFinite,mustBeNonnegative} = 1.0e-8
end

[productionDirectory,productionFile] = production_location( ...
    "artifacts","export_stage_a4_result_artifacts.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(productionDirectory,"-begin");
resolved = string(which("export_stage_a4_result_artifacts"));
if ~same_path(resolved,productionFile)
    error("rkkt:artifacts:ProductionFunctionShadowed", ...
        ["Expected export_stage_a4_result_artifacts at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
exported = export_stage_a4_result_artifacts( ...
    runContext,data,index,finalState,physicalAudit, ...
    SolvePass=options.SolvePass, ...
    PhysicalTolerance=options.PhysicalTolerance);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,string(folder));
file = fullfile(directory,string(fileName));
if ~isfile(file)
    error("rkkt:artifacts:ProductionFileMissing", ...
        "Production artifact file is missing: %s",file);
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
