function [audit,dependencyClosure] = scan_stage_a4_r1_forbidden_code(projectRoot)
%SCAN_STAGE_A4_R1_FORBIDDEN_CODE Enforce the isolated R1 execution boundary.
%
% The call-shaped rules are evaluated over the project-local MATLAB
% dependency closure rooted at the actual R1 entry.  The common-step rule
% remains a targeted entry/orchestrator check because shared iteration
% helpers deliberately support the isolated A4-2C common_min experiment;
% the R1 runtime audit separately proves which step strategy was consumed.

arguments
    projectRoot (1,1) string
end
mainPath = fullfile(projectRoot,"main_stage_A4_2D_2A_R1.m");
diagnosticPath = fullfile(projectRoot,"src","diagnostics", ...
    "run_stage_a4_objective_unitization_r1_diagnostic.m");
oldMainPath = fullfile(projectRoot,"main_stage_A4_2D_2A.m");
directFiles = [mainPath;diagnosticPath];
assert(all(isfile(directFiles)) && isfile(oldMainPath), ...
    "stageA4:r1:ForbiddenScanFiles", ...
    "The R1 or historical A4-2D-2A entry is missing.");

dependencyFiles = project_m_files(dependency_files(mainPath),projectRoot);
assert(~isempty(dependencyFiles), ...
    "stageA4:r1:EmptyDependencyClosure", ...
    "The project-local R1 dependency closure is empty.");
dependencyCanonical = arrayfun(@canonical_path,dependencyFiles);
assert(all(ismember(lower(arrayfun(@canonical_path,directFiles)), ...
    lower(dependencyCanonical))), ...
    "stageA4:r1:DependencyClosureRoots", ...
    "The R1 dependency closure omits its entry or orchestrator.");

closureRawCode = strings(numel(dependencyFiles),1);
closureCode = strings(numel(dependencyFiles),1);
for k = 1:numel(dependencyFiles)
    closureRawCode(k) = string(fileread(dependencyFiles(k)));
    closureCode(k) = strip_matlab_noncode(closureRawCode(k));
end
directRawCode = strings(numel(directFiles),1);
for k = 1:numel(directFiles)
    directRawCode(k) = string(fileread(directFiles(k)));
end
closureCombined = strjoin(closureCode,newline);
directRawCombined = strjoin(directRawCode,newline);

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
    "R1-OLD-ENTRY-DOES-NOT-CALL-R1"
    "R1-NO-STAGE-B-DEPENDENCY"
    "R1-DEPENDENCY-CLOSURE-COVERAGE"
    "R1-NO-DYNAMIC-INVOCATION"];
requirement = [ ...
    "R1 dependency closure contains no inverse or minimum-norm call"
    "R1 dependency closure contains no parallel execution call"
    "R1 entry never selects the common_min experimental step"
    "R1 dependency closure contains no dynamic sigma mechanism"
    "R1 dependency closure contains no predictor-corrector mechanism"
    "R1 dependency closure contains no line-search mechanism"
    "R1 dependency closure contains no regularization mechanism"
    "R1 dependency closure contains no automatic symmetrization mechanism"
    "R1 dependency closure performs no filesystem mutation"
    "R1 dependency closure excludes the evidence exporter"
    "R1 orchestrator executes exactly 1+2 chains with MaxPasses=3"
    "Historical A4-2D-2A entry does not call the R1 entry"
    "The R1 entry dependency closure excludes Stage B"
    "The R1 closure contains every mandatory transitive execution helper"
    "The R1 dependency closure contains no dynamic invocation"];
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
    ""
    ""
    ""
    ""];
matchCount = zeros(numel(checkId),1);
matchedFiles = strings(numel(checkId),1);
details = strings(numel(checkId),1);
filesScanned = zeros(numel(checkId),1);
status = repmat("PASS",numel(checkId),1);
for row = 1:10
    target = closureCombined;
    targetFiles = dependencyFiles;
    scanScope = "R1 entry dependency closure";
    if row==3
        target = directRawCombined;
        targetFiles = directFiles;
        scanScope = "R1 entry and orchestrator";
    end
    hits = regexp(char(target),char(pattern(row)),'match');
    matchCount(row) = numel(hits);
    if matchCount(row)>0
        matchedFiles(row) = matched_pattern_files( ...
            targetFiles,pattern(row),projectRoot,row==3);
        status(row) = "FAIL";
    end
    details(row) = "scope="+scanScope+"; pattern="+pattern(row);
    filesScanned(row) = numel(targetFiles);
end

diagnosticCode = directRawCode(2);
explicitPassCount = numel(regexp(char(diagnosticCode), ...
    '"RecursiveRefinementMaxPasses"\s*,\s*maximumPasses','match'));
maximumPassDeclaration = numel(regexp(char(diagnosticCode), ...
    'maximumPasses\s*=\s*3\s*;','match'));
unscaledCallCount = numel(regexp(char(diagnosticCode), ...
    '(?<![A-Za-z0-9_])run_stage_a4_five_iteration_diagnostic\s*\(', ...
    'match'));
scaledCallCount = numel(regexp(char(diagnosticCode), ...
    '(?<![A-Za-z0-9_])run_stage_a4_scaled_objective_chain\s*\(', ...
    'match'));
formalIpmCallCount = numel(regexp(char(diagnosticCode), ...
    '(?<![A-Za-z0-9_])run_stage_a4_full_ipm\s*\(','match'));
matchCount(11) = double(explicitPassCount~=3 || ...
    maximumPassDeclaration~=1 || unscaledCallCount~=1 || ...
    scaledCallCount~=2 || formalIpmCallCount~=0);
