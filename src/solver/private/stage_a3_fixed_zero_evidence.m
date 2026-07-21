function evidence = stage_a3_fixed_zero_evidence(index)
%STAGE_A3_FIXED_ZERO_EVIDENCE Validate exact removed-variable recovery.

map = [];
count = 0;
if isstruct(index) && isfield(index,"fixed_zero_map")
    map = index.fixed_zero_map;
    if istable(map)
        count = height(map);
    elseif isstruct(map)
        count = numel(map);
    elseif ~isempty(map)
        count = size(map,1);
    end
end
value = zeros(count,1);
direction = zeros(count,1);
if istable(map)
    names = string(map.Properties.VariableNames);
    assert(count==0 || all(ismember( ...
        ["fixed_value","fixed_direction_value"],names)), ...
        "stageA3:solver:FixedZeroColumns", ...
        "A nonempty fixed-zero map needs exact value and direction columns.");
    if count>0
        value = double(map.fixed_value(:));
        direction = double(map.fixed_direction_value(:));
    end
elseif isstruct(map) && count>0
    assert(isfield(map,"fixed_value") && ...
        isfield(map,"fixed_direction_value"), ...
        "stageA3:solver:FixedZeroFields", ...
        "A nonempty fixed-zero map needs exact value and direction fields.");
    value = reshape(double([map.fixed_value]),[],1);
    direction = reshape(double([map.fixed_direction_value]),[],1);
end
assert(numel(value)==count && numel(direction)==count && ...
    all(value==0) && all(direction==0), ...
    "stageA3:solver:FixedZeroNonzero", ...
    "Every removed renewable value and direction must be exact zero.");

evidence = struct("count",count,"map",map,"value",value, ...
    "direction",direction,"all_exact_zero",true, ...
    "maximum_absolute_value",0,"maximum_absolute_direction",0, ...
    "inequality_directions_applicable",false(count,1));
end
