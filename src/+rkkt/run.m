function project = run(options)
%RUN Execute the Stage B-2C range configured by RUN_PROJECT.yaml.

arguments
    options.ConfigPath (1,1) string = ""
end
root = rkkt.projectRoot();
settings = rkkt.config.read_run_project_configuration( ...
    root,ConfigPath=options.ConfigPath);
project = rkkt.workflows.stageB2CConfigured(settings, ...
    ExplicitDaySet=settings.explicit_day_set, ...
    JointMicroborderScanEnabled=false);
end
