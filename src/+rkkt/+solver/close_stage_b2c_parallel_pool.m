function close_stage_b2c_parallel_pool()
%CLOSE_STAGE_B2C_PARALLEL_POOL Close the active pool when configured.

pool = gcp("nocreate");
if ~isempty(pool)
    delete(pool);
end
end