details(11) = "explicit_pass_arguments="+string(explicitPassCount)+ ...
    "; maximum_pass_declarations="+string(maximumPassDeclaration)+ ...
    "; unscaled_chain_calls="+string(unscaledCallCount)+ ...
    "; scaled_chain_calls="+string(scaledCallCount)+ ...
    "; formal_ipm_calls="+string(formalIpmCallCount);
if matchCount(11)>0
    status(11) = "FAIL";
    matchedFiles(11) = relative_path(diagnosticPath,projectRoot);
end
filesScanned(11) = 1;

oldCode = strip_matlab_noncode(fileread(oldMainPath));
oldHits = regexp(char(oldCode),'main_stage_A4_2D_2A_R1\s*\(','match');
matchCount(12) = numel(oldHits);
details(12) = "historical entry targeted call scan";
if matchCount(12)>0
    status(12) = "FAIL";
    matchedFiles(12) = relative_path(oldMainPath,projectRoot);
end
filesScanned(12) = 1;

stageBRoot = canonical_path(fullfile(projectRoot,"stages","stage_B"));
stageBPrefix = lower(stageBRoot+filesep);
stageBMask = startsWith(lower(dependencyCanonical),stageBPrefix);
matchCount(13) = nnz(stageBMask);
matchedFiles(13) = strjoin(relative_paths( ...
    dependencyFiles(stageBMask),projectRoot),"; ");
details(13) = "dependency closure rooted at "+ ...
    relative_path(mainPath,projectRoot);
filesScanned(13) = numel(dependencyFiles);
if matchCount(13)>0
    status(13) = "FAIL";
end

mandatoryClosurePaths = [ ...
    mainPath
    diagnosticPath
    fullfile(projectRoot,"src","diagnostics", ...
        "audit_stage_a4_r1_forbidden_execution.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "make_stage_a4_r1_blocking_audit.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "scan_stage_a4_r1_forbidden_code.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_five_iteration_diagnostic.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_scaled_objective_chain.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "execute_stage_a4_iteration.m")
    fullfile(projectRoot,"src","solver", ...
        "solve_stage_a_multiday_recursive_direction.m")
    fullfile(projectRoot,"src","solver", ...
        "solve_stage_a_multiday_full_kkt_direction.m")
    fullfile(projectRoot,"src","solver","update_primal_dual_state.m")];
mandatoryCanonical = arrayfun(@canonical_path,mandatoryClosurePaths);
missingMask = ~ismember(lower(mandatoryCanonical),lower(dependencyCanonical));
matchCount(14) = nnz(missingMask);
matchedFiles(14) = strjoin(relative_paths( ...
    mandatoryClosurePaths(missingMask),projectRoot),"; ");
details(14) = "mandatory_files="+string(numel(mandatoryClosurePaths))+ ...
    "; closure_files="+string(numel(dependencyFiles));
filesScanned(14) = numel(dependencyFiles);
if matchCount(14)>0
    status(14) = "FAIL";
end

dynamicInvocationPattern = ...
    "(?<![A-Za-z0-9_])(?:eval|evalin|feval|str2func)\s*\(";
dynamicInvocationHits = regexp( ...
    char(closureCombined),char(dynamicInvocationPattern),'match');
matchCount(15) = numel(dynamicInvocationHits);
if matchCount(15)>0
    matchedFiles(15) = matched_pattern_files( ...
        dependencyFiles,dynamicInvocationPattern,projectRoot,false);
    status(15) = "FAIL";
end
details(15) = "scope=R1 entry dependency closure; pattern="+ ...
    dynamicInvocationPattern;
filesScanned(15) = numel(dependencyFiles);

relativePath = relative_paths(dependencyFiles,projectRoot);
sha256 = strings(numel(dependencyFiles),1);
for k = 1:numel(dependencyFiles)
    sha256(k) = lower(string(compute_sha256_file(dependencyFiles(k))));
end
dependencyClosure = table(relativePath,sha256, ...
    'VariableNames',{'relative_path','sha256'});
dependencyClosure = sortrows(dependencyClosure,"relative_path");

audit = table(checkId,requirement,matchCount,matchedFiles,details, ...
    filesScanned,status, ...
    'VariableNames',{'check_id','requirement','match_count', ...
    'matched_files','details','files_scanned','status'});
end

function files = dependency_files(entryPath)
try
    [requiredFiles,~] = matlab.codetools.requiredFilesAndProducts( ...
        char(entryPath));
catch cause
    wrapped = MException("stageA4:r1:DependencyAnalysisFailed", ...
        "Could not determine R1 dependencies for %s: %s", ...
        entryPath,cause.message);
    wrapped = addCause(wrapped,cause);
    throw(wrapped);
end
files = [string(entryPath);string(requiredFiles(:))];
end

function files = project_m_files(candidates,projectRoot)
root = canonical_path(projectRoot);
rootPrefix = lower(root+filesep);
files = strings(0,1);
for candidate = string(candidates(:)).'
    if ~isfile(candidate) || ~endsWith(lower(candidate),".m")
        continue
    end
    canonical = canonical_path(candidate);
    if startsWith(lower(canonical),rootPrefix)
        files(end+1,1) = canonical; %#ok<AGROW>
    end
end
files = unique(files,'stable');
end

function value = matched_pattern_files(files,pattern,root,useRaw)
hits = strings(0,1);
for k = 1:numel(files)
    target = string(fileread(files(k)));
    if ~useRaw
        target = strip_matlab_noncode(target);
    end
    if ~isempty(regexp(char(target),char(pattern),'once'))
        hits(end+1,1) = relative_path(files(k),root); %#ok<AGROW>
    end
end
value = strjoin(unique(hits,'stable'),"; ");
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
    pathValue = canonical_path(pathValue);
    root = canonical_path(root);
    value = replace(extractAfter(pathValue,strlength(root)+1),'\','/');
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end
