function state = initialize(data,index,config)
%INITIALIZE Initialize the formal A4 state through the production entry.
%   STATE = RKKT.MODEL.INITIALIZE(DATA,INDEX,CONFIG) delegates exactly once
%   to INITIALIZE_STAGE_A4_STATE and returns its state without modification.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

rkkt.contracts.requireFields(data,"projectRoot", ...
    "rkkt.model.initialize data");
rkkt.contracts.requireFields(index,"scope", ...
    "rkkt.model.initialize index");
rkkt.contracts.requireFields(config,"stage_id", ...
    "rkkt.model.initialize config");
rkkt.contracts.requireTextScalar(data.projectRoot, ...
    "rkkt.model.initialize data.projectRoot");

modelDirectory = fullfile(string(data.projectRoot),"src","model");
productionFile = fullfile(modelDirectory,"initialize_stage_a4_state.m");
if ~isfile(productionFile)
    error("rkkt:model:ProductionFileMissing", ...
        "Production state initializer is missing: %s",productionFile);
end

originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("initialize_stage_a4_state"));
if ~same_path(resolved,productionFile)
    error("rkkt:model:ProductionFunctionShadowed", ...
        "Expected initialize_stage_a4_state at '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end

state = initialize_stage_a4_state(data,index,config);
clear pathGuard
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
