function result = solve_block_thomas_ldl(partition, options)
%SOLVE_BLOCK_THOMAS_LDL Solve [r|B] with one LDL factor per hour block.

arguments
    partition (1,1) struct
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
end

nHours = numel(partition.hour);
assert(nHours >= 1, "stageA1:solver:EmptyThomasChain", ...
    "Block Thomas requires at least one hour block.");

schur = cell(nHours,1);
multipliers = cell(nHours,1);
forwardRhs = cell(nHours,1);
solutions = cell(nHours,1);
factors = cell(nHours,1);
factorDiagnostics = cell(nHours,1);
multiplierSolveDiagnostics = cell(nHours,1);
backSolveDiagnostics = cell(nHours,1);

for t = 1:nHours
    block = partition.hour(t);
    assert(size(block.B,2) == 14, "stageA1:solver:ThomasCapacityColumns", ...
        "Hour %d B block must have 14 capacity columns.", block.hour);
    currentF = [block.r, block.B];
    assert(size(currentF,2) == 15, "stageA1:solver:ThomasRhsCount", ...
        "Hour %d must have exactly 15 Thomas right-hand sides.", block.hour);

    if t == 1
        schur{t} = block.D;
        multipliers{t} = sparse(0,0);
        forwardRhs{t} = currentF;
    else
        previousHour = partition.hour(t-1).hour;
        try
            [solvedTranspose,solveDiag] = solve_with_ldl_factor( ...
                factors{t-1}, block.E.', ...
                sprintf("hour_%d_to_%d_multiplier", previousHour, block.hour));
        catch cause
            throw(hour_failure(cause,block,"interface_multiplier"));
        end
        multipliers{t} = solvedTranspose.';
        multiplierSolveDiagnostics{t} = solveDiag;
        schur{t} = block.D - multipliers{t} * block.E.';
        forwardRhs{t} = currentF - multipliers{t} * forwardRhs{t-1};
    end

    label = sprintf("hour_%d_schur_pivot", block.hour);
    try
        factors{t} = factor_symmetric_ldl(schur{t}, label, options.SymmetryTolerance);
    catch cause
        throw(hour_failure(cause,block,"schur_pivot_factorization"));
    end
    factorDiagnostics{t} = strip_factor_matrices(factors{t});
end

for t = nHours:-1:1
    block = partition.hour(t);
    if t == nHours
        rhs = forwardRhs{t};
    else
        rhs = forwardRhs{t} - partition.hour(t+1).E.' * solutions{t+1};
    end
    try
        [solutions{t},backSolveDiagnostics{t}] = solve_with_ldl_factor( ...
            factors{t},rhs,sprintf("hour_%d_backward_15rhs",block.hour));
    catch cause
        throw(hour_failure(cause,block,"backward_15rhs"));
    end
end

stackedSolution = vertcat(solutions{:});
stackedRhs = [partition.r_v, partition.B];
chainResidual = partition.M * stackedSolution - stackedRhs;
chainRelativeResidual = norm(chainResidual,"fro") / max(1,norm(stackedRhs,"fro"));
if any(~isfinite(stackedSolution),"all")
    error("stageA1:solver:ThomasSolutionNonfinite", ...
        "Block Thomas produced NaN or Inf.");
end

result = struct();
result.linearization_identity = partition.linearization_identity;
result.rhs_count = size(stackedSolution,2);
result.schur_blocks = schur;
result.elimination_multipliers = multipliers;
result.forward_rhs = forwardRhs;
result.X_by_hour = solutions;
result.stacked_solution = stackedSolution;
result.factors = factors;
result.diagnostics = struct( ...
    "factor",{factorDiagnostics}, ...
    "multiplier_solve",{multiplierSolveDiagnostics}, ...
    "back_solve",{backSolveDiagnostics}, ...
    "chain_relative_residual",chainRelativeResidual, ...
    "chain_max_absolute_residual",max(abs(chainResidual),[],"all"), ...
    "chain_residual",chainResidual);
end

function diagnostics = strip_factor_matrices(factor)
diagnostics = rmfield(factor,["matrix","L","D"]);
end

function wrapped = hour_failure(cause,block,level)
message = "Hour %d failed at %s; xi indices=%s; equality indices=%s; " + ...
    "block dimension=%d. Cause: %s";
wrapped = MException("stageA1:solver:HourlyEliminationFailure", ...
    message, ...
    block.hour,level,mat2str(block.x_indices.'), ...
    mat2str(block.y_indices.'),block.dimension,cause.message);
wrapped = addCause(wrapped,cause);
end
