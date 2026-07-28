function thomas = solveDayChain(dayPartition,options)
%SOLVEDAYCHAIN Delegate one 24-hour multi-RHS block Thomas solve.

arguments
    dayPartition (1,1) struct
    options.SymmetryTolerance (1,1) double ...
        {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

rkkt.contracts.requireFields(dayPartition, ...
    ["linearization_identity","hour"], ...
    "rkkt.solver.solveDayChain dayPartition");
if options.ResidualRefinementMaxPasses ~= 0
    error("rkkt:solver:ResidualRefinementDisabled", ...
        "PKG-6 requires ResidualRefinementMaxPasses=0.");
end
[solverDirectory,productionFile] = production_location( ...
    "solve_block_thomas_ldl.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(solverDirectory,"-begin");
resolved = string(which("solve_block_thomas_ldl"));
if ~same_path(resolved,productionFile)
    error("rkkt:solver:ProductionFunctionShadowed", ...
        ["Expected solve_block_thomas_ldl at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
thomas = solve_block_thomas_ldl(dayPartition, ...
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
