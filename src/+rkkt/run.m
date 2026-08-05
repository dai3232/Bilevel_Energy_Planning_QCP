function project = run()
%RUN Execute and evidence the complete seven-day A4 package regression.

numerical = rkkt.workflows.stageA4( ...
    "ExecutionProfile","package_closure");
project = rkkt.workflows.completePackageClosureA4(numerical);
end
