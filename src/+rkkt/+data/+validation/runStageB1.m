function moduleResult = runStageB1(options)
%RUNSTAGEB1 Observe Stage B-1 daily hydro-water values and derivatives.
%   This entry calls only the Stage B-1 data facade. It neither creates a
%   formal run nor assembles or solves an optimization problem.

arguments
    options.ProjectRoot (1,1) string = default_project_root()
    options.Interactive (1,1) logical = false
    options.WriteArtifacts (1,1) logical = false
    options.OutputDirectory (1,1) string = default_output_directory()
end

projectRoot = strip(options.ProjectRoot);
outputDirectory = strip(options.OutputDirectory);
require_inputs(projectRoot,outputDirectory,options.WriteArtifacts);

data = rkkt.data.load(projectRoot);
[summary,representative] = evaluate_samples(data);
[outputFile,tableFiles,figureFiles,figureIndex] = output_paths( ...
    outputDirectory,options.WriteArtifacts);

sourceFiles = string(data.hashes.filePath);
sourceHashes = lower(string(data.hashes.actualSHA256));
metadata = struct( ...
    "interface_name","rkkt.data.evaluateStageBDailyHydroWater", ...
    "production_function","evaluate_stage_b_daily_hydro_water", ...
    "input_artifact",sourceFiles(1), ...
    "input_sha256",sourceHashes(1), ...
    "git_commit",git_commit(projectRoot), ...
    "stage_id","stage_B", ...
    "day",14:20, ...
    "hour",1:24, ...
    "iteration",[], ...
    "revision",0, ...
    "matlab_version",string(version), ...
    "generated_at",now_text(), ...
    "contract_version",rkkt.contracts.version(), ...
    "module_name","阶段B-1水量函数验证", ...
    "output_file",outputFile, ...
    "interactive_figures",options.Interactive, ...
    "artifacts_requested",options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "project_root",projectRoot, ...
    "source_files",sourceFiles, ...
    "source_sha256",sourceHashes, ...
    "days",14:20, ...
    "hydro_ids",1:4, ...
    "power_profile_rule", ...
        "0.2Pmax至0.8Pmax的24小时确定性循环剖面");
moduleResult.output = struct( ...
    "summary",summary, ...
    "representative_day14_hydro1",representative);
moduleResult.intermediate = struct("figureIndex",figureIndex);
moduleResult.diagnostics = struct( ...
    "sample_count",height(summary), ...
    "all_values_finite",all(isfinite(summary.waterValue)), ...
    "all_gradients_finite",all(summary.gradientFinite), ...
    "all_hessians_sparse",all(summary.hessianSparse), ...
    "all_hessians_diagonal",all(summary.hessianOffDiagonalNnz == 0), ...
    "optimization_executed",false, ...
    "state_update_executed",false, ...
    "formal_run_created",false, ...
    "artifacts_written",options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "row_order","日期14—20为外层、水电站1—4为内层", ...
    "gradient_order","24个日内小时", ...
    "hessian_order","24×24日内小时，跨小时项为零");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    write_table17(summary,tableFiles(1));
    fig = summary_figure(summary,options.Interactive);
    save_figure_pair(fig,figureIndex.figPath,figureIndex.pngPath);
    if ~options.Interactive
        close(fig);
    end
    save(outputFile,"moduleResult","-v7.3");
end
end

