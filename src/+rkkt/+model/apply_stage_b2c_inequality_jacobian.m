function result = apply_stage_b2c_inequality_jacobian(lin,vector,options)
%APPLY_STAGE_B2C_INEQUALITY_JACOBIAN Apply G or G' by independent blocks.

arguments
    lin (1,1) struct
    vector (:,1) double
    options.Transpose (1,1) logical = false
end
if ~isfield(lin,"storage_mode") || lin.storage_mode~="recursive_daily_blocks"
    if options.Transpose, result = sparse(lin.G).'*vector;
    else, result = sparse(lin.G)*vector; end
    return
end
if options.Transpose
    assert(numel(vector)==lin.counts.inequalities, ...
        "stageB2C:blockG:Dimension","G' input has an invalid length.");
    result = zeros(lin.counts.primal,1);
    q = lin.maps.q_global;
    rows = lin.blocks.global_block.inequality_rows;
    result(q) = lin.blocks.global_block.G.'*vector(rows);
    for d = 1:numel(lin.blocks.day)
        block = lin.blocks.day(d);
        result(block.primal_indices) = ...
            result(block.primal_indices)+ ...
            block.G_base.'*vector(block.base_inequality_rows)+ ...
            block.G_water.'*vector(block.water_rows);
    end
else
    assert(numel(vector)==lin.counts.primal, ...
        "stageB2C:blockG:Dimension","G input has an invalid length.");
    result = zeros(lin.counts.inequalities,1);
    q = lin.maps.q_global;
    rows = lin.blocks.global_block.inequality_rows;
    result(rows) = lin.blocks.global_block.G*vector(q);
    for d = 1:numel(lin.blocks.day)
        block = lin.blocks.day(d);
        local = vector(block.primal_indices);
        result(block.base_inequality_rows) = block.G_base*local;
        result(block.water_rows) = block.G_water*local;
    end
end
end
