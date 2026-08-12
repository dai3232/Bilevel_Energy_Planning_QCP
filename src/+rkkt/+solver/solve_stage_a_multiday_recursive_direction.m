%本函数不负责去原始建立完整KKT
function result = solve_stage_a_multiday_recursive_direction(lin,options)
%SOLVE_STAGE_A_MULTIDAY_RECURSIVE_DIRECTION Compute one seven-day direction.
% This interface cannot receive a direction from the audit route.

%lin是已经包含内点迭代需要的线性化信息。
%%
%H                 拉格朗日函数 Hessian
%A                 等式约束 Jacobian
%G                 不等式约束 Jacobian
%r_dual            驻点残差
%r_eq              等式约束残差
%r_ineq            松弛等式残差
%r_comp            互补残差
%xi、y、l、z        当前原始—对偶状态
arguments
    lin (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
    options.ResponseInputOrder (1,:) double {mustBeInteger,mustBePositive} = zeros(1,0)
    options.ResidualRefinementMaxPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 0
    options.UseCongruenceScaling (1,1) logical = false
    options.EquilibrationPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 8
end
%%
%| 参数                            | 作用             |
%| ----------------------------- | -------------- |
%| `AssemblyTolerance`           | 分块和矩阵组装时使用的容差  |
%| `SymmetryTolerance`           | 检查矩阵或日响应是否保持对称 |
%| `ResponseInputOrder`          | 控制各天响应进入聚合器的顺序 |
%| `ResidualRefinementMaxPasses` | LDL 求解后的残差修正次数 |
%| `UseCongruenceScaling`        | 是否对矩阵进行合同缩放    |
%| `EquilibrationPasses`         | 矩阵平衡缩放次数       |

assert(options.ResidualRefinementMaxPasses<=3, ...
    "stageA:RNS1:MultidayRefinementPassLimit", ...
    "Stage-A retained-factor refinement permits at most three passes.");
%%获取线性化契约和阶段身份
contract = rkkt.solver.stage_a_multiday_linearization_contract(lin);%这个函数是检查 lin 是否满足多日递推求解器所要求的数据契约
%获取id，当发生错误标明具体的错误
stageId = contract.stage_id;

%%
%solve_stage_a_multiday_recursive_direction
%│
%├─ 1. stage_a_multiday_linearization_contract
%│
%├─ 2. eliminate_stage_a_multiday_inequality_directions
%│
%├─ 3. partition_stage_a_multiday_recursive_system
%│
%├─ 4. 对每一天循环
%│    ├─ solve_block_thomas_ldl
%│    └─ form_stage_a_multiday_day_response
%│
%├─ 5. aggregate_stage_a_multiday_day_responses
%│
%├─ 6. solve_stage_a_multiday_core16_ldl
%│
%├─ 7. recover_stage_a_multiday_recursive_direction
%│
%├─ 8. assemble_stage_a_multiday_full_kkt
%│
%└─ 9. 用完整 KKT 计算残差
%%3. 记录求解当前执行到哪一层
%%第1层：消去不等式变量方向
layer = "inequality_elimination";
try
    reduced = rkkt.solver.eliminate_stage_a_multiday_inequality_directions(lin);
    layer = "seven_day_partition";
    partition = rkkt.solver.partition_stage_a_multiday_recursive_system(lin,reduced, ...
        AssemblyTolerance=options.AssemblyTolerance);
    nDays = numel(partition.day);
    for d = 1:nDays
        layer = sprintf("day_%d_block_ldl_thomas",partition.day(d).day_id);
        thomas = rkkt.solver.solve_block_thomas_ldl(partition.day(d), ...
            SymmetryTolerance=options.SymmetryTolerance, ...
            ResidualRefinementMaxPasses= ...
                options.ResidualRefinementMaxPasses, ...
            UseCongruenceScaling=options.UseCongruenceScaling, ...
            EquilibrationPasses=options.EquilibrationPasses);
        layer = sprintf("day_%d_response",partition.day(d).day_id);
        response = rkkt.solver.form_stage_a_multiday_day_response(partition.day(d),thomas);
        if d==1
            dailyThomas = thomas;
            dailyResponses = response;
        else
            dailyThomas(d,1) = thomas;
            dailyResponses(d,1) = response;
        end
        if response.diagnostics.symmetry_relative > ...
                options.SymmetryTolerance
            error("stageAMultiday:solver:DayResponseAsymmetry", ...
                "Day %d response symmetry error %.17g exceeds %.17g; " + ...
                "no matrix modification was applied.", ...
                partition.day(d).day_id, ...
                response.diagnostics.symmetry_relative, ...
                options.SymmetryTolerance);
        end
    end
    layer = "sorted_day_response_aggregation";
    responseInputOrder = options.ResponseInputOrder;
    if isempty(responseInputOrder)
        responseInputOrder = 1:nDays;
    end
    assert(numel(responseInputOrder)==nDays && ...
        isequal(sort(responseInputOrder),1:nDays), ...
        "stageAMultiday:solver:ResponseInputOrder", ...
        "ResponseInputOrder must be a permutation of 1:%d.",nDays);
    aggregation = rkkt.solver.aggregate_stage_a_multiday_day_responses( ...
        dailyResponses(responseInputOrder),partition.days);
    layer = "global_core_16";
    core = rkkt.solver.solve_stage_a_multiday_core16_ldl(partition,aggregation, ...
        SymmetryTolerance=options.SymmetryTolerance, ...
        ResidualRefinementMaxPasses= ...
            options.ResidualRefinementMaxPasses, ...
        UseCongruenceScaling=options.UseCongruenceScaling, ...
        EquilibrationPasses=options.EquilibrationPasses);
    layer = "strict_reverse_recovery";
    recovery = rkkt.solver.recover_stage_a_multiday_recursive_direction( ...
        lin,partition,dailyResponses,core);
    layer = "full_kkt_reinsertion";
    fullAssembly = rkkt.solver.assemble_stage_a_multiday_full_kkt(lin);
    residual = fullAssembly.matrix*recovery.direction-fullAssembly.rhs;
catch cause
    wrapped = MException("stageAMultiday:solver:RecursiveLayerFailure", ...
        "%s recursion failed first at layer '%s': %s", ...
        stageId,layer,cause.message);
    wrapped = addCause(wrapped,cause);
    throw(wrapped);
end


relativeResidual = norm(residual,2)/max(1,norm(fullAssembly.rhs,2));
[maxAbsoluteResidual,maxResidualRow] = max(abs(residual));
result = struct();
result.stage_id = stageId;
result.method = "seven_day_recursive_block_ldl_thomas";
result.linearization_identity = recovery.linearization_identity;
result.direction = recovery.direction;
result.components = recovery.components;
result.fixed_zero = recovery.fixed_zero;
result.reduced = reduced;
result.partition = partition;
result.daily_partitions = partition.day;
result.daily_thomas = dailyThomas;
result.daily_responses = dailyResponses;
result.aggregation = aggregation;
result.core = core;
result.recovery = recovery.diagnostics;
result.full_kkt_reinsertion = struct( ...
    "relative_residual",relativeResidual, ...
    "max_absolute_residual",maxAbsoluteResidual, ...
    "max_residual_row",maxResidualRow, ...
    "residual",residual,"rhs_norm_2",norm(fullAssembly.rhs,2));
result.no_full_direction_fallback = true;
result.full_direction_consumed = false;
result.parallel_executed = false;
result.residual_refinement = struct( ...
    "maximum_passes",options.ResidualRefinementMaxPasses, ...
    "daily",{reshape(arrayfun(@(item) ...
        item.diagnostics.residual_refinement,dailyThomas),[],1)}, ...
    "core",core.diagnostics.residual_refinement, ...
    "uniform_shared_solver_path",true);
result.congruence_scaling = struct( ...
    "used",options.UseCongruenceScaling, ...
    "configured_equilibration_passes",options.EquilibrationPasses, ...
    "equilibration_passes", ...
        options.EquilibrationPasses*options.UseCongruenceScaling, ...
    "original_operator_retained_for_residual_audit",true, ...
    "automatic_symmetrization_used",false, ...
    "regularization_used",false);
end
