function evidence = persist_stage_a4_3_static_evidence( ...
        projectRoot,runRoot,runId,gitCommit,options)
%PERSIST_STAGE_A4_3_STATIC_EVIDENCE Rebuild and persist formal static gates.

arguments
    projectRoot (1,1) string
    runRoot (1,1) string
    runId (1,1) string
    gitCommit (1,1) string
    options.CommandText (1,1) string = ...
        "rkkt.testing.persist_stage_a4_3_static_evidence(...)"
end
testsDirectory = fullfile(runRoot,"tests");
diagnosticsDirectory = fullfile(runRoot,"diagnostics");
assert(isfolder(testsDirectory) && isfolder(diagnosticsDirectory), ...
    "stageA4:a43:static:RunDirectories", ...
    "Run tests/diagnostics directories must already exist.");
paths = struct( ...
    "summary",fullfile(testsDirectory,"static_check_summary.csv"), ...
    "analyzer",fullfile(testsDirectory,"code_analyzer_results.csv"), ...
    "analyzer_scope",fullfile(testsDirectory,"code_analyzer_scope.csv"), ...
    "analyzer_advisories",fullfile(testsDirectory, ...
        "code_analyzer_advisories.csv"), ...
    "git_diff",fullfile(testsDirectory,"git_diff_check.txt"), ...
    "command",fullfile(testsDirectory,"static_check_command.txt"), ...
    "hashes",fullfile(testsDirectory,"static_evidence_sha256.csv"), ...
    "stage_snapshot",fullfile(testsDirectory,"CURRENT_STAGE.md"), ...
    "code",fullfile(diagnosticsDirectory,"forbidden_code_audit.csv"), ...
    "runtime",fullfile(diagnosticsDirectory, ...
        "forbidden_execution_audit.csv"), ...
    "closure",fullfile(diagnosticsDirectory, ...
        "dependency_closure_sha256.csv"));
assert(~any(isfile([paths.summary;paths.analyzer;paths.analyzer_scope; ...
    paths.analyzer_advisories;paths.git_diff;paths.command;paths.hashes; ...
    paths.stage_snapshot])), ...
    "stageA4:a43:static:EvidenceExists", ...
    "Static evidence is immutable and already exists.");
assert(all(isfile([paths.code;paths.runtime;paths.closure])), ...
    "stageA4:a43:static:DiagnosticEvidence", ...
    "Formal forbidden/runtime/dependency evidence is missing.");

config = rkkt.model.load_stage_a4_3_configuration(projectRoot);
[rebuiltCode,rebuiltClosure] = ...
    rkkt.diagnostics.scan_stage_a4_3_forbidden_code(projectRoot,config);
persistedCode = read_csv_table(paths.code);
persistedRuntime = read_csv_table(paths.runtime);
persistedClosure = read_csv_table(paths.closure);
codeIdentity = tables_equal(rebuiltCode,persistedCode);
closureIdentity = tables_equal(rebuiltClosure,persistedClosure);
codePassed = codeIdentity && closureIdentity && ...
    all(rebuiltCode.status=="PASS");
runtimePassed = ~isempty(persistedRuntime) && ...
    all(persistedRuntime.status=="PASS");

scope = rkkt.diagnostics.get_stage_a4_3_code_analyzer_scope(projectRoot,rebuiltClosure);
scopeFindings = run_code_analyzer(projectRoot,scope);
allAdvisories = run_code_analyzer(projectRoot,rebuiltClosure);
nonblockingIds = ["MSNU","SPRIX"];
blockingMask = ~ismember(string(scopeFindings.identifier),nonblockingIds);
analyzer = scopeFindings(blockingMask,:);
advisoryMask = ~ismember(string(allAdvisories.file), ...
    string(scope.relative_path)) | ...
    ismember(string(allAdvisories.identifier),nonblockingIds);
