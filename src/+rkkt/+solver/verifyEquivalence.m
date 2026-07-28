function audit = verifyEquivalence( ...
        fullResult,recursiveResult,linearization,thresholds)
%VERIFYEQUIVALENCE Delegate formal full-versus-recursive direction audit.

arguments
    fullResult (1,1) struct
    recursiveResult (1,1) struct
    linearization (1,1) struct
    thresholds.DirectionRelative (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.RecursiveResidual (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.FullResidualPreferred (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    thresholds.FullResidualMaximum (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-10
end

rkkt.contracts.requireFields(fullResult,"linearization_identity", ...
    "rkkt.solver.verifyEquivalence fullResult");
rkkt.contracts.requireFields(recursiveResult,"linearization_identity", ...
    "rkkt.solver.verifyEquivalence recursiveResult");
rkkt.contracts.requireFields(linearization,"identity", ...
    "rkkt.solver.verifyEquivalence linearization");
[solverDirectory,productionFile] = production_location( ...
    "verify_stage_a_multiday_direction_equivalence.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which( ...
    "verify_stage_a_multiday_direction_equivalence"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected verify_stage_a_multiday_direction_equivalence " ...
        "at '%s'; MATLAB resolved '%s'."],productionFile,resolved);
end
audit = verify_stage_a_multiday_direction_equivalence( ...
    fullResult,recursiveResult,linearization, ...
    DirectionRelative=thresholds.DirectionRelative, ...
    RecursiveResidual=thresholds.RecursiveResidual, ...
    FullResidualPreferred=thresholds.FullResidualPreferred, ...
    FullResidualMaximum=thresholds.FullResidualMaximum);
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
