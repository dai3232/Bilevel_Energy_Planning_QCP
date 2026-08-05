function moduleResult = runJacobian(options)
%RUNJACOBIAN Observe A and G from the fixed shared-linearization MAT.
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
    inputArtifact,"runJacobian");
if string(upstream.meta.interface_name) ~= "rkkt.model.linearize"
    error("rkkt:model:validation:JacobianUpstreamInterface", ...
        "runJacobian requires the shared linearization artifact.");
end
rkkt.contracts.requireFields(upstream.input,"projectData", ...
    "runJacobian upstream.input");
rkkt.contracts.requireFields(upstream.output,"linearization", ...
    "runJacobian upstream.output");
linearization = upstream.output.linearization;
view = rkkt.model.jacobianView(linearization);
summary = jacobian_summary(view);
identityExact = string(view.identity) == ...
    string(linearization.identity);
payloadExact = isequaln(view.jacobian,linearization.jacobian) && ...
    isequaln(view.A,linearization.A) && ...
    isequaln(view.G,linearization.G);
if ~(identityExact && payloadExact)
    error("rkkt:model:validation:JacobianViewFacts", ...
        "The Jacobian view does not exactly preserve its source payload.");
end

[outputFile,tableFiles,figureFiles,figureIndex] = output_paths( ...
    outputDirectory,options.WriteArtifacts);
metadata = rkkt.validation.metadata( ...
    "rkkt.model.jacobianView","read-only linearization Jacobian fields", ...
    inputArtifact,outputFile,"Jacobian观察模块", ...
    linearization.state.iteration_index, ...
    linearization.state.state_revision, ...
    options.Interactive,options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "linearization",linearization, ...
    "upstreamMetadata",upstream.meta, ...
    "inputArtifact",inputArtifact);
moduleResult.output = struct("jacobianView",view);
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
    "order","A/G保持canonical行列顺序", ...
    "assembly","只读观察，不重新计算Jacobian");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    rkkt.validation.writeTable17( ...
        summary,tableFiles(1));
    fig = jacobian_figure(view,options.Interactive);
    rkkt.validation.saveFigurePair( ...
        fig,figureIndex.figPath,figureIndex.pngPath);
    if ~options.Interactive
        close(fig);
    end
    rkkt.validation.saveResult( ...
        outputFile,moduleResult);
end

fprintf("当前模块：Jacobian观察模块\n");
fprintf("公共接口：rkkt.model.jacobianView\n");
fprintf("identity：%s\n",view.identity);
if options.WriteArtifacts
    fprintf("固定人工验证输出：%s\n",outputFile);
end
end

function value = jacobian_summary(view)
matrixName = ["A";"G"];
rowCount = [size(view.A,1);size(view.G,1)];
columnCount = [size(view.A,2);size(view.G,2)];
nonzeroCount = [nnz(view.A);nnz(view.G)];
density = nonzeroCount./(rowCount.*columnCount);
sparseStorage = [issparse(view.A);issparse(view.G)];
value = table(matrixName,rowCount,columnCount,nonzeroCount, ...
    density,sparseStorage);
end

function fig = jacobian_figure(view,interactive)
visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name","Jacobian观察：稀疏结构", ...
    "NumberTitle","off","Color","w","Visible",visibility, ...
    "Position",[100,100,1120,620]);
layout = tiledlayout(fig,1,2,"TileSpacing","compact");
nexttile(layout);
spy(view.A);
title(compose("A：%d×%d，nnz=%d", ...
    size(view.A,1),size(view.A,2),nnz(view.A)));
nexttile(layout);
spy(view.G);
title(compose("G：%d×%d，nnz=%d", ...
    size(view.G,1),size(view.G,2),nnz(view.G)));
end

function [outputFile,tableFiles,figureFiles,index] = ...
        output_paths(outputDirectory,writeArtifacts)
if writeArtifacts
    outputFile = fullfile(outputDirectory,"Jacobian观察输出.mat");
    tableFiles = fullfile(outputDirectory, ...
        "Jacobian维数与非零元.csv");
    figPath = fullfile(outputDirectory,"Jacobian稀疏结构.fig");
    pngPath = fullfile(outputDirectory,"Jacobian稀疏结构.png");
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
