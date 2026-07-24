function result = solve_block_thomas_ldl(partition, options)
%SOLVE_BLOCK_THOMAS_LDL Solve [r|B] with one LDL factor per hour block.

arguments
    partition (1,1) struct
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
end
assert(options.ResidualRefinementMaxPasses<=3, ...
    "stageA:RNS1:ThomasRefinementPassLimit", ...
    "Stage-A retained-factor refinement permits at most three passes.");

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
hourBlockDiagnostics = repmat(empty_hour_block_diagnostics(),nHours,1);

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
    hourBlockDiagnostics(t) = build_hour_block_diagnostics( ...
        block,factors{t},size(currentF,2));
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

initialStackedSolution = vertcat(solutions{:});
[stackedSolution,solutions,refinementDiagnostics] = ...
    refine_block_thomas_solution( ...
    partition,factors,multipliers,initialStackedSolution, ...
    MaxPasses=options.ResidualRefinementMaxPasses);
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
    "hour_block",hourBlockDiagnostics, ...
    "factor",{factorDiagnostics}, ...
    "multiplier_solve",{multiplierSolveDiagnostics}, ...
    "back_solve",{backSolveDiagnostics}, ...
    "residual_refinement",refinementDiagnostics, ...
    "chain_relative_residual",chainRelativeResidual, ...
    "chain_max_absolute_residual",max(abs(chainResidual),[],"all"), ...
    "chain_residual",chainResidual);
end

function diagnostics = build_hour_block_diagnostics(block,factor,rhsCount)
% Record the original D block separately from its effective Thomas pivot.
% Both matrices are small hourly blocks; the full conversion is diagnostic
% only and never applies to the complete day chain or complete KKT matrix.
denseD = full(block.D);
diagnostics = empty_hour_block_diagnostics();
diagnostics.hour = block.hour;
diagnostics.dimension = block.dimension;
diagnostics.n_primal = block.n_primal;
diagnostics.n_equalities = block.n_equalities;
diagnostics.nnz_D = nnz(block.D);
diagnostics.D_symmetry_relative = norm(block.D-block.D.',"fro") / ...
    max(1,norm(block.D,"fro"));
diagnostics.D_numeric_rank = rank(denseD);
diagnostics.D_condition_2 = cond(denseD,2);
diagnostics.schur_nnz = factor.nnz;
diagnostics.schur_symmetry_relative = factor.symmetry_relative;
diagnostics.schur_numeric_rank = factor.numeric_rank;
diagnostics.schur_condition_2 = factor.condition_2;
diagnostics.schur_inertia_positive = factor.inertia_positive;
diagnostics.schur_inertia_negative = factor.inertia_negative;
diagnostics.schur_inertia_zero = factor.inertia_zero;
diagnostics.schur_factor_relative_residual = factor.factor_relative_residual;
diagnostics.schur_raw_to_factorized_operator_relative = ...
    factor.raw_to_factorized_operator_relative;
diagnostics.schur_actual_factorized_operator_reconstruction_exact = ...
    factor.actual_factorized_operator_reconstruction_exact;
diagnostics.rhs_count = rhsCount;
end

function diagnostics = empty_hour_block_diagnostics()
diagnostics = struct( ...
    "hour",0, ...
    "dimension",0, ...
    "n_primal",0, ...
    "n_equalities",0, ...
    "nnz_D",0, ...
    "D_symmetry_relative",NaN, ...
    "D_numeric_rank",0, ...
    "D_condition_2",NaN, ...
    "schur_nnz",0, ...
    "schur_symmetry_relative",NaN, ...
    "schur_numeric_rank",0, ...
    "schur_condition_2",NaN, ...
    "schur_inertia_positive",0, ...
    "schur_inertia_negative",0, ...
    "schur_inertia_zero",0, ...
    "schur_factor_relative_residual",NaN, ...
    "schur_raw_to_factorized_operator_relative",NaN, ...
    "schur_actual_factorized_operator_reconstruction_exact",false, ...
    "rhs_count",0);
end

function diagnostics = strip_factor_matrices(factor)
diagnostics = rmfield(factor, ...
    ["matrix","factorized_operator","L","D"]);
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
