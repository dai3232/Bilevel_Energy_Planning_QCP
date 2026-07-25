function audit = scan_stage_a4_r1_forbidden_code(projectRoot)
%SCAN_STAGE_A4_R1_FORBIDDEN_CODE Enforce the isolated R1 execution boundary.

arguments
    projectRoot (1,1) string
end
mainPath = fullfile(projectRoot,"main_stage_A4_2D_2A_R1.m");
diagnosticPath = fullfile(projectRoot,"src","diagnostics", ...
    "run_stage_a4_objective_unitization_r1_diagnostic.m");
oldMainPath = fullfile(projectRoot,"main_stage_A4_2D_2A.m");
files = [mainPath;diagnosticPath];
assert(all(isfile(files)) && isfile(oldMainPath), ...
    "stageA4:r1:ForbiddenScanFiles", ...
    "The R1 or historical A4-2D-2A entry is missing.");
code = strings(numel(files),1);
rawCode = strings(numel(files),1);
for k = 1:numel(files)
    rawCode(k) = string(fileread(files(k)));
    code(k) = strip_matlab_noncode(rawCode(k));
end
combined = strjoin(code,newline);
rawCombined = strjoin(rawCode,newline);

checkId = [ ...
    "R1-NO-INV-PINV-LSQMINNORM"
    "R1-NO-PARALLEL-CALL"
    "R1-NO-COMMON-MIN-CALL"
    "R1-NO-DYNAMIC-SIGMA"
    "R1-NO-PREDICTOR-CORRECTOR"
    "R1-NO-LINE-SEARCH"
    "R1-NO-REGULARIZATION"
    "R1-NO-AUTOMATIC-SYMMETRIZATION"
    "R1-NO-FILESYSTEM-MUTATION"
    "R1-NO-EVIDENCE-EXPORT-DEPENDENCY"
    "R1-EXPLICIT-THREE-PASS-CHAINS"
    "R1-OLD-ENTRY-DOES-NOT-CALL-R1"];
requirement = [ ...
    "R1 entry contains no inverse, pseudoinverse or minimum-norm call"
    "R1 entry contains no parallel execution call"
    "R1 entry never selects the common_min experimental step"
    "R1 entry contains no dynamic sigma mechanism"
    "R1 entry contains no predictor-corrector mechanism"
    "R1 entry contains no line-search mechanism"
    "R1 entry contains no regularization mechanism"
    "R1 entry contains no automatic symmetrization mechanism"
    "R1 calculation entry performs no filesystem mutation"
    "R1 calculation entry does not depend on the evidence exporter"
    "R1 orchestrator explicitly passes MaxPasses=3 to all three chains"
    "Historical A4-2D-2A entry does not call the R1 entry"];
pattern = [ ...
    "(?<![A-Za-z0-9_])(?:inv|pinv|lsqminnorm)\s*\("
    "(?<![A-Za-z0-9_])(?:parfor|parpool|parfeval|spmd|gcp)\b"
    "common_min"
    "(?<![A-Za-z0-9_])dynamic_?sigma\b"
    "(?<![A-Za-z0-9_])(?:mehrotra|predictor_?corrector)\b"
    "(?<![A-Za-z0-9_])(?:line_?search|backtrack|armijo|wolfe)\b"
    "(?<![A-Za-z0-9_])(?:regulari[sz]e|add_?jitter|diagonal_?shift)\s*\("
    "(?<![A-Za-z0-9_])(?:symmetri[sz]e|make_?symmetric)\s*\("
    "(?<![A-Za-z0-9_])(?:create_run_context|mkdir|save|writetable|" + ...
        "writecell|writematrix|delete|movefile|copyfile|zip|unzip)\s*\("
    "export_stage_a4_2d_2a_r1"
    ""
    ""];
matchCount = zeros(numel(checkId),1);
matchedFiles = strings(numel(checkId),1);
details = strings(numel(checkId),1);
status = repmat("PASS",numel(checkId),1);
for row = 1:10
    target = combined;
    if row==3
        target = rawCombined;
    end
    hits = regexp(char(target),char(pattern(row)),'match');
    matchCount(row) = numel(hits);
    if matchCount(row)>0
        matchedFiles(row) = strjoin(relative_paths(files,projectRoot),"; ");
        status(row) = "FAIL";
    end
    details(row) = "pattern="+pattern(row);
end

diagnosticCode = rawCode(2);
explicitPassCount = numel(regexp(char(diagnosticCode), ...
    '"RecursiveRefinementMaxPasses"\s*,\s*maximumPasses','match'));
maximumPassDeclaration = numel(regexp(char(diagnosticCode), ...
    'maximumPasses\s*=\s*3\s*;','match'));
matchCount(11) = double(explicitPassCount~=3 || maximumPassDeclaration~=1);
details(11) = "explicit_pass_arguments="+string(explicitPassCount)+ ...
    "; maximum_pass_declarations="+string(maximumPassDeclaration);
if matchCount(11)>0
    status(11) = "FAIL";
    matchedFiles(11) = relative_path(diagnosticPath,projectRoot);
end

oldCode = strip_matlab_noncode(fileread(oldMainPath));
oldHits = regexp(char(oldCode),'main_stage_A4_2D_2A_R1\s*\(','match');
matchCount(12) = numel(oldHits);
details(12) = "historical entry targeted call scan";
if matchCount(12)>0
    status(12) = "FAIL";
    matchedFiles(12) = relative_path(oldMainPath,projectRoot);
end

audit = table(checkId,requirement,matchCount,matchedFiles,details,status, ...
    'VariableNames',{'check_id','requirement','match_count', ...
    'matched_files','details','status'});
end

function output = strip_matlab_noncode(textValue)
output = string(textValue);
output = regexprep(output,'"(?:""|[^"])*"',' ');
output = regexprep(output, ...
    "(?<![A-Za-z0-9_\)\]\}\.])'(?:''|[^'])*'"," ");
output = regexprep(output,'(?s)%\{.*?%\}',' ');
lines = splitlines(output);
for line = 1:numel(lines)
    position = regexp(char(lines(line)),'%', 'once');
    if ~isempty(position)
        lines(line) = extractBefore(lines(line),position);
    end
end
output = strjoin(lines,newline);
end

function values = relative_paths(paths,root)
values = strings(numel(paths),1);
for k = 1:numel(paths)
    values(k) = relative_path(paths(k),root);
end
end

function value = relative_path(pathValue,root)
pathValue = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
root = string(char(java.io.File(char(root)).getCanonicalPath()));
value = replace(extractAfter(pathValue,strlength(root)+1),'\','/');
end
