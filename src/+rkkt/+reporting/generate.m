function [reportPaths,validation] = generate(runContext,options)
%GENERATE Generate and validate the Chinese A4 reports.

arguments
    runContext (1,1) struct
    options.OutputDirectory (1,1) string = ""
    options.FinalStatusCandidate (1,1) string = "PASS"
    options.ReportGateMode (1,1) string {mustBeMember( ...
        options.ReportGateMode,["preflight","final"])} = "final"
end

[reportPaths,validation] = rkkt.reporting.generate_stage_a4_reports( ...
    runContext,OutputDirectory=options.OutputDirectory, ...
    FinalStatusCandidate=options.FinalStatusCandidate, ...
    ReportGateMode=options.ReportGateMode);
end
