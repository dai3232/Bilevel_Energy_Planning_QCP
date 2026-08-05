function moduleResult = runResidual(options)
%RUNRESIDUAL Observe residuals from the fixed shared-linearization MAT.
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
    inputArtifact,"runResidual");
if string(upstream.meta.interface_name) ~= "rkkt.model.linearize"
    error("rkkt:model:validation:ResidualUpstreamInterface", ...
        "runResidual requires the shared linearization artifact.");
end
rkkt.contracts.requireFields(upstream.input,"projectData", ...
    "runResidual upstream.input");
rkkt.contracts.requireFields(upstream.output,"linearization", ...
    "runResidual upstream.output");
linearization = upstream.output.linearization;
view = rkkt.model.residualView(linearization);
summary = residual_component_summary(view);
identityExact = string(view.identity) == ...
    string(linearization.identity);
payloadExact = residual_payload_exact(view,linearization);
if ~(identityExact && payloadExact)
    error("rkkt:model:validation:ResidualViewFacts", ...
        "The residual view does not exactly preserve its source payload.");
end

[outputFile,tableFiles,figureFiles,figureIndex] = output_paths( ...
    outputDirectory,options.WriteArtifacts);
metadata = rkkt.validation.metadata( ...
    "rkkt.model.residualView","read-only linearization residual fields", ...
    inputArtifact,outputFile,"残差观察模块", ...
    linearization.state.iteration_index, ...
    linearization.state.state_revision, ...
    options.Interactive,options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "linearization",linearization, ...
    "upstreamMetadata",upstream.meta, ...
    "inputArtifact",inputArtifact);
moduleResult.output = struct("residualView",view);
moduleResult.intermediate = struct( ...
    "componentSummary",summary, ...
    "figureIndex",figureIndex);
moduleResult.diagnostics = struct( ...
    "identity",string(view.identity), ...
    "identity_exact",identityExact, ...
    "payload_exact",payloadExact, ...
    "artifacts_written",options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "source","统一线性化模块输出中的唯一linearization对象", ...
    "order","残差和l/z保持原对象顺序", ...
    "assembly","只读观察，不重新装配");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    rkkt.validation.writeTable17( ...
        summary,tableFiles(1));
    fig = residual_figure(summary,options.Interactive);
    rkkt.validation.saveFigurePair( ...
        fig,figureIndex.figPath,figureIndex.pngPath);
    if ~options.Interactive
        close(fig);
    end
    rkkt.validation.saveResult( ...
        outputFile,moduleResult);
end

fprintf("当前模块：残差观察模块\n");
fprintf("公共接口：rkkt.model.residualView\n");
fprintf("identity：%s\n",view.identity);
if options.WriteArtifacts
    fprintf("固定人工验证输出：%s\n",outputFile);
end
end

function value = residual_payload_exact(view,linearization)
value = isequaln(view.r_dual,linearization.r_dual) && ...
    isequaln(view.r_eq,linearization.r_eq) && ...
    isequaln(view.r_ineq,linearization.r_ineq) && ...
    isequaln(view.r_comp,linearization.r_comp) && ...
    isequaln(view.l,linearization.l) && ...
    isequaln(view.z,linearization.z) && ...
    isequaln(view.mu,linearization.mu);
end

function value = residual_component_summary(view)
component = ["r_dual";"r_eq";"r_ineq";"r_comp";"l";"z";"mu"];
vectors = {view.r_dual;view.r_eq;view.r_ineq;view.r_comp; ...
    view.l;view.z;view.mu};
n = numel(vectors);
elementCount = zeros(n,1);
minimum = zeros(n,1);
maximum = zeros(n,1);
norm2 = zeros(n,1);
normInf = zeros(n,1);
finite = false(n,1);
for k = 1:n
    vector = vectors{k};
    elementCount(k) = numel(vector);
    minimum(k) = min(vector,[],"all");
    maximum(k) = max(vector,[],"all");
    norm2(k) = norm(vector,2);
    normInf(k) = norm(vector,inf);
    finite(k) = all(isfinite(vector),"all");
end
value = table(component,elementCount,minimum,maximum,norm2,normInf,finite);
end

function fig = residual_figure(summary,interactive)
visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name","残差观察：残差范数", ...
    "NumberTitle","off","Color","w","Visible",visibility, ...
    "Position",[100,100,920,600]);
bar(log10(1+summary.normInf(1:4)));
xticks(1:4);
xticklabels(summary.component(1:4));
ylabel("log_{10}(1+无穷范数)");
title("初始残差分量量级（压缩显示）");
grid on;
end

function [outputFile,tableFiles,figureFiles,index] = ...
        output_paths(outputDirectory,writeArtifacts)
if writeArtifacts
    outputFile = fullfile(outputDirectory,"残差观察输出.mat");
    tableFiles = fullfile(outputDirectory,"残差分量摘要.csv");
    figPath = fullfile(outputDirectory,"残差范数.fig");
    pngPath = fullfile(outputDirectory,"残差范数.png");
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
