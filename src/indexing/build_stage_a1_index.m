function index = build_stage_a1_index(data, options)
%BUILD_STAGE_A1_INDEX Build the explicit three-hour A1 fixture index.
% The fixture is read from config/stage_A1.yaml unless ConfigPath is given.
% It is an algorithm test window, not a shortened physical day.

arguments
    data (1,1) struct
    options.ConfigPath (1,1) string = ""
    options.RunId (1,1) string = "STAGE_A1_INDEX"
end

configPath = options.ConfigPath;
if strlength(configPath) == 0
    if ~isfield(data,"projectRoot") || strlength(string(data.projectRoot)) == 0
        error("stageA1:index:MissingProjectRoot", ...
            "data.projectRoot is required when ConfigPath is not supplied.");
    end
    configPath = fullfile(string(data.projectRoot),"config","stage_A1.yaml");
end
stageConfig = read_stage_a1_window_config(configPath);

if stageConfig.stage_id ~= "stage_A1"
    error("stageA1:index:StageIdMismatch", ...
        "The A1 index requires stage_id='stage_A1'.");
end
if ~isequal(stageConfig.days,1) || ~isequal(stageConfig.hours,8:10)
    error("stageA1:index:FrozenFixtureMismatch", ...
        "The frozen A1 fixture must select day 1 and physical hours 8:10.");
end
if any(data.base.storage.initialSocFraction ~= 0.5)
    error("stageA1:index:SocFractionMismatch", ...
        "Both A1 storage boundary fractions must equal 0.5 from controlled data.");
end

windowSpec = struct( ...
    "window_type",stageConfig.window_type, ...
    "start_hour",stageConfig.start_hour, ...
    "terminal_hour",stageConfig.terminal_hour, ...
    "soc_boundary_mode",stageConfig.soc_boundary_mode, ...
    "terminal_soc_equality_count",stageConfig.terminal_soc_equality_count);

index = build_canonical_index_framework(data,stageConfig.days, ...
    stageConfig.hours,[],options.RunId,windowSpec);
index.scope.stage_id = "stage_A1";
index.scope.window_purpose = "algorithmic_direction_equivalence_only";
index.expected = struct( ...
    "full_kkt_dimension",stageConfig.expected_full_kkt_dimension, ...
    "hourly_kkt_block_dimensions", ...
    stageConfig.expected_hourly_kkt_block_dimensions);

if index.counts.full_kkt_dimension ~= stageConfig.expected_full_kkt_dimension
    error("stageA1:index:FullKktDimensionMismatch", ...
        "Expected full KKT dimension %d; built %d.", ...
        stageConfig.expected_full_kkt_dimension,index.counts.full_kkt_dimension);
end
hourBlocks = index.block_index(index.block_index.day == 1 & ...
    ismember(index.block_index.hour_start,stageConfig.hours),:);
[~,order] = sort(hourBlocks.hour_start);
hourBlocks = hourBlocks(order,:);
actualBlockDimensions = reshape(hourBlocks.kkt_block_dimension,1,[]);
if ~isequal(actualBlockDimensions, ...
        stageConfig.expected_hourly_kkt_block_dimensions)
    error("stageA1:index:HourlyBlockDimensionMismatch", ...
        "Expected A1 hourly KKT blocks %s; built %s.", ...
        mat2str(stageConfig.expected_hourly_kkt_block_dimensions), ...
        mat2str(actualBlockDimensions));
end
end
