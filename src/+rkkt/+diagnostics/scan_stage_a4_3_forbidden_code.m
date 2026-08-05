function [audit,dependencyClosure] = scan_stage_a4_3_forbidden_code( ...
        projectRoot,config)
%SCAN_STAGE_A4_3_FORBIDDEN_CODE Audit the formal A4-3 dependency closure.

arguments
    projectRoot (1,1) string
    config (1,1) struct
end
entryPath = fullfile(projectRoot,"src","+rkkt","+workflows","stageA4.m");
runnerPath = fullfile(projectRoot,"src","+rkkt","+ipm", ...
    "run_stage_a4_full_ipm.m");
recursivePath = fullfile(projectRoot,"src","+rkkt","+solver", ...
    "solve_stage_a_multiday_recursive_direction.m");
directPath = fullfile(projectRoot,"src","+rkkt","+solver", ...
    "solve_stage_a_multiday_full_kkt_direction.m");
assert(all(isfile([entryPath;runnerPath;recursivePath;directPath])), ...
    "stageA4:a43:ForbiddenScanFiles", ...
    "A required A4-3 execution file is missing.");

closure = project_m_files(dependency_files(entryPath),projectRoot);
recursiveClosure = project_m_files( ...
    dependency_files(recursivePath),projectRoot);
assert(~isempty(closure)&&~isempty(recursiveClosure), ...
    "stageA4:a43:ForbiddenClosure", ...
    "The A4-3 dependency closure is empty.");

rules = [ ...
    make_rule("A43-NO-INV-PINV-LSQMINNORM", ...
        "No inverse, pseudoinverse, or minimum-norm solve", ...
        "(?<![A-Za-z0-9_])(?:inv|pinv|lsqminnorm)\s*\(")
    make_rule("A43-NO-PARALLEL", ...
        "No parallel execution call or keyword", ...
        "(?<![A-Za-z0-9_])(?:parfor|spmd|parpool|parfeval|"+ ...
        "parfevalOnAll|backgroundPool|gcp|batch)(?![A-Za-z0-9_])")
    make_rule("A43-NO-PREDICTOR-CORRECTOR", ...
        "No predictor-corrector implementation", ...
        "(?<![A-Za-z0-9_])(?:mehrotra|predictor_?corrector|"+ ...
        "predictorcorrector)\s*\(")
    make_rule("A43-NO-LINE-SEARCH", ...
        "No line search or backtracking implementation", ...
        "(?<![A-Za-z0-9_])(?:line_?search|backtrack(?:ing)?|"+ ...
        "armijo|wolfe)\s*\(")
    make_rule("A43-NO-REGULARIZATION", ...
        "No regularization, jitter, or diagonal shift", ...
        "(?<![A-Za-z0-9_])(?:regulari[sz]e|add_?jitter|"+ ...
        "diagonal_?shift)\s*\(")
    make_rule("A43-NO-AUTOMATIC-SYMMETRIZATION", ...
        "No automatic symmetrization helper", ...
        "(?<![A-Za-z0-9_])(?:symmetri[sz]e|make_?symmetric)\s*\(")
    make_rule("A43-NO-NEGATIVE-MATRIX-POWER", ...
        "No inverse expressed through matrix power", ...
        "\^\s*-\s*1(?![0-9])")
    make_rule("A43-NO-RANDOM", ...
        "No random numerical model or direction data", ...
        "(?<![A-Za-z0-9_])(?:rng|rand|randn|randi|sprand|sprandn)\s*\(")
    make_rule("A43-NO-DYNAMIC-INVOCATION", ...
        "No dynamic invocation outside the dependency closure", ...
        "(?<![A-Za-z0-9_])(?:feval|eval|evalin|str2func)\s*\(")
    make_rule("A43-NO-LARGE-FULL-CONVERSION", ...
        "No complete KKT, day chain, or reduced system full conversion", ...
        "(?<![A-Za-z0-9_])full\s*\(\s*(?:kkt(?:\.matrix)?|"+ ...
        "assembly\.matrix|lin\.(?:H|A|G)|linearization\.(?:H|A|G)|"+ ...
        "partition\.M|reduced\.(?:W|saddle)|daily_partitions?\b)")
    make_rule("A43-NO-EXTERNAL-OPTIMIZER", ...
        "No external optimization solver replaces the frozen IPM", ...
        "(?<![A-Za-z0-9_])(?:fmincon|fminunc|fminsearch|linprog|quadprog|"+ ...
        "intlinprog|ga|patternsearch)\s*\(")];

