function result = apply_stage_b2c_lagrangian_hessian(lin,vector)
%APPLY_STAGE_B2C_LAGRANGIAN_HESSIAN Apply the local water Hessians.

arguments
    lin (1,1) struct
    vector (:,1) double
end
if ~isfield(lin,"storage_mode") || lin.storage_mode~="recursive_daily_blocks"
    result = sparse(lin.H)*vector;
    return
end
assert(numel(vector)==lin.counts.primal, ...
    "stageB2C:blockH:Dimension","H input has an invalid length.");
result = zeros(lin.counts.primal,1);
for d = 1:numel(lin.blocks.day)
    block = lin.blocks.day(d);
    result(block.primal_indices) = ...
        block.H*vector(block.primal_indices);
end
end
