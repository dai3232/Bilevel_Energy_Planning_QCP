function moduleResult = runHessian(options)
%RUNHESSIAN Observe H from the fixed shared-linearization MAT.
%   No state initialization or model assembly is performed.

arguments
    options.InputArtifact (1,1) string = default_input_artifact()
    options.Interactive (1,1) logical = true
    options.WriteArtifacts (1,1) logical = true
    options.OutputDirectory (1,1) string = default_output_directory()
end

inputArtifact = string(options.InputArtifact);
outputDirectory = string(options.OutputDirectory);
rkkt.validation.requireOutputDirectory( ...
    outputDirectory,options.WriteArtifacts);
upstream = rkkt.validation.loadResult( ...
    inputArtifact,"runHessian");
if string(upstream.meta.interface_name) ~= "rkkt.model.linearize"
    error("rkkt:model:validation:HessianUpstreamInterface", ...
        "runHessian requires the shared linearization artifact.");
end
rkkt.contracts.requireFields(upstream.input,"projectData", ...
    "runHessian upstream.input");
rkkt.contracts.requireFields(upstream.output,"linearization", ...
    "runHessian upstream.output");
linearization = upstream.output.linearization;
view = rkkt.model.hessianView(linearization);
summary = hessian_summary(view);
identityExact = string(view.identity) == ...
    string(linearization.identity);
payloadExact = isequaln(view.hessian,linearization.hessian) && ...
    isequaln(view.H,linearization.H);
if ~(identityExact && payloadExact)
    error("rkkt:model:validation:HessianViewFacts", ...
        "The Hessian view does not exactly preserve its source payload.");
end

[outputFile,tableFiles,figureFiles,figureIndex] = output_paths( ...
    outputDirectory,options.WriteArtifacts);
metadata = rkkt.validation.metadata( ...
    "rkkt.model.hessianView","read-only linearization Hessian fields", ...
    inputArtifact,outputFile,"Hessian观察模块", ...
    linearization.state.iteration_index, ...
    linearization.state.state_revision, ...
    options.Interactive,options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "linearization",linearization, ...
    "upstreamMetadata",upstream.meta, ...
    "inputArtifact",inputArtifact);
moduleResult.output = struct("hessianView",view);
moduleResult.intermediate = struct( ...
    "matrixSummary",summary, ...
    "figureIndex",figureIndex);
moduleResult.diagnostics = struct( ...
    "identity",string(view.identity), ...
    "identity_exact",identityExact, ...
    "payload_exact",payloadExact, ...
    "artifacts_written",options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "source","统一线性化模块输出中的唯一linearization对象", ...
    "order","H保持canonical xi顺序", ...
    "assembly","只读观察，不重新计算Hessian");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    rkkt.validation.writeTable17( ...
        summary,tableFiles(1));
    fig = hessian_figure(view,options.Interactive);
    rkkt.validation.saveFigurePair( ...
        fig,figureIndex.figPath,figureIndex.pngPath);
    if ~options.Interactive
        close(fig);
    end
    rkkt.validation.saveResult( ...
        outputFile,moduleResult);
end

fprintf("当前模块：Hessian观察模块\n");
fprintf("公共接口：rkkt.model.hessianView\n");
fprintf("identity：%s\n",view.identity);
if options.WriteArtifacts
    fprintf("固定人工验证输出：%s\n",outputFile);
end
end

function value = hessian_summary(view)
matrixName = "H";
rowCount = size(view.H,1);
columnCount = size(view.H,2);
nonzeroCount = nnz(view.H);
density = nonzeroCount/(rowCount*columnCount);
sparseStorage = issparse(view.H);
exactZero = nonzeroCount == 0;
value = table(matrixName,rowCount,columnCount,nonzeroCount, ...
    density,sparseStorage,exactZero);
end

function fig = hessian_figure(view,interactive)
visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name","Hessian观察：稀疏结构", ...
    "NumberTitle","off","Color","w","Visible",visibility, ...
    "Position",[100,100,900,620]);
spy(view.H);
title(compose("H：%d×%d，nnz=%d（阶段A精确零）", ...
    size(view.H,1),size(view.H,2),nnz(view.H)));
end

function [outputFile,tableFiles,figureFiles,index] = ...
        output_paths(outputDirectory,writeArtifacts)
if writeArtifacts
    outputFile = fullfile(outputDirectory,"Hessian观察输出.mat");
    tableFiles = fullfile(outputDirectory, ...
        "Hessian维数与非零元.csv");
    figPath = fullfile(outputDirectory,"Hessian稀疏结构.fig");
    pngPath = fullfile(outputDirectory,"Hessian稀疏结构.png");
    figureFiles = [figPath;pngPath];
else
    outputFile = "";
    tableFiles = strings(0,1);
    figPath = "";
    pngPath = "";
    figureFiles = strings(0,1);
end
tableFiles = reshape(string(tableFiles),[],1);
figureFiles = reshape(string(figureFiles),[],1);
index = struct("figPath",string(figPath),"pngPath",string(pngPath));
end

function value = default_input_artifact()
value = fullfile(default_output_directory(), ...
    "统一线性化模块输出.mat");
end

function value = default_output_directory()
value = string(fileparts(mfilename("fullpath")));
end
