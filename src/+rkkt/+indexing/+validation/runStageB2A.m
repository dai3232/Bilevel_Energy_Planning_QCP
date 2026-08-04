function moduleResult = runStageB2A(options)
%RUNSTAGEB2A Observe the canonical 56-row Stage B-2A water index.
%   This entry calls the explicit B-2A indexing facade. It does not create
%   a formal run, assemble a KKT system, or update an optimization state.

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
config = call_configuration(projectRoot);
index = rkkt.indexing.buildStageB2A(data,config, ...
    "RunId","PKG9_STAGE_B2A_INDEX_VALIDATION");
summary = water_index_summary(index);
facts = inspect_index(summary,index);
if ~all(structfun(@logical,facts))
    error("rkkt:indexing:validation:StageB2AIndexFacts", ...
        "The Stage B-2A water index observations are inconsistent.");
end
[outputFile,tableFiles,figureFiles,figureIndex] = output_paths( ...
    outputDirectory,options.WriteArtifacts);

sourceFiles = string(data.hashes.filePath);
sourceHashes = lower(string(data.hashes.actualSHA256));
metadata = struct( ...
    "interface_name","rkkt.indexing.buildStageB2A", ...
    "production_function","build_stage_b_index", ...
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
    "module_name","阶段B-2A索引验证", ...
    "output_file",outputFile, ...
    "interactive_figures",options.Interactive, ...
    "artifacts_requested",options.WriteArtifacts);
moduleResult = rkkt.contracts.moduleResultTemplate(metadata);
moduleResult.input = struct( ...
    "project_root",projectRoot, ...
    "source_files",sourceFiles, ...
    "source_sha256",sourceHashes, ...
    "configuration_paths",config.source_paths, ...
    "run_id","PKG9_STAGE_B2A_INDEX_VALIDATION");
moduleResult.output = struct( ...
    "waterConstraintSummary",summary, ...
    "indexVersion",string(index.version), ...
    "scope",index.scope, ...
    "counts",index.counts);
moduleResult.intermediate = struct("figureIndex",figureIndex);
moduleResult.diagnostics = struct( ...
    "objective_facts",facts, ...
    "water_constraint_count",height(summary), ...
    "stage_a_variable_count",index.counts.variables, ...
    "stage_a_equality_count",index.counts.equalities, ...
    "total_inequality_count",index.counts.inequalities, ...
    "full_kkt_dimension",index.counts.full_kkt_dimension, ...
    "optimization_executed",false, ...
    "state_update_executed",false, ...
    "formal_run_created",false, ...
    "artifacts_written",options.WriteArtifacts);
moduleResult.indexDescription = struct( ...
    "row_order","日期→水电站→upper/lower", ...
    "water_row_count",56, ...
    "touched_variables","每行仅连接同日同站24个PH变量", ...
    "stage_a_prefix","变量、等式及既有不等式前缀保持不变");
moduleResult.tableFiles = tableFiles;
moduleResult.figureFiles = figureFiles;
rkkt.contracts.validateModuleResult(moduleResult);

if options.WriteArtifacts
    write_table17(summary,tableFiles(1));
    fig = index_figure(summary,options.Interactive);
    save_figure_pair(fig,figureIndex.figPath,figureIndex.pngPath);
    if ~options.Interactive
        close(fig);
    end
    save(outputFile,"moduleResult","-v7.3");
end
end

function value = water_index_summary(index)
water = index.water_constraint_index;
names = [ ...
    "constraint_id"
    "day"
    "hydro_id"
    "bound_type"
    "row_position"
    "inequality_position"
    "global_row"
    "touched_hour_count"
    "touched_variable_count"
    "ordering_rule"];
value = water(:,cellstr(names));
end