rowCount = numel(rules)+5;
checkId = strings(rowCount,1);
requirement = strings(rowCount,1);
matchCount = zeros(rowCount,1);
matchedFiles = strings(rowCount,1);
filesScanned = zeros(rowCount,1);
details = strings(rowCount,1);
status = repmat("PASS",rowCount,1);
code = strings(numel(closure),1);
for k = 1:numel(closure)
    code(k) = strip_matlab_noncode(fileread(closure(k)));
end
row = 0;
for ruleIndex = 1:numel(rules)
    row = row+1;
    hits = strings(0,1);
    for fileIndex = 1:numel(closure)
        found = regexpi(char(code(fileIndex)), ...
            char(rules(ruleIndex).pattern),"match");
        matchCount(row) = matchCount(row)+numel(found);
        if ~isempty(found)
            hits(end+1,1) = relative_path( ...
                closure(fileIndex),projectRoot); %#ok<AGROW>
        end
    end
    checkId(row) = rules(ruleIndex).id;
    requirement(row) = rules(ruleIndex).requirement;
    matchedFiles(row) = strjoin(unique(hits,"stable"),"; ");
    filesScanned(row) = numel(closure);
    details(row) = "pattern="+rules(ruleIndex).pattern;
    if matchCount(row)>0
        status(row) = "FAIL";
    end
end

formalRaw = string(fileread(entryPath))+newline+string(fileread(runnerPath));
row = row+1;
checkId(row) = "A43-INDEPENDENT-STEP-ONLY";
requirement(row) = "Formal A4-3 selects only independent primal/dual steps";
matchCount(row) = numel(regexp(char(formalRaw), ...
    'StepStrategy\s*[,=]\s*["'']common_min["'']',"match"));
filesScanned(row) = 2;
details(row) = "targeted formal entry/runner selection scan";
if matchCount(row)>0
    status(row) = "FAIL";
    matchedFiles(row) = strjoin(relative_paths( ...
        [entryPath;runnerPath],projectRoot),"; ");
end

row = row+1;
checkId(row) = "A43-STABLE-V2-EXPLICIT";
requirement(row) = ...
    "Formal A4-3 explicitly selects stable-v2 MaxPasses=3 and congruence scaling";
matchCount(row) = double(~contains(formalRaw, ...
    "RecursiveRefinementMaxPasses")) + ...
    double(~contains(formalRaw,"UseCongruenceScaling")) + ...
    double(~contains(formalRaw,"EquilibrationPasses"));
filesScanned(row) = 2;
details(row) = "formal runner option selection plus validated stable-v2/scaling config";
if matchCount(row)>0 || config.a4_3.recursive_refinement_max_passes~=3 || ...
        ~config.a4_3.recursive_congruence_scaling_enabled || ...
        config.a4_3.equilibration_passes~=8
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "A43-RECURSIVE-CLOSURE-NO-DIRECT-SOLVER";
requirement(row) = ...
    "Recursive direction dependency closure excludes the full-KKT solver";
recursiveCanonical = arrayfun(@canonical_path,recursiveClosure);
directCanonical = canonical_path(directPath);
mask = strcmpi(recursiveCanonical,directCanonical);
matchCount(row) = nnz(mask);
matchedFiles(row) = strjoin(relative_paths( ...
    recursiveClosure(mask),projectRoot),"; ");
filesScanned(row) = numel(recursiveClosure);
details(row) = "dependency closure rooted at "+ ...
    relative_path(recursivePath,projectRoot);
if matchCount(row)>0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "A43-FROZEN-RUNTIME-CONFIG";
requirement(row) = ...
    "Runtime config disables every forbidden algorithm factor";
configurationPass = config.a4_3.step_strategy=="independent" && ...
    ~config.a4_3.common_step_enabled && ...
    ~config.a4_3.dynamic_sigma_enabled && ...
    ~config.a4_3.predictor_corrector_enabled && ...
    ~config.a4_3.line_search_enabled && ...
    ~config.a4_3.regularization_enabled && ...
    ~config.a4_3.automatic_symmetrization_enabled && ...
    config.a4_3.parallel_mode=="off" && ...
    ~config.a4_3.full_kkt_direction_fallback_enabled;
matchCount(row) = double(~configurationPass);
filesScanned(row) = 1;
details(row) = "validated effective A4-3 configuration";
if ~configurationPass
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "A43-NO-STAGE-B-DEPENDENCY";
requirement(row) = "Formal A4-3 dependency closure excludes Stage B";
stageBPrefix = lower(canonical_path( ...
    fullfile(projectRoot,"stages","stage_B"))+filesep);
closureCanonical = arrayfun(@canonical_path,closure);
mask = startsWith(lower(closureCanonical),stageBPrefix);
matchCount(row) = nnz(mask);
matchedFiles(row) = strjoin(relative_paths(closure(mask),projectRoot),"; ");
filesScanned(row) = numel(closure);
details(row) = "dependency closure rooted at rkkt.workflows.stageA4";
if matchCount(row)>0
    status(row) = "FAIL";
