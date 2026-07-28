function linearization = linearize(state,data,index,config)
%LINEARIZE Build the shared A4 linearization from the caller's state.
%   LINEARIZATION = RKKT.MODEL.LINEARIZE(STATE,DATA,INDEX,CONFIG) delegates
%   exactly once to BUILD_STAGE_A4_LINEARIZATION. STATE is passed directly;
%   this facade never initializes or alters it.

arguments
    state (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
end

rkkt.contracts.requireFields(state, ...
    ["xi";"y";"l";"z";"stage_id";"iteration_index";"state_revision"], ...
    "rkkt.model.linearize state");
rkkt.contracts.requireFields(data,"projectRoot", ...
    "rkkt.model.linearize data");
rkkt.contracts.requireFields(index,"scope", ...
    "rkkt.model.linearize index");
rkkt.contracts.requireFields(config,"stage_id", ...
    "rkkt.model.linearize config");
rkkt.contracts.requireTextScalar(data.projectRoot, ...
    "rkkt.model.linearize data.projectRoot");

modelDirectory = fullfile(string(data.projectRoot),"src","model");
productionFile = fullfile(modelDirectory,"build_stage_a4_linearization.m");
if ~isfile(productionFile)
    error("rkkt:model:ProductionFileMissing", ...
        "Production linearization builder is missing: %s",productionFile);
end

originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("build_stage_a4_linearization"));
if ~same_path(resolved,productionFile)
    error("rkkt:model:ProductionFunctionShadowed", ...
        "Expected build_stage_a4_linearization at '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end

linearization = build_stage_a4_linearization( ...
    state,data,index,config);
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
