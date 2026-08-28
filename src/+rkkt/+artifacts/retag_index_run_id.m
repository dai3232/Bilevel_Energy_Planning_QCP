function value = retag_index_run_id(index,runId)
%RETAG_INDEX_RUN_ID Create a run-evidence view of one cached index.

arguments
    index (1,1) struct
    runId (1,1) string
end
value = index;
tableFields = ["variable_index","constraint_index","block_index", ...
    "fixed_zero_map","permutation_map","soc_link_map", ...
    "water_constraint_index"];
for name = tableFields
    if isfield(value,name) && istable(value.(name)) && ...
            ismember("run_id",string(value.(name).Properties.VariableNames))
        value.(name).run_id(:) = cast_run_id(value.(name).run_id,runId);
    end
end
if isfield(value,"stage_a_base_index")
    value.stage_a_base_index = rkkt.artifacts.retag_index_run_id( ...
        value.stage_a_base_index,runId);
end
end

function result = cast_run_id(column,runId)
if iscell(column)
    result = repmat({char(runId)},numel(column),1);
elseif isstring(column)
    result = repmat(runId,numel(column),1);
elseif iscategorical(column)
    result = categorical(repmat(runId,numel(column),1));
else
    error("rkkt:index:RunIdType", ...
        "Unsupported run_id column type %s.",class(column));
end
end