end

expectedIds = [ ...
    "A43-NO-INV-PINV-LSQMINNORM"
    "A43-NO-PARALLEL"
    "A43-NO-PREDICTOR-CORRECTOR"
    "A43-NO-LINE-SEARCH"
    "A43-NO-REGULARIZATION"
    "A43-NO-AUTOMATIC-SYMMETRIZATION"
    "A43-NO-NEGATIVE-MATRIX-POWER"
    "A43-NO-RANDOM"
    "A43-NO-DYNAMIC-INVOCATION"
    "A43-NO-LARGE-FULL-CONVERSION"
    "A43-NO-EXTERNAL-OPTIMIZER"
    "A43-INDEPENDENT-STEP-ONLY"
    "A43-STABLE-V2-EXPLICIT"
    "A43-RECURSIVE-CLOSURE-NO-DIRECT-SOLVER"
    "A43-FROZEN-RUNTIME-CONFIG"
    "A43-NO-STAGE-B-DEPENDENCY"];
assert(row==rowCount && rowCount==16 && ...
    isequal(checkId,expectedIds) && numel(unique(checkId))==16, ...
    "stageA4:a43:ForbiddenAuditIdentity", ...
    "The A4-3 forbidden execution audit must contain 11 fixed rows.");
audit = table(checkId,requirement,matchCount,matchedFiles,filesScanned, ...
    details,status,'VariableNames',{'check_id','requirement', ...
    'match_count','matched_files','files_scanned','details','status'});
dependencyClosure = make_dependency_closure_evidence( ...
    closure,recursiveClosure,projectRoot);
end

function evidence = make_dependency_closure_evidence( ...
        formalFiles,recursiveFiles,root)
files = unique([formalFiles(:);recursiveFiles(:)],"stable");
n = numel(files);
relative_path_value = strings(n,1);
sha256 = strings(n,1);
bytes = zeros(n,1);
in_formal_entry_closure = false(n,1);
in_recursive_direction_closure = false(n,1);
status = repmat("PASS",n,1);
formalCanonical = lower(arrayfun(@canonical_path,formalFiles));
recursiveCanonical = lower(arrayfun(@canonical_path,recursiveFiles));
for k = 1:n
    canonical = canonical_path(files(k));
    relative_path_value(k) = relative_path(canonical,root);
    sha256(k) = rkkt.data.compute_sha256_file(canonical);
    info = dir(canonical);
    bytes(k) = info.bytes;
    in_formal_entry_closure(k) = ...
        ismember(lower(canonical),formalCanonical);
    in_recursive_direction_closure(k) = ...
        ismember(lower(canonical),recursiveCanonical);
end
evidence = table(relative_path_value,sha256,bytes, ...
    in_formal_entry_closure,in_recursive_direction_closure,status, ...
    'VariableNames',{'relative_path','sha256','bytes', ...
    'in_formal_entry_closure','in_recursive_direction_closure','status'});
assert(height(evidence)>0 && ...
    all(evidence.in_formal_entry_closure | ...
    evidence.in_recursive_direction_closure) && ...
    numel(unique(evidence.relative_path))==height(evidence) && ...
    all(strlength(evidence.sha256)==64), ...
    "stageA4:a43:DependencyClosureEvidence", ...
    "A4-3 dependency closure SHA256 evidence is incomplete.");
end

function files = dependency_files(entryPath)
[files,~] = matlab.codetools.requiredFilesAndProducts(char(entryPath));
files = string(files(:));
files(end+1,1) = string(entryPath);
files = unique(files,"stable");
end

function files = project_m_files(paths,root)
rootCanonical = canonical_path(root);
prefix = lower(rootCanonical+filesep);
canonical = arrayfun(@canonical_path,paths);
mask = startsWith(lower(canonical),prefix) & endsWith(canonical,".m");
files = unique(canonical(mask),"stable");
end

function rule = make_rule(id,requirement,pattern)
rule = struct("id",string(id),"requirement",string(requirement), ...
    "pattern",string(pattern));
end

function output = strip_matlab_noncode(textValue)
output = string(textValue);
output = regexprep(output,'"(?:""|[^"])*"'," ");
output = regexprep(output, ...
    "(?<![A-Za-z0-9_\)\]\}\.])'(?:''|[^'])*'"," ");
output = regexprep(output,"(?s)%\{.*?%\}"," ");
lines = splitlines(output);
for line = 1:numel(lines)
    position = regexp(char(lines(line)),"%", "once");
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
value = replace(extractAfter(pathValue,strlength(root)+1),"\","/");
end

function value = canonical_path(pathValue)
value = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
end
