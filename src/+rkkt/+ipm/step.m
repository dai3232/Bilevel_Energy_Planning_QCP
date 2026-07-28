function result = step(stateBefore,data,index,config,options)
%STEP Delegate one explicit-state A4 primal-dual transition.

arguments
    stateBefore (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    options.StepStrategy (1,1) string {mustBeMember( ...
        options.StepStrategy,["independent","common_min"])} = "independent"
    options.ObjectiveScaleMode (1,1) string {mustBeMember( ...
        options.ObjectiveScaleMode, ...
        ["unscaled","positive_scalar_unitization"])} = "unscaled"
    options.DiagnosticObjectiveChainId (1,1) string = ""
    options.EqualityResidualReferenceScale (1,1) double = NaN
    options.DualResidualReferenceScale (1,1) double = NaN
    options.RecursiveRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end

[productionDirectory,productionFile] = production_location( ...
    "diagnostics","execute_stage_a4_iteration.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(productionDirectory,"-begin");
resolved = string(which("execute_stage_a4_iteration"));
if ~same_path(resolved,productionFile)
    error("rkkt:ipm:ProductionFunctionShadowed", ...
        ["Expected execute_stage_a4_iteration at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
result = execute_stage_a4_iteration( ...
    stateBefore,data,index,config, ...
    StepStrategy=options.StepStrategy, ...
    ObjectiveScaleMode=options.ObjectiveScaleMode, ...
    DiagnosticObjectiveChainId=options.DiagnosticObjectiveChainId, ...
    EqualityResidualReferenceScale= ...
        options.EqualityResidualReferenceScale, ...
    DualResidualReferenceScale=options.DualResidualReferenceScale, ...
    RecursiveRefinementMaxPasses= ...
        options.RecursiveRefinementMaxPasses);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,string(folder));
file = fullfile(directory,string(fileName));
if ~isfile(file)
    error("rkkt:ipm:ProductionFileMissing", ...
        "Production IPM file is missing: %s",file);
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
