function state = initializeStageB2B(data,index,config)
%INITIALIZESTAGEB2B Delegate explicit Stage B-2B state initialization.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

require_inputs(data,index,config,"B-2B", ...
    "rkkt.model.initializeStageB2B");
[modelDirectory,productionFile] = production_location( ...
    "model","initialize_stage_b2b_state.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("initialize_stage_b2b_state"));
if ~same_path(resolved,productionFile)
    error("rkkt:model:ProductionFunctionShadowed", ...
        "Expected initialize_stage_b2b_state at '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end

state = initialize_stage_b2b_state(data,index,config);
clear pathGuard
end

function require_inputs(data,index,config,milestone,context)
rkkt.contracts.requireFields(data,["meta";"base";"timeseries"], ...
    context+" data");
rkkt.contracts.requireFields(index,["scope";"counts"],context+" index");
rkkt.contracts.requireFields(config,["stage_id";"milestone_id"], ...
    context+" config");
if string(config.stage_id) ~= "stage_B" || ...
        string(config.milestone_id) ~= milestone
    error("rkkt:model:StageContract", ...
        "%s requires stage_B / %s configuration.",context,milestone);
end
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,folder);
file = fullfile(directory,fileName);
if ~isfile(file)
    error("rkkt:model:ProductionFileMissing", ...
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
