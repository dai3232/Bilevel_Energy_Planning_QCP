function solution = apply_stage_b2b_retained_chain_rhs(day,thomas,rhs)
%APPLY_STAGE_B2B_RETAINED_CHAIN_RHS Solve extra RHS using retained factors.
%
% No block is factored here.  The same Schur pivots and Thomas elimination
% multipliers produced for the physical/capacity RHS are reused for the
% eight daily-water border RHS columns.

arguments
    day (1,1) struct
    thomas (1,1) struct
    rhs (:,:) double
end
assert(size(rhs,1)==size(day.M,1) && size(rhs,2)>=1, ...
    "stageB2B:retainedRhs:Shape","Extra chain RHS has invalid shape.");
nHours = numel(day.hour);
offsets = day.block_offsets;
forward = cell(nHours,1);
for t = 1:nHours
    rows = offsets.start_index(t):offsets.end_index(t);
    current = rhs(rows,:);
    if t>1
        current = current-thomas.elimination_multipliers{t}*forward{t-1};
    end
    forward{t} = current;
end
solutions = cell(nHours,1);
for t = nHours:-1:1
    current = forward{t};
    if t<nHours
        current = current-day.hour(t+1).E.'*solutions{t+1};
    end
    [solutions{t},~] = solve_with_ldl_factor( ...
        thomas.factors{t},current, ...
        "stageB2B_extra_rhs_hour_"+string(day.hour(t).hour));
end
solution = vertcat(solutions{:});
residual = day.M*solution-rhs;
assert(all(isfinite(solution),"all") && ...
    norm(residual,"fro")/max(1,norm(rhs,"fro"))<=1e-10, ...
    "stageB2B:retainedRhs:Residual", ...
    "Retained-factor extra RHS residual exceeded 1e-10.");
end