function [summary,representative] = evaluate_samples(data)
rowCount = 7*4;
day = repelem((14:20).',4,1);
hydroId = repmat((1:4).',7,1);
waterValue = zeros(rowCount,1);
waterMinimum = zeros(rowCount,1);
waterMaximum = zeros(rowCount,1);
gradientMinimum = zeros(rowCount,1);
gradientMaximum = zeros(rowCount,1);
gradientNorm2 = zeros(rowCount,1);
hessianNnz = zeros(rowCount,1);
hessianDiagonalMinimum = zeros(rowCount,1);
hessianDiagonalMaximum = zeros(rowCount,1);
hessianOffDiagonalNnz = zeros(rowCount,1);
gradientFinite = false(rowCount,1);
hessianSparse = false(rowCount,1);
representative = struct();

for row = 1:rowCount
    dayValue = day(row);
    hydro = hydroId(row);
    maximumMW = double(data.base.hydro.maxOutputMW(hydro));
    phase = mod((0:23).' + dayValue-14,24)/23;
    powerMW = maximumMW.*(0.2 + 0.6.*phase);
    a = data.base.hydro.waterA(hydro);
    b = data.base.hydro.waterB(hydro);
    c = data.base.hydro.waterC(hydro);
    result = rkkt.data.evaluateStageBDailyHydroWater( ...
        powerMW,a,b,c);
    diagonal = full(diag(result.hessian));
    offDiagonal = result.hessian-spdiags(diagonal,0,24,24);

    waterValue(row) = result.value;
    waterMinimum(row) = data.timeseries.hydroWaterMin(dayValue,hydro);
    waterMaximum(row) = data.timeseries.hydroWaterMax(dayValue,hydro);
    gradientMinimum(row) = min(result.gradient);
    gradientMaximum(row) = max(result.gradient);
    gradientNorm2(row) = norm(result.gradient,2);
    hessianNnz(row) = nnz(result.hessian);
    hessianDiagonalMinimum(row) = min(diagonal);
    hessianDiagonalMaximum(row) = max(diagonal);
    hessianOffDiagonalNnz(row) = nnz(offDiagonal);
    gradientFinite(row) = all(isfinite(result.gradient));
    hessianSparse(row) = issparse(result.hessian);
    if row == 1
        representative = struct( ...
            "day",dayValue, ...
            "hydro_id",hydro, ...
            "power_mw",powerMW, ...
            "value",result.value, ...
            "gradient",result.gradient, ...
            "hessian",result.hessian);
    end
end

summary = table(day,hydroId,waterValue,waterMinimum,waterMaximum, ...
    gradientMinimum,gradientMaximum,gradientNorm2,hessianNnz, ...
    hessianDiagonalMinimum,hessianDiagonalMaximum, ...
    hessianOffDiagonalNnz,gradientFinite,hessianSparse);
end

function fig = summary_figure(summary,interactive)
visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name","阶段B-1水量值与导数摘要", ...
    "NumberTitle","off","Color","w","Visible",visibility, ...
    "Position",[100,100,1180,650]);
layout = tiledlayout(fig,1,3,"TileSpacing","compact");
days = unique(summary.day,"stable");
for hydro = 1:4
    rows = summary.hydroId == hydro;
    nexttile(layout,1);
    hold on;
    plot(days,summary.waterValue(rows),"-o","LineWidth",1.1, ...
        "DisplayName",compose("水电%d",hydro));
    nexttile(layout,2);
    hold on;
    plot(days,summary.gradientNorm2(rows),"-o","LineWidth",1.1, ...
        "DisplayName",compose("水电%d",hydro));
    nexttile(layout,3);
    hold on;
    plot(days,summary.hessianNnz(rows),"-o","LineWidth",1.1, ...
        "DisplayName",compose("水电%d",hydro));
end
nexttile(layout,1);
xlabel("日期"); ylabel("日水量函数值"); title("水量值"); grid on;
legend("Location","best");
nexttile(layout,2);
xlabel("日期"); ylabel("梯度2范数"); title("梯度量级"); grid on;
nexttile(layout,3);
xlabel("日期"); ylabel("Hessian非零元数"); title("Hessian摘要"); grid on;
end

function [outputFile,tableFiles,figureFiles,index] = ...
        output_paths(outputDirectory,writeArtifacts)
if writeArtifacts
    outputFile = fullfile(outputDirectory,"阶段B-1水量函数验证输出.mat");
    tableFiles = fullfile(outputDirectory, ...
        "阶段B-1水量值与导数摘要.csv");
    figPath = fullfile(outputDirectory, ...
        "阶段B-1水量值与导数摘要.fig");
    pngPath = fullfile(outputDirectory, ...
        "阶段B-1水量值与导数摘要.png");
    figureFiles = [figPath;pngPath];
else
    outputFile = "";
    tableFiles = strings(0,1);
    figPath = "";
    pngPath = "";
    figureFiles = strings(0,1);
end
outputFile = string(outputFile);
tableFiles = reshape(string(tableFiles),[],1);
figureFiles = reshape(string(figureFiles),[],1);
index = struct("figPath",string(figPath),"pngPath",string(pngPath));
end

function require_inputs(projectRoot,outputDirectory,writeArtifacts)
if strlength(projectRoot) == 0 || ~isfolder(projectRoot)
    error("rkkt:data:validation:StageB1ProjectRoot", ...
        "ProjectRoot must be an existing nonempty directory: %s", ...
        projectRoot);
end
if writeArtifacts && ~isfolder(outputDirectory)
    error("rkkt:data:validation:StageB1OutputDirectory", ...
        "OutputDirectory must already exist: %s",outputDirectory);
end
end

function save_figure_pair(fig,figPath,pngPath)
savefig(fig,figPath);
exportgraphics(fig,pngPath,"Resolution",200);
end

function write_table17(value,destination)
names = string(value.Properties.VariableNames);
cells = strings(height(value),width(value));
for columnIndex = 1:width(value)
    column = value.(value.Properties.VariableNames{columnIndex});
    if isnumeric(column)
        cells(:,columnIndex) = compose("%.17g",double(column));
    elseif islogical(column)
        cells(:,columnIndex) = lower(string(column));
    else
        cells(:,columnIndex) = csv_escape(string(column));
    end
end
lines = [strjoin(csv_escape(names),",");join(cells,",",2)];
write_text(destination,strjoin(lines,newline)+newline);
end

function value = csv_escape(value)
value = replace(string(value),"""","""""");
value = """"+value+"""";
end

function write_text(destination,textValue)
[fileId,message] = fopen(destination,"wb","n","UTF-8");
if fileId < 0
    error("rkkt:data:validation:StageB1CsvOpen","%s",message);
end
fileGuard = onCleanup(@() close_file(fileId));
bytes = unicode2native(char(textValue),"UTF-8");
if fwrite(fileId,bytes,"uint8") ~= numel(bytes)
    error("rkkt:data:validation:StageB1CsvWrite", ...
        "Incomplete CSV write: %s",destination);
end
status = fclose(fileId);
clear fileGuard
if status ~= 0
    error("rkkt:data:validation:StageB1CsvClose", ...
        "Could not close CSV: %s",destination);
end
end

function close_file(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end

function value = git_commit(projectRoot)
value = "NOT_AVAILABLE";
safeRoot = replace(projectRoot,"\","/");
command = sprintf('git -c safe.directory="%s" -C "%s" rev-parse HEAD', ...
    safeRoot,projectRoot);
[status,output] = system(command);
candidate = lower(strip(string(output)));
if status == 0 && ~isempty(regexp(char(candidate), ...
        "^[0-9a-f]{40}$","once"))
    value = candidate;
end
end

function value = now_text()
value = string(datetime("now","TimeZone","Asia/Shanghai", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end

function value = default_project_root()
value = string(fileparts(mfilename("fullpath")));
for k = 1:4
    value = string(fileparts(value));
end
end

function value = default_output_directory()
value = string(fileparts(mfilename("fullpath")));
end
