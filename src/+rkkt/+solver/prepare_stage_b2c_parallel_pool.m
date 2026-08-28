function info = prepare_stage_b2c_parallel_pool(settings)
%PREPARE_STAGE_B2C_PARALLEL_POOL Create or reuse the configured process pool.

arguments
    settings (1,1) struct
end

info = struct("enabled",logical(settings.parallel_enabled), ...
    "mode","serial","requested_worker_count",0,"worker_count",0, ...
    "action","serial_not_used","startup_seconds",0, ...
    "auto_resize",logical(settings.parallel_pool_auto_resize), ...
    "keep_alive",logical(settings.parallel_pool_keep_alive), ...
    "close_after_run",false,"pool_class","");
if ~settings.parallel_enabled
    return
end

workerCount = double(settings.parallel_worker_count);
info.mode = "parallel_processes";
info.requested_worker_count = workerCount;
pool = gcp("nocreate");
if isempty(pool)
    timer = tic;
    pool = parpool("Processes",workerCount);
    info.startup_seconds = toc(timer);
    info.action = "created";
elseif ~contains(string(class(pool)),"ProcessPool") || ...
        pool.NumWorkers~=workerCount
    assert(settings.parallel_pool_auto_resize, ...
        "rkkt:parallelPool:Mismatch", ...
        "The existing pool does not match the configured Processes/%d pool.", ...
        workerCount);
    delete(pool);
    timer = tic;
    pool = parpool("Processes",workerCount);
    info.startup_seconds = toc(timer);
    info.action = "recreated";
else
    info.action = "reused";
end
info.worker_count = pool.NumWorkers;
info.pool_class = string(class(pool));
info.close_after_run = ~settings.parallel_pool_keep_alive;
end
