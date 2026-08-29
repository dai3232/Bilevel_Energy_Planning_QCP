function result = apply_stage_b2c_equality_jacobian(lin,vector,options)
%APPLY_STAGE_B2C_EQUALITY_JACOBIAN Apply A or A' in either storage mode.

arguments
    lin (1,1) struct
    vector (:,1) double
    options.Transpose (1,1) logical = false
end
if ~isfield(lin,"storage_mode") || lin.storage_mode~="recursive_daily_blocks"
    if options.Transpose, result = sparse(lin.A).'*vector;
    else, result = sparse(lin.A)*vector; end
    return
end
if options.Transpose
    assert(numel(vector)==lin.counts.equalities, ...
        "stageB2C:blockA:Dimension","A' input has an invalid length.");
    result = zeros(lin.counts.primal,1);
    q = lin.maps.q_global;
    result(q) = lin.blocks.global_block.A.'*vector(lin.maps.y_duration);
    for d = 1:numel(lin.blocks.day)
        block = lin.blocks.day(d);
        result(block.primal_indices) = result(block.primal_indices)+ ...
            block.A_local.'*vector(block.equality_indices);
        result(q) = result(q)+ ...
            block.A_global.'*vector(block.equality_indices);
    end
else
    assert(numel(vector)==lin.counts.primal, ...
        "stageB2C:blockA:Dimension","A input has an invalid length.");
    result = zeros(lin.counts.equalities,1);
    q = lin.maps.q_global;
    result(lin.maps.y_duration) = lin.blocks.global_block.A*vector(q);
    for d = 1:numel(lin.blocks.day)
        block = lin.blocks.day(d);
        result(block.equality_indices) = ...
            block.A_local*vector(block.primal_indices)+ ...
            block.A_global*vector(q);
    end
end
end