function facts = inspect_index(summary,index)
expectedDay = repelem((14:20).',8,1);
expectedHydro = repmat(repelem((1:4).',2,1),7,1);
expectedBound = repmat(["upper";"lower"],28,1);
facts = struct( ...
    "water_row_count_exact",height(summary) == 56, ...
    "row_position_contiguous", ...
        isequal(summary.row_position,(1:56).'), ...
    "day_order_exact",isequal(summary.day,expectedDay), ...
    "hydro_order_exact",isequal(summary.hydro_id,expectedHydro), ...
    "bound_order_exact", ...
        isequal(string(summary.bound_type),expectedBound), ...
    "constraint_ids_unique", ...
        numel(unique(string(summary.constraint_id))) == 56, ...
    "inequality_positions_unique", ...
        numel(unique(summary.inequality_position)) == 56, ...
    "global_rows_unique",numel(unique(summary.global_row)) == 56, ...
    "twenty_four_hours_per_row", ...
        all(summary.touched_hour_count == 24), ...
    "twenty_four_variables_per_row", ...
        all(summary.touched_variable_count == 24), ...
    "controlled_counts_exact", ...
        index.counts.variables == 3722 && ...
        index.counts.equalities == 618 && ...
        index.counts.inequalities == 7304 && ...
        index.counts.full_kkt_dimension == 18948);
end

function config = call_configuration(projectRoot)
modelDirectory = fullfile(projectRoot,"src","model");
productionFile = fullfile(modelDirectory, ...
    "load_stage_b2a_configuration.m");
if ~isfile(productionFile)
    error("rkkt:indexing:validation:StageB2AConfigMissing", ...
        "The controlled configuration loader is missing: %s", ...
        productionFile);
end
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(modelDirectory,"-begin");
resolved = string(which("load_stage_b2a_configuration"));
if ~same_path(resolved,productionFile)
    error("rkkt:indexing:validation:StageB2AConfigShadowed", ...
        "Expected '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end
config = load_stage_b2a_configuration(projectRoot);
clear pathGuard
end

function fig = index_figure(summary,interactive)
visibility = "off";
if interactive
    visibility = "on";
end
fig = figure("Name","阶段B-2A水量约束索引摘要", ...
    "NumberTitle","off","Color","w","Visible",visibility, ...
    "Position",[100,100,980,620]);
upper = string(summary.bound_type) == "upper";
lower = ~upper;
plot(summary.row_position(upper),summary.global_row(upper), ...
    "o","LineWidth",1.1,"DisplayName","upper");
hold on;
plot(summary.row_position(lower),summary.global_row(lower), ...
    "x","LineWidth",1.1,"DisplayName","lower");
xlabel("水量约束规范行序号");
ylabel("全局约束行号");
title("56条日级水量约束索引顺序");
legend("Location","best");
grid on;
end

function [outputFile,tableFiles,figureFiles,index] = ...
        output_paths(outputDirectory,writeArtifacts)
if writeArtifacts
    outputFile = fullfile(outputDirectory, ...
        "阶段B-2A索引验证输出.mat");
    tableFiles = fullfile(outputDirectory, ...
        "阶段B-2A水量约束索引摘要.csv");
    figPath = fullfile(outputDirectory, ...
        "阶段B-2A水量约束索引摘要.fig");
    pngPath = fullfile(outputDirectory, ...
        "阶段B-2A水量约束索引摘要.png");
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
    error("rkkt:indexing:validation:StageB2AProjectRoot", ...
        "ProjectRoot must be an existing nonempty directory: %s", ...
        projectRoot);
end
if writeArtifacts && ~isfolder(outputDirectory)
    error("rkkt:indexing:validation:StageB2AOutputDirectory", ...
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
    error("rkkt:indexing:validation:StageB2ACsvOpen","%s",message);
end
fileGuard = onCleanup(@() close_file(fileId));
bytes = unicode2native(char(textValue),"UTF-8");
if fwrite(fileId,bytes,"uint8") ~= numel(bytes)
    error("rkkt:indexing:validation:StageB2ACsvWrite", ...
        "Incomplete CSV write: %s",destination);
end
status = fclose(fileId);
clear fileGuard
if status ~= 0
    error("rkkt:indexing:validation:StageB2ACsvClose", ...
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

function value = same_path(left,right)
left = replace(string(left),"/","\");
right = replace(string(right),"/","\");
if ispc
    value = strcmpi(left,right);
else
    value = strcmp(left,right);
end
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
