function index = build_stage_a3_index(data, options)
%BUILD_STAGE_A3_INDEX Preserve the validated A3 public index builder.

arguments
    data (1,1) struct
    options.ConfigPath (1,1) string = ""
    options.RunId (1,1) string = "STAGE_A3_INDEX"
end

projectRoot = resolve_project_root(data,options.ConfigPath);
config = rkkt.model.load_stage_a3_configuration(projectRoot);
if strlength(options.ConfigPath) > 0
    expectedPath = string(fullfile(projectRoot,"config","stage_A3.yaml"));
    if ~paths_equal(options.ConfigPath,expectedPath)
        error("stageA3:index:ConfigPathLayout", ...
            "ConfigPath must identify <projectRoot>/config/stage_A3.yaml.");
    end
end
index = rkkt.indexing.build_stage_a_multiday_index(data,config,"RunId",options.RunId);
end

function projectRoot = resolve_project_root(data,configPath)
if strlength(configPath) > 0
    configDirectory = string(fileparts(configPath));
    projectRoot = string(fileparts(configDirectory));
elseif isfield(data,"projectRoot") && ...
        strlength(string(data.projectRoot)) > 0
    projectRoot = string(data.projectRoot);
else
    error("stageA3:index:MissingProjectRoot", ...
        "data.projectRoot is required when ConfigPath is not supplied.");
end
end

function equal = paths_equal(left,right)
left = replace(string(left),"\","/");
right = replace(string(right),"\","/");
equal = strcmpi(left,right);
end
