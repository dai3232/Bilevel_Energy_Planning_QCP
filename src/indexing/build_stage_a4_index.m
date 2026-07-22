function index = build_stage_a4_index(data, options)
%BUILD_STAGE_A4_INDEX Build the formal seven-day A4 canonical index.

arguments
    data (1,1) struct
    options.ConfigPath (1,1) string = ""
    options.RunId (1,1) string = "STAGE_A4_INDEX"
end

projectRoot = resolve_project_root(data,options.ConfigPath);
config = load_stage_a4_configuration(projectRoot);
if strlength(options.ConfigPath) > 0
    expectedPath = string(fullfile(projectRoot,"config","stage_A4.yaml"));
    if ~paths_equal(options.ConfigPath,expectedPath)
        error("stageA4:index:ConfigPathLayout", ...
            "ConfigPath must identify <projectRoot>/config/stage_A4.yaml.");
    end
end
index = build_stage_a_multiday_index(data,config,"RunId",options.RunId);
if string(index.scope.stage_id) ~= "stage_A4" || ...
        index.counts.full_kkt_dimension ~= 18836 || ...
        index.counts.fixed_zero ~= 422
    error("stageA4:index:Identity", ...
        "The A4 canonical index identity or controlled counts are invalid.");
end
end

function projectRoot = resolve_project_root(data,configPath)
if strlength(configPath) > 0
    configDirectory = string(fileparts(configPath));
    projectRoot = string(fileparts(configDirectory));
elseif isfield(data,"projectRoot") && ...
        strlength(string(data.projectRoot)) > 0
    projectRoot = string(data.projectRoot);
else
    error("stageA4:index:MissingProjectRoot", ...
        "data.projectRoot is required when ConfigPath is not supplied.");
end
end

function equal = paths_equal(left,right)
left = replace(string(left),"\","/");
right = replace(string(right),"\","/");
equal = strcmpi(left,right);
end
