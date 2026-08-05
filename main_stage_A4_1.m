function result = main_stage_A4_1()
%MAIN_STAGE_A4_1 Execute the non-formal one-iteration A4-1 milestone.
%
% This entry performs one Newton direction and one primal-dual update.  It
% intentionally does not create runs/<run_id>, does not run a complete IPM,
% and does not change CURRENT_STAGE.md.

projectRoot = string(fileparts(mfilename("fullpath")));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a4_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a4_index( ...
    data,config,"RunId","A4_1_SINGLE_ITERATION");
result = rkkt.diagnostics.run_stage_a4_single_iteration(data,index,config);
assert(result.all_pass && result.milestone_status=="PASS" && ...
    result.stage_status=="READY" && ...
    ~result.execution.full_ipm_executed && ...
    ~result.execution.formal_a4_run_created, ...
    "stageA4:singleIteration:MainContract", ...
    "A4-1 did not satisfy the one-iteration milestone contract.");
end
