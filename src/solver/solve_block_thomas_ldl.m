function result = solve_block_thomas_ldl(partition, options)
%SOLVE_BLOCK_THOMAS_LDL Solve [r|B] with one LDL factor per hour block.
%输入是小时链分块 partition 和名称值选项 options，
%输出统一放进 result，
arguments       %参数验证块
    partition (1,1) struct  %partition是一个标量结构体
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12%定义对称性容差，必须是有限、非负标量，默认 1e-12。
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0           %要求精化次数是非负整数，默认关闭，即 0 次。
end             %结束参数验证块。
assert(options.ResidualRefinementMaxPasses<=3, ...  %若断言失败，则弹出下面这一行的错误日志
    "stageA:RNS1:ThomasRefinementPassLimit", ...
    "Stage-A retained-factor refinement permits at most three passes.");

nHours = numel(partition.hour); %读取 partition.hour 中的小时块数量。
assert(nHours >= 1, "stageA1:solver:EmptyThomasChain", ...%断言至少有一个小时块。
    "Block Thomas requires at least one hour block.");

schur = cell(nHours,1);         %先创建一个小时×1的列向量-为每个小时的有效Schru主元S_t创建cell数组
multipliers = cell(nHours,1);   %为前向消元乘子L_t创建cell数组
forwardRhs = cell(nHours,1);    %为前向消元后的右端 G_t 创建 cell 数组。
solutions = cell(nHours,1);     %为每小时最终解 X_t 创建 cell 数组。
factors = cell(nHours,1);       %保存每个 S_t 的 LDL 分解及相关信息。
factorDiagnostics = cell(nHours,1);     %保存去掉大型矩阵后的因子诊断信息。
multiplierSolveDiagnostics = cell(nHours,1);
backSolveDiagnostics = cell(nHours,1);
hourBlockDiagnostics = repmat(empty_hour_block_diagnostics(),nHours,1);

for t = 1:nHours        %从第一个小时开始执行前向消元。v
    block = partition.hour(t);    %取出当前小时结构体，后续用 block 简化访问。
    assert(size(block.B,2) == 14, "stageA1:solver:ThomasCapacityColumns", ...
        "Hour %d B block must have 14 capacity columns.", block.hour);
    currentF = [block.r, block.B];%把一列 r 和十四列 B 横向拼接成 currentF，所以一次求 15 个右端。
    assert(size(currentF,2) == 15, "stageA1:solver:ThomasRhsCount", ...
        "Hour %d must have exactly 15 Thomas right-hand sides.", block.hour);

    if t == 1       %判断当前是不是链首小时。
        schur{t} = block.D;    %首小时没有前驱块，所以有效主元直接是 S_1=D_1
        multipliers{t} = sparse(0,0);   %首小时没有消元乘子，用 0×0 稀疏矩阵作明确占位。
        forwardRhs{t} = currentF;       %首小时的前向右端不需要修正，即 G_1=F_1。
    else            %其余小时进入一般前向消元分支。
        previousHour = partition.hour(t-1).hour;    %取前一个块的物理小时编号，用于诊断标签。它比直接使用 t-1 更可靠，因为测试窗小时不一定从 1 开始。
        try
            [solvedTranspose,solveDiag] = solve_with_ldl_factor( ...      %调用 solve_with_ldl_factor，复用上一小时已经得到的 LDL 因子。
                factors{t-1}, block.E.', ...
                sprintf("hour_%d_to_%d_multiplier", previousHour, block.hour));
        catch cause
            throw(hour_failure(cause,block,"interface_multiplier"));
        end
        multipliers{t} = solvedTranspose.';   %把求得的 Y 转置，得到消元乘子，
        multiplierSolveDiagnostics{t} = solveDiag;%保存这次多右端 LDL 求解的残差和警告诊断。
        schur{t} = block.D - multipliers{t} * block.E.';%计算当前有效 Schur 主元
        forwardRhs{t} = currentF - multipliers{t} * forwardRhs{t-1};%同步消去前一小时未知量，得到新右端
    end                                       %结束首小时/一般小时分支。

    label = sprintf("hour_%d_schur_pivot", block.hour);
    try
        factors{t} = factor_symmetric_ldl(schur{t}, label, options.SymmetryTolerance);%调用 factor_symmetric_ldl 分解 S_t，同时执行对称性、秩、条件数、惯性和非有限值检查。
    catch cause
        throw(hour_failure(cause,block,"schur_pivot_factorization"));
    end
    factorDiagnostics{t} = strip_factor_matrices(factors{t});%复制因子诊断信息，但删掉原矩阵和 L/D 等大型字段，避免诊断结构重复存储矩阵。
    hourBlockDiagnostics(t) = build_hour_block_diagnostics( ...
        block,factors{t},size(currentF,2));
end  %结束前向小时循环。此时所有 S_t、L_t 和 G_t 都已得到

%%执行反向回代   空行，分隔前向消元与反向回代。
for t = nHours:-1:1   %从最后一个小时倒序回代到第一个小时。
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


%AI写的诊断报告，可以不用看，只是生成字段而已
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
