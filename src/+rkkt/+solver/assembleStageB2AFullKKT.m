function assembly = assembleStageB2AFullKKT(linearization,config)
%ASSEMBLESTAGEB2AFULLKKT Delegate assemble-only Stage B-2A full KKT.

arguments
    linearization (1,1) struct
    config (1,1) struct
end

rkkt.contracts.requireFields(linearization,["identity";"milestone_id"], ...
    "rkkt.solver.assembleStageB2AFullKKT linearization");
rkkt.contracts.requireFields(config,["stage_id";"milestone_id"], ...
    "rkkt.solver.assembleStageB2AFullKKT config");
if string(linearization.milestone_id) ~= "B-2A" || ...
        string(config.stage_id) ~= "stage_B" || ...
        string(config.milestone_id) ~= "B-2A"
    error("rkkt:solver:StageContract", ...
        "assembleStageB2AFullKKT requires stage_B / B-2A inputs.");
end

[solverDirectory,productionFile] = production_location( ...
    "solver","assemble_stage_b_multiday_full_kkt.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("assemble_stage_b_multiday_full_kkt"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected assemble_stage_b_multiday_full_kkt at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

assembly = assemble_stage_b_multiday_full_kkt(linearization,config);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,folder);
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
