function result = solve_stage_a3_recursive_direction(lin,options)
%SOLVE_STAGE_A3_RECURSIVE_DIRECTION Compute one seven-day direction.
% This interface cannot receive a direction from the audit route.

arguments
    lin (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
    options.SymmetryTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
end

layer = "inequality_elimination";
try
    reduced = eliminate_stage_a3_inequality_directions(lin);
    layer = "seven_day_partition";
    partition = partition_stage_a3_recursive_system(lin,reduced, ...
        AssemblyTolerance=options.AssemblyTolerance);
    nDays = numel(partition.day);
    for d = 1:nDays
        layer = sprintf("day_%d_block_ldl_thomas",partition.day(d).day_id);
        thomas = solve_block_thomas_ldl(partition.day(d), ...
            SymmetryTolerance=options.SymmetryTolerance);
        layer = sprintf("day_%d_response",partition.day(d).day_id);
        response = form_stage_a3_day_response(partition.day(d),thomas);
        if d==1
            dailyThomas = thomas;
            dailyResponses = response;
        else
            dailyThomas(d,1) = thomas;
            dailyResponses(d,1) = response;
        end
        if response.diagnostics.symmetry_relative > ...
                options.SymmetryTolerance
            error("stageA3:solver:DayResponseAsymmetry", ...
                "Day %d response symmetry error %.17g exceeds %.17g; " + ...
                "no matrix modification was applied.", ...
                partition.day(d).day_id, ...
                response.diagnostics.symmetry_relative, ...
                options.SymmetryTolerance);
        end
    end
    layer = "sorted_day_response_aggregation";
    exerciseOrder = [4,1,7,2,6,3,5];
    aggregation = aggregate_stage_a3_day_responses( ...
        dailyResponses(exerciseOrder),partition.days);
    layer = "global_core_16";
    core = solve_stage_a3_core16_ldl(partition,aggregation, ...
        SymmetryTolerance=options.SymmetryTolerance);
    layer = "strict_reverse_recovery";
    recovery = recover_stage_a3_recursive_direction( ...
        lin,partition,dailyResponses,core);
    layer = "full_kkt_reinsertion";
    fullAssembly = assemble_stage_a3_full_kkt(lin);
    residual = fullAssembly.matrix*recovery.direction-fullAssembly.rhs;
catch cause
    wrapped = MException("stageA3:solver:RecursiveLayerFailure", ...
        "A3 recursion failed first at layer '%s': %s",layer,cause.message);
    wrapped = addCause(wrapped,cause);
    throw(wrapped);
end

relativeResidual = norm(residual,2)/max(1,norm(fullAssembly.rhs,2));
[maxAbsoluteResidual,maxResidualRow] = max(abs(residual));
result = struct();
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
end
