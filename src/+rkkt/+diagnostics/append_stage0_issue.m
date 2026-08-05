function issues = append_stage0_issue(issues,runContext,testId,symptom, ...
        errorMessage,rootCause,proposedSolution,status,evidencePath)
%APPEND_STAGE0_ISSUE Append one truthful issue record.

if nargin < 8 || strlength(string(status)) == 0
    status = "OPEN";
end
if nargin < 9
    evidencePath = "";
end
allowed = ["OPEN","FIXED","BLOCKED","WONT_FIX"];
status = upper(string(status));
if ~ismember(status,allowed)
    error('stage0:issues:InvalidStatus','Invalid issue status: %s',status);
end
issueId = sprintf('S0-ISSUE-%03d',height(issues)+1);
gitCommit = "NOT_AVAILABLE";
if isfile(runContext.run_manifest_path)
    manifest = jsondecode(fileread(runContext.run_manifest_path));
    if isfield(manifest,'git_commit')
        gitCommit = string(manifest.git_commit);
    end
end
issues(end+1,:) = {string(issueId),string(runContext.run_id), ...
    string(runContext.stage_id),NaN,string(testId),string(symptom), ...
    string(errorMessage),string(rootCause),string(proposedSolution),"", ...
    gitCommit,"",status,replace(string(evidencePath),'\','/')};
end
