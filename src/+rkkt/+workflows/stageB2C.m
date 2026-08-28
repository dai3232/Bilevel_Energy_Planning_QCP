function result = stageB2C(options)
%STAGEB2C Run the formal seven-day preset through the common workflow.

arguments
    options.ProjectRoot (1,1) string = ""
    options.RunId (1,1) string = ""
end
root = options.ProjectRoot;
if strlength(strip(root))==0
    root = rkkt.projectRoot();
end
settings = rkkt.config.build_stage_b2c_run_settings(root, ...
    DayStart=14,DayEnd=20,AuditMode="full_kkt",RunId=options.RunId, ...
    ConfigPath=fullfile(root,"config","stage_B_2C.yaml"));
result = rkkt.workflows.stageB2CConfigured( ...
    settings,ProjectRoot=root,RunId=options.RunId);
end
