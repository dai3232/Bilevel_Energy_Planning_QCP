function [solution,byHour,diagnostics] = ...
        apply_retained_block_thomas_once( ...
        partition,factors,multipliers,rhs,label)
%APPLY_RETAINED_BLOCK_THOMAS_ONCE Apply one frozen Thomas inverse map.
%
% No factorization is performed.  The caller supplies the factors and
% elimination multipliers created by the initial official Thomas solve.

arguments
    partition (1,1) struct
    factors (:,1) cell
    multipliers (:,1) cell
    rhs {mustBeNumeric,mustBeReal}
    label (1,1) string
end

nHours = numel(partition.hour);
assert(numel(factors)==nHours && numel(multipliers)==nHours && ...
    size(rhs,1)==size(partition.M,1), ...
    "stageA:RNS1:RetainedThomasContext", ...
    "The retained Thomas context does not match the raw day chain.");
forward = cell(nHours,1);
byHour = cell(nHours,1);
solveDiagnostics = cell(nHours,1);

for t = 1:nHours
    rows = partition.block_offsets.start_index(t): ...
        partition.block_offsets.end_index(t);
    current = rhs(rows,:);
    if t==1
        forward{t} = current;
    else
        forward{t} = current-multipliers{t}*forward{t-1};
    end
end
for t = nHours:-1:1
    current = forward{t};
    if t<nHours
        current = current-partition.hour(t+1).E.'*byHour{t+1};
    end
    [byHour{t},solveDiagnostics{t}] = solve_with_ldl_factor( ...
        factors{t},current,label+"_hour_"+string(partition.hour(t).hour));
end
solution = vertcat(byHour{:});
assert(all(isfinite(solution),"all"), ...
    "stageA:RNS1:RetainedThomasNonfinite", ...
    "The retained Thomas inverse map produced NaN or Inf.");
diagnostics = struct( ...
    "label",label, ...
    "rhs_count",size(rhs,2), ...
    "forward_rhs",{forward}, ...
    "back_solve",{solveDiagnostics}, ...
    "additional_factorization_count",0, ...
    "direct_chain_backslash_used",false, ...
    "full_kkt_direction_consumed",false);
end
