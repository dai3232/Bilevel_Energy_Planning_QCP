
function audit = verify_stage_a_multiday_direction_equivalence( ...
        fullResult,recursiveResult,lin,thresholds)
%VERIFY_STAGE_A_MULTIDAY_DIRECTION_EQUIVALENCE Audit canonical directions.

arguments
    fullResult (1,1) struct
    recursiveResult (1,1) struct
    lin (1,1) struct
    thresholds.DirectionRelative (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.RecursiveResidual (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-10
    thresholds.FullResidualPreferred (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
    thresholds.FullResidualMaximum (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-10
end
contract = rkkt.solver.stage_a_multiday_linearization_contract(lin);
assert(isequal(fullResult.linearization_identity,contract.identity) && ...
    isequal(recursiveResult.linearization_identity,contract.identity), ...
    "stageAMultiday:solver:LinearizationIdentityMismatch", ...
    "formal multi-day directions do not share the linearization identity.");
assembly = fullResult.kkt;
fullDirection = fullResult.direction(:);
recursiveDirection = recursiveResult.direction(:);
assert(numel(fullDirection)==assembly.dimension && ...
    numel(recursiveDirection)==assembly.dimension, ...
    "stageAMultiday:solver:DirectionDimension", ...
    "formal multi-day directions must match the canonical KKT dimension.");

componentErrors = struct();
for name = ["xi","y","l","z"]
    rows = assembly.slices.(name);
    componentErrors.(name) = relative_error( ...
        recursiveDirection(rows),fullDirection(rows));
end
overallError = relative_error(recursiveDirection,fullDirection);
fullResidualVector = assembly.matrix*fullDirection-assembly.rhs;
recursiveResidualVector = assembly.matrix*recursiveDirection-assembly.rhs;
fullResidual = norm(fullResidualVector,2)/max(1,norm(assembly.rhs,2));
recursiveResidual = norm(recursiveResidualVector,2)/max(1,norm(assembly.rhs,2));

rowResiduals = struct();
rowNames = ["stationarity_rows","equality_rows", ...
    "slack_rows","complementarity_rows"];
outputNames = ["stationarity","equality","slack","complementarity"];
for k = 1:numel(rowNames)
    rows = assembly.slices.(rowNames(k));
    rowResiduals.(outputNames(k)) = struct( ...
        "full_relative",norm(fullResidualVector(rows),2)/ ...
            max(1,norm(assembly.rhs(rows),2)), ...
        "recursive_relative",norm(recursiveResidualVector(rows),2)/ ...
            max(1,norm(assembly.rhs(rows),2)), ...
        "full_max_absolute",max(abs(fullResidualVector(rows))), ...
        "recursive_max_absolute",max(abs(recursiveResidualVector(rows))));
end

[maxDirectionDifference,maxDirectionIndex] = ...
    max(abs(recursiveDirection-fullDirection));
[maxRecursiveResidual,maxRecursiveRow] = max(abs(recursiveResidualVector));
[maxFullResidual,maxFullRow] = max(abs(fullResidualVector));
audit = struct();
audit.stage_id = contract.stage_id;
audit.linearization_identity = contract.identity;
audit.direction_relative_error = overallError;
audit.component_relative_errors = componentErrors;
audit.full_kkt_relative_residual = fullResidual;
audit.recursive_kkt_relative_residual = recursiveResidual;
audit.row_block_residuals = rowResiduals;
audit.maximum_direction_difference = struct( ...
    "absolute_value",maxDirectionDifference, ...
    "canonical_index",maxDirectionIndex, ...
    "location",describe_direction_component( ...
        maxDirectionIndex,lin,contract));
audit.maximum_recursive_residual = struct( ...
    "absolute_value",maxRecursiveResidual,"row",maxRecursiveRow, ...
    "location",describe_kkt_row(maxRecursiveRow,lin,contract));
audit.maximum_full_residual = struct( ...
    "absolute_value",maxFullResidual,"row",maxFullRow, ...
    "location",describe_kkt_row(maxFullRow,lin,contract));
audit.thresholds = thresholds;
audit.passed = struct( ...
    "direction",overallError<=thresholds.DirectionRelative, ...
    "recursive_residual",recursiveResidual<=thresholds.RecursiveResidual, ...
    "full_residual_preferred",fullResidual<=thresholds.FullResidualPreferred, ...
    "full_residual_hard",fullResidual<=thresholds.FullResidualMaximum, ...
    "fixed_zero_exact",recursiveResult.fixed_zero.all_exact_zero, ...
    "day_sort_invariant",recursiveResult.aggregation.order_invariant_passed, ...
    "no_full_direction_fallback", ...
        recursiveResult.no_full_direction_fallback && ...
        ~recursiveResult.full_direction_consumed);
audit.all_blocking_pass = audit.passed.direction && ...
    audit.passed.recursive_residual && audit.passed.full_residual_hard && ...
    audit.passed.fixed_zero_exact && audit.passed.day_sort_invariant && ...
    audit.passed.no_full_direction_fallback;
end

function value = relative_error(actual,reference)
value = norm(actual-reference,2)/max(1,norm(reference,2));
end

function location = describe_direction_component(index,lin,contract)
if index<=contract.nx
    location = describe_index("xi",index,lin.index,"variable");
elseif index<=contract.nx+contract.neq
    location = describe_index("y",index-contract.nx,lin.index,"equality");
elseif index<=contract.nx+contract.neq+contract.nineq
    location = describe_index("l", ...
        index-contract.nx-contract.neq,lin.index,"inequality");
else
    location = describe_index("z", ...
        index-contract.nx-contract.neq-contract.nineq, ...
        lin.index,"inequality");
end
end

function location = describe_kkt_row(row,lin,contract)
if row<=contract.nx
    location = describe_index("stationarity",row,lin.index,"variable");
elseif row<=contract.nx+contract.neq
    location = describe_index("equality",row-contract.nx, ...
        lin.index,"equality");
elseif row<=contract.nx+contract.neq+contract.nineq
    location = describe_index("slack_equation", ...
        row-contract.nx-contract.neq,lin.index,"inequality");
else
    location = describe_index("complementarity", ...
        row-contract.nx-contract.neq-contract.nineq, ...
        lin.index,"inequality");
end
end

function location = describe_index(space,localIndex,index,objectType)
location = struct("space",space,"local_index",localIndex, ...
    "object_name","","day",NaN,"hour",NaN, ...
    "asset_type","","asset_id",NaN);
if ~isstruct(index)
    return
end
if objectType=="variable" && isfield(index,"variable_index") && ...
        istable(index.variable_index) && ...
        height(index.variable_index)>=localIndex
    row = index.variable_index(localIndex,:);
elseif isfield(index,"constraint_index") && istable(index.constraint_index)
    tableValue = index.constraint_index;
    names = string(tableValue.Properties.VariableNames);
    if any(names=="constraint_type")
        tableValue = tableValue( ...
            string(tableValue.constraint_type)==objectType,:);
    end
    if height(tableValue)<localIndex
        return
    end
    row = tableValue(localIndex,:);
else
    return
end
names = string(row.Properties.VariableNames);
if objectType=="variable" && any(names=="variable_name")
    location.object_name = string(row.variable_name(1));
elseif any(names=="constraint_id")
    location.object_name = string(row.constraint_id(1));
end
if any(names=="day"), location.day = double(row.day(1)); end
if any(names=="hour"), location.hour = double(row.hour(1)); end
if any(names=="asset_type")
    location.asset_type = string(row.asset_type(1));
end
if any(names=="asset_id")
    location.asset_id = double(row.asset_id(1));
end
end
