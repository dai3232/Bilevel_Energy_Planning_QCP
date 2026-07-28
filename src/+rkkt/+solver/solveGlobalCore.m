function core = solveGlobalCore(partition,aggregation,options)
%SOLVEGLOBALCORE Delegate the retained 16-dimensional LDL solve.

arguments
    partition (1,1) struct
    aggregation (1,1) struct
    options.SymmetryTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

rkkt.contracts.requireFields(partition,"linearization_identity", ...
    "rkkt.solver.solveGlobalCore partition");
rkkt.contracts.requireFields(aggregation,"linearization_identity", ...
    "rkkt.solver.solveGlobalCore aggregation");
if options.ResidualRefinementMaxPasses ~= 0
    error("rkkt:solver:ResidualRefinementDisabled", ...
        "PKG-6 requires ResidualRefinementMaxPasses=0.");
end
[solverDirectory,productionFile] = production_location( ...
    "solve_stage_a_multiday_core16_ldl.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("solve_stage_a_multiday_core16_ldl"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected solve_stage_a_multiday_core16_ldl at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
core = solve_stage_a_multiday_core16_ldl(partition,aggregation, ...
    SymmetryTolerance=options.SymmetryTolerance, ...
    ResidualRefinementMaxPasses= ...
        options.ResidualRefinementMaxPasses);
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