advisories = allAdvisories(advisoryMask,:);
rkkt.artifacts.write_table_csv_17g(paths.analyzer,analyzer);
rkkt.artifacts.write_table_csv_17g(paths.analyzer_scope,scope);
rkkt.artifacts.write_table_csv_17g(paths.analyzer_advisories,advisories);
analyzerPassed = isempty(analyzer);
[gitExit,gitText] = git_diff_check(projectRoot);
write_utf8(paths.git_diff,"exit_code="+string(gitExit)+newline+ ...
    string(gitText));
gitPassed = gitExit==0;
stageText = string(fileread(fullfile(projectRoot,"CURRENT_STAGE.md")));
stagePassed = contains(stageText,"`stage_id`: `stage_A4`") && ...
    contains(stageText,"`status`: `READY`");
write_utf8(paths.stage_snapshot,stageText);
assert(rkkt.data.compute_sha256_file(paths.stage_snapshot)== ...
    rkkt.data.compute_sha256_file(fullfile(projectRoot,"CURRENT_STAGE.md")), ...
    "stageA4:a43:static:StageSnapshot", ...
    "The run-local CURRENT_STAGE snapshot does not match the project state.");

check_id = [ ...
    "A43-STATIC-CODE-ANALYZER"
    "A43-STATIC-FORBIDDEN-CODE"
    "A43-STATIC-FORBIDDEN-EXECUTION"
    "A43-STATIC-GIT-DIFF-CHECK"
    "A43-STATIC-STAGE-GOVERNANCE"];
passed = [analyzerPassed;codePassed;runtimePassed;gitPassed;stagePassed];
status = repmat("FAIL",5,1);
status(passed) = "PASS";
actual_value = [ ...
    "finding_count="+string(height(analyzer))+ ...
        "; scope_files="+string(height(scope))+ ...
        "; advisory_count="+string(height(advisories))
    "all_pass="+string(codePassed)+"; identity="+string(codeIdentity)
    "all_pass="+string(runtimePassed)
    "exit_code="+string(gitExit)
    "stage_A4_READY="+string(stagePassed)];
threshold = ["0 findings";"all 16 PASS and identity"; ...
    "all 8 PASS";"exit_code=0";"stage_A4 / READY"];
evidence_path = [ ...
    "tests/code_analyzer_results.csv; tests/code_analyzer_scope.csv; "+ ...
        "tests/code_analyzer_advisories.csv"
    "diagnostics/forbidden_code_audit.csv"
    "diagnostics/forbidden_execution_audit.csv"
    "tests/git_diff_check.txt"
    "tests/CURRENT_STAGE.md"];
details = [ ...
    "checkcode ran on the persisted A4-3 dependency closure"
    "forbidden scan was independently rebuilt from current source"
    "runtime gate consumes accepted-iteration trace and closure evidence"
    "git -c safe.directory=<project> diff --check"
    "run-local stage snapshot; project stage is retained and Stage B is not entered"];
summary = table(check_id,status,actual_value,threshold,evidence_path, ...
    details,repmat(runId,5,1),repmat(gitCommit,5,1), ...
    'VariableNames',{'check_id','status','actual_value','threshold', ...
    'evidence_path','details','run_id','git_commit'});
rkkt.artifacts.write_table_csv_17g(paths.summary,summary);
write_utf8(paths.command,options.CommandText+newline);
write_static_hashes(paths);
evidence = struct("summary",summary,"code_analyzer",analyzer, ...
    "code_analyzer_scope",scope,"code_analyzer_advisories",advisories, ...
    "forbidden_code",rebuiltCode,"dependency_closure",rebuiltClosure, ...
    "all_pass",all(passed),"paths",paths);
end

