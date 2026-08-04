function linearization = linearizeStageB2A(state,data,index,config)
%LINEARIZESTAGEB2A Delegate explicit Stage B-2A linearization.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

require_inputs(state,data,index,config,"B-2A", ...
    "rkkt.model.linearizeStageB2A");
[modelDirectory,productionFile] = production_location( ...
    "model","build_stage_b_multiday_linearization.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("build_stage_b_multiday_linearization"));
if ~same_path(resolved,productionFile)
    error("rkkt:model:ProductionFunctionShadowed", ...
        ["Expected build_stage_b_multiday_linearization at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

linearization = build_stage_b_multiday_linearization( ...
    state,data,index,config);
clear pathGuard
end

function require_inputs(state,data,index,config,milestone,context)
rkkt.contracts.requireFields(state,["xi";"y";"l";"z";"milestone_id"], ...
    context+" state");
rkkt.contracts.requireFields(data,["meta";"base";"timeseries"], ...
    context+" data");
rkkt.contracts.requireFields(index,["scope";"counts"],context+" index");
rkkt.contracts.requireFields(config,["stage_id";"milestone_id"], ...
    context+" config");
if string(config.stage_id) ~= "stage_B" || ...
        string(config.milestone_id) ~= milestone || ...
        string(state.milestone_id) ~= milestone
    error("rkkt:model:StageContract", ...
        "%s requires matching stage_B / %s inputs.",context,milestone);
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
