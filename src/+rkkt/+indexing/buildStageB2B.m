function index = buildStageB2B(data,config,options)
%BUILDSTAGEB2B Delegate explicit Stage B-2B index construction.

arguments
    data (1,1) struct
    config (1,1) struct
    options.RunId (1,1) string = "STAGE_B_2B_INDEX"
end

require_inputs(data,config,"B-2B","rkkt.indexing.buildStageB2B");
[indexDirectory,productionFile] = production_location( ...
    "indexing","build_stage_b2b_index.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(indexDirectory,"-begin");
resolved = string(which("build_stage_b2b_index"));
if ~same_path(resolved,productionFile)
    error("rkkt:indexing:ProductionFunctionShadowed", ...
        "Expected build_stage_b2b_index at '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end

index = build_stage_b2b_index(data,config,RunId=options.RunId);
clear pathGuard
end

function require_inputs(data,config,milestone,context)
rkkt.contracts.requireFields(data,["meta";"base";"timeseries"], ...
    context+" data");
rkkt.contracts.requireFields(config,["stage_id";"milestone_id"], ...
    context+" config");
if string(config.stage_id) ~= "stage_B" || ...
        string(config.milestone_id) ~= milestone
    error("rkkt:indexing:StageContract", ...
        "%s requires stage_B / %s configuration.",context,milestone);
end
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,folder);
file = fullfile(directory,fileName);
if ~isfile(file)
    error("rkkt:indexing:ProductionFileMissing", ...
        "Production indexing file is missing: %s",file);
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