function findings = run_code_analyzer(root,closure)
file = strings(0,1);
line = zeros(0,1);
column = zeros(0,1);
identifier = strings(0,1);
message = strings(0,1);
for k = 1:height(closure)
    relative = string(closure.relative_path(k));
    if ~endsWith(relative,".m","IgnoreCase",true)
        continue
    end
    absolute = fullfile(root,replace(relative,"/",filesep));
    observed = checkcode(absolute,"-id");
    for j = 1:numel(observed)
        file(end+1,1) = relative; %#ok<AGROW>
        line(end+1,1) = double(observed(j).line); %#ok<AGROW>
        currentColumn = observed(j).column;
        if isempty(currentColumn)
            column(end+1,1) = NaN; %#ok<AGROW>
        else
            column(end+1,1) = double(currentColumn(1)); %#ok<AGROW>
        end
        text = string(observed(j).message);
        token = regexp(char(text),"\(([A-Za-z0-9_]+)\)\s*$", ...
            "tokens","once");
        if isempty(token)
            identifier(end+1,1) = string(observed(j).id); %#ok<AGROW>
        else
            identifier(end+1,1) = string(token{1}); %#ok<AGROW>
        end
        message(end+1,1) = text; %#ok<AGROW>
    end
end
findings = table(file,line,column,identifier,message);
end

function passed = tables_equal(left,right)
passed = isequal(string(left.Properties.VariableNames), ...
    string(right.Properties.VariableNames)) && ...
    height(left)==height(right);
if ~passed
    return
end
for name = string(left.Properties.VariableNames)
    a = left.(name);
    b = right.(name);
    if (isnumeric(a) || islogical(a)) && ...
            (isnumeric(b) || islogical(b))
        passed = passed && isequaln(double(a),double(b));
    else
        leftText = string(a);
        rightText = string(b);
        % Empty CSV text cells are imported as either <missing> or the
        % literal "NaN" depending on the R2024a import path.  Treat both
        % representations as the same empty evidence value so a rebuilt
        % forbidden-code table can be compared byte-semantically.
        leftText(ismissing(leftText) | lower(strip(leftText))=="nan") = "";
        rightText(ismissing(rightText) | lower(strip(rightText))=="nan") = "";
        passed = passed && isequal(leftText,rightText);
    end
end
end

function [status,output] = git_diff_check(root)
safe = replace(root,"\","/");
quotedSafe = '"'+replace(safe,'"','\"')+'"';
quotedRoot = '"'+replace(root,'"','\"')+'"';
[status,output] = system(char("git -c safe.directory="+quotedSafe+ ...
    " -C "+quotedRoot+" diff --check"));
end

function write_static_hashes(paths)
names = [ ...
    "tests/static_check_summary.csv"
    "tests/code_analyzer_results.csv"
    "tests/code_analyzer_scope.csv"
    "tests/code_analyzer_advisories.csv"
    "tests/git_diff_check.txt"
    "tests/static_check_command.txt"
    "tests/CURRENT_STAGE.md"
    "diagnostics/forbidden_code_audit.csv"
    "diagnostics/forbidden_execution_audit.csv"
    "diagnostics/dependency_closure_sha256.csv"];
targets = [paths.summary;paths.analyzer;paths.analyzer_scope; ...
    paths.analyzer_advisories;paths.git_diff;paths.command; ...
    paths.stage_snapshot;paths.code;paths.runtime;paths.closure];
sha256 = strings(numel(targets),1);
bytes = zeros(numel(targets),1);
for k = 1:numel(targets)
    sha256(k) = rkkt.data.compute_sha256_file(targets(k));
    info = dir(targets(k));
    bytes(k) = info.bytes;
end
status = repmat("PASS",numel(targets),1);
rkkt.artifacts.write_table_csv_17g(paths.hashes, ...
    table(names,sha256,bytes,status));
end

function write_utf8(pathValue,textValue)
[fileId,message] = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0,"stageA4:a43:static:Write","%s",message);
guard = onCleanup(@()close_file(fileId));
bytes = unicode2native(char(textValue),"UTF-8");
count = fwrite(fileId,bytes,"uint8");
assert(count==numel(bytes),"stageA4:a43:static:Write", ...
    "Incomplete static evidence write: %s",pathValue);
status = fclose(fileId);
clear guard
assert(status==0,"stageA4:a43:static:Write", ...
    "Could not close static evidence: %s",pathValue);
end

function close_file(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end

function value = read_csv_table(pathValue)
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
value = readtable(pathValue,options);
end
