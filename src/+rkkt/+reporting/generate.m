function [reportPaths,validation] = generate(runContext,options)
%GENERATE Delegate Chinese A4 report generation to the production backend.

arguments
    runContext (1,1) struct
    options.OutputDirectory (1,1) string = ""
    options.FinalStatusCandidate (1,1) string = "PASS"
    options.ReportGateMode (1,1) string {mustBeMember( ...
        options.ReportGateMode,["preflight","final"])} = "final"
end

[productionDirectory,productionFile] = production_location( ...
    "reporting","generate_stage_a4_reports.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(productionDirectory,"-begin");
resolved = string(which("generate_stage_a4_reports"));
if ~same_path(resolved,productionFile)
    error("rkkt:reporting:ProductionFunctionShadowed", ...
        ["Expected generate_stage_a4_reports at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
[reportPaths,validation] = generate_stage_a4_reports( ...
    runContext,OutputDirectory=options.OutputDirectory, ...
    FinalStatusCandidate=options.FinalStatusCandidate, ...
    ReportGateMode=options.ReportGateMode);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,string(folder));
file = fullfile(directory,string(fileName));
if ~isfile(file)
    error("rkkt:reporting:ProductionFileMissing", ...
        "Production reporting file is missing: %s",file);
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
