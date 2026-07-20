function config = read_stage_a1_window_config(configPath)
%READ_STAGE_A1_WINDOW_CONFIG Read the frozen flat A1 YAML fields.
% This narrow reader intentionally accepts only the scalar/list fields used
% to construct and audit the A1 index.  It is not a general YAML parser.

configPath = string(configPath);
if ~isscalar(configPath) || strlength(configPath) == 0 || ~isfile(configPath)
    error("stageA1:index:ConfigMissing", ...
        "A1 configuration file does not exist: %s",configPath);
end

rawText = string(fileread(configPath));
lines = splitlines(rawText);
values = containers.Map("KeyType","char","ValueType","char");
for lineIndex = 1:numel(lines)
    line = strip(lines(lineIndex));
    if strlength(line) == 0 || startsWith(line,"#")
        continue
    end
    colon = strfind(char(line),':');
    if isempty(colon)
        error("stageA1:index:ConfigSyntax", ...
            "Malformed flat YAML line %d in %s.",lineIndex,configPath);
    end
    key = char(strip(extractBefore(line,colon(1))));
    value = char(strip(extractAfter(line,colon(1))));
    if isKey(values,key)
        error("stageA1:index:DuplicateConfigKey", ...
            "Duplicate A1 configuration key '%s'.",key);
    end
    values(key) = value;
end

config = struct();
config.stage_id = parse_string(values,"stage_id");
config.days = parse_numeric_list(values,"days");
config.hours = parse_numeric_list(values,"hours");
config.window_type = parse_string(values,"window_type");
config.start_hour = parse_numeric_scalar(values,"start_hour");
config.terminal_hour = parse_numeric_scalar(values,"terminal_hour");
config.soc_boundary_mode = parse_string(values,"soc_boundary_mode");
config.terminal_soc_equality_count = ...
    parse_numeric_scalar(values,"terminal_soc_equality_count");
config.expected_full_kkt_dimension = ...
    parse_numeric_scalar(values,"expected_full_kkt_dimension");
config.expected_hourly_kkt_block_dimensions = ...
    parse_numeric_list(values,"expected_hourly_kkt_block_dimensions");
end

function value = required_value(values,key)
if ~isKey(values,key)
    error("stageA1:index:MissingConfigKey", ...
        "A1 configuration is missing required key '%s'.",key);
end
value = string(values(key));
end

function value = parse_string(values,key)
value = strip(required_value(values,key));
if startsWith(value,'"') && endsWith(value,'"') && strlength(value) >= 2
    value = extractBetween(value,2,strlength(value)-1);
end
if ~isscalar(value) || strlength(value) == 0
    error("stageA1:index:InvalidConfigString", ...
        "A1 configuration key '%s' must be a nonempty string scalar.",key);
end
end

function value = parse_numeric_scalar(values,key)
text = strip(required_value(values,key));
value = str2double(text);
if ~isscalar(value) || ~isfinite(value)
    error("stageA1:index:InvalidConfigNumber", ...
        "A1 configuration key '%s' must be a finite numeric scalar.",key);
end
end

function valuesOut = parse_numeric_list(values,key)
text = strip(required_value(values,key));
if ~startsWith(text,"[") || ~endsWith(text,"]")
    error("stageA1:index:InvalidConfigList", ...
        "A1 configuration key '%s' must be a bracketed numeric list.",key);
end
body = strip(extractBetween(text,2,strlength(text)-1));
if strlength(body) == 0
    valuesOut = zeros(1,0);
    return
end
parts = strip(split(body,","));
valuesOut = reshape(str2double(parts),1,[]);
if any(~isfinite(valuesOut))
    error("stageA1:index:InvalidConfigList", ...
        "A1 configuration key '%s' contains a nonnumeric value.",key);
end
end
