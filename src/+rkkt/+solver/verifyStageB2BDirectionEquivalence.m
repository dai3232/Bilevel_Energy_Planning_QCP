function audit = verifyStageB2BDirectionEquivalence( ...
        fullResult,recursiveResult,linearization,thresholds)
%VERIFYSTAGEB2BDIRECTIONEQUIVALENCE Delegate the frozen B-2B audit.

arguments
    fullResult (1,1) struct
    recursiveResult (1,1) struct
    linearization (1,1) struct
    thresholds.DirectionRelative (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.RecursiveResidual (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.FullResidual (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
end

rkkt.contracts.requireFields(fullResult,"linearization_identity", ...
    "rkkt.solver.verifyStageB2BDirectionEquivalence fullResult");
rkkt.contracts.requireFields(recursiveResult,"linearization_identity", ...
    "rkkt.solver.verifyStageB2BDirectionEquivalence recursiveResult");
rkkt.contracts.requireFields(linearization,["identity";"milestone_id"], ...
    "rkkt.solver.verifyStageB2BDirectionEquivalence linearization");
if string(linearization.milestone_id) ~= "B-2B"
    error("rkkt:solver:StageContract", ...
        "verifyStageB2BDirectionEquivalence requires B-2B inputs.");
end

[solverDirectory,productionFile] = production_location( ...
    "solver","verify_stage_b2b_direction_equivalence.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("verify_stage_b2b_direction_equivalence"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected verify_stage_b2b_direction_equivalence at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end

audit = verify_stage_b2b_direction_equivalence( ...
    fullResult,recursiveResult,linearization, ...
    DirectionRelative=thresholds.DirectionRelative, ...
    RecursiveResidual=thresholds.RecursiveResidual, ...
    FullResidual=thresholds.FullResidual);
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
