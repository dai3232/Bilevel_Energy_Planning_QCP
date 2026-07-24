function audit = scan_stage_a4_forbidden_code(projectRoot,config)
%SCAN_STAGE_A4_FORBIDDEN_CODE Audit executable code on the A4 diagnostic paths.
%
% The scan follows the production dependency closures rooted at the
% A4-1, A4-2A, A4-2B, A4-2C, A4-2D-1, A4-2D-2A, and A4-RNS-1
% entry points. Tests, reports,
% historical runs, and unrelated stage-0 environment probes are therefore
% outside the scan and cannot create false parallel-call findings.
% Call-shaped patterns are evaluated after comments and quoted literals
% have been removed.

arguments
    projectRoot (1,1) string
    config (1,1) struct
end

entryPaths = [ ...
    fullfile(projectRoot,"main_stage_A4_1.m")
    fullfile(projectRoot,"main_stage_A4_2A.m")
    fullfile(projectRoot,"main_stage_A4_2B.m")
    fullfile(projectRoot,"main_stage_A4_2C.m")
    fullfile(projectRoot,"main_stage_A4_2D_1.m")
    fullfile(projectRoot,"main_stage_A4_2D_2A.m")
    fullfile(projectRoot,"main_stage_A4_RNS_1.m")];
complementarityAuditPath = fullfile(projectRoot,"src","diagnostics", ...
    "audit_stage_a4_complementarity_change.m");
a42dAuditPath = fullfile(projectRoot,"src","diagnostics", ...
    "run_stage_a4_small_step_root_cause_audit.m");
recursivePath = fullfile(projectRoot,"src","solver", ...
    "solve_stage_a_multiday_recursive_direction.m");
directPath = fullfile(projectRoot,"src","solver", ...
    "solve_stage_a_multiday_full_kkt_direction.m");
diagnosticRhsPath = fullfile(projectRoot,"src","solver", ...
    "solve_stage_a_multiday_diagnostic_rhs_responses.m");
mandatoryPaths = [ ...
    entryPaths
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_single_iteration.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "execute_stage_a4_iteration.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_five_iteration_diagnostic.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_complementarity_gap_diagnostic.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_step_strategy_ab_diagnostic.m")
    a42dAuditPath
    fullfile(projectRoot,"src","diagnostics", ...
        "build_stage_a4_scaled_objective_linearization.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_scaled_objective_chain.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "evaluate_stage_a4_scaled_five_round_gate.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_objective_unitization_diagnostic.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_rns1_stability_audit.m")
    complementarityAuditPath
    fullfile(projectRoot,"src","indexing","build_stage_a4_index.m")
    fullfile(projectRoot,"src","indexing", ...
        "build_stage_a_multiday_index.m")
    fullfile(projectRoot,"src","model", ...
        "load_stage_a4_configuration.m")
    fullfile(projectRoot,"src","model","initialize_stage_a4_state.m")
    fullfile(projectRoot,"src","model", ...
        "initialize_stage_a_multiday_state.m")
    fullfile(projectRoot,"src","model","build_stage_a4_linearization.m")
    fullfile(projectRoot,"src","model", ...
        "build_stage_a_multiday_linearization.m")
    recursivePath
    directPath
    diagnosticRhsPath
    fullfile(projectRoot,"src","solver", ...
        "compute_fraction_to_boundary_step.m")
    fullfile(projectRoot,"src","solver","update_primal_dual_state.m")];
missingMandatory = mandatoryPaths(~isfile(mandatoryPaths));
if ~isempty(missingMandatory)
    error("stageA4:scan:MissingProductionFile", ...
        "Required A4 production files are missing: %s", ...
        strjoin(missingMandatory,", "));
end

entryDependencies = strings(0,1);
for entryPath = entryPaths.'
    entryDependencies = [entryDependencies; ...
        dependency_files(entryPath)]; %#ok<AGROW>
end
productionFiles = project_m_files( ...
    [entryDependencies;mandatoryPaths],projectRoot);
recursiveDependencies = project_m_files( ...
    dependency_files(recursivePath),projectRoot);
if isempty(productionFiles) || isempty(recursiveDependencies)
    error("stageA4:scan:EmptyDependencyClosure", ...
        "The A4 production or recursive dependency closure is empty.");
end

codeText = strings(numel(productionFiles),1);
for fileIndex = 1:numel(productionFiles)
    codeText(fileIndex) = strip_matlab_noncode( ...
        fileread(productionFiles(fileIndex)));
end

rules = [ ...
    make_rule("NO-INV","No inv call", ...
        "(?<![A-Za-z0-9_])inv\s*\(")
    make_rule("NO-PINV","No pinv call", ...
        "(?<![A-Za-z0-9_])pinv\s*\(")
    make_rule("NO-LSQMINNORM","No lsqminnorm call", ...
        "(?<![A-Za-z0-9_])lsqminnorm\s*\(")
    make_rule("NO-NEGATIVE-MATRIX-POWER", ...
        "No explicit negative-one matrix power", ...
        "\^\s*\(?\s*-1\s*\)?")
    make_rule("NO-RANDOM","No random-number call", ...
        "(?<![A-Za-z0-9_])(?:rand|randn|randi|randperm|rng)\s*\(")
    make_rule("NO-PARALLEL-CALL", ...
        "No parallel execution call or keyword", ...
        "(?<![A-Za-z0-9_])(?:(?:parfor|spmd)(?![A-Za-z0-9_])|" + ...
        "(?:parpool|parfeval|parfevalOnAll|backgroundPool|gcp|batch)" + ...
        "(?:\s*\(|\s+[A-Za-z]))")
    make_rule("NO-DYNAMIC-INVOCATION", ...
        "No eval, feval, or dynamic function construction", ...
        "(?<![A-Za-z0-9_])(?:eval|evalin|feval|str2func)\s*\(")
    make_rule("NO-FILESYSTEM-MUTATION", ...
        "No run/artifact creation or filesystem mutation", ...
        "(?<![A-Za-z0-9_])(?:create_run_context|mkdir|save|" + ...
        "writetable|writecell|writematrix|delete|movefile|copyfile|" + ...
        "zip|unzip|system|dos|unix)\s*\(")
    make_rule("NO-LINE-SEARCH", ...
        "No line search, backtracking, or optimizer call", ...
        "(?<![A-Za-z0-9_])(?:line_?search|backtrack(?:ing)?|armijo|" + ...
        "wolfe|fminsearch|fminbnd|fminunc|fmincon)\s*\(")
    make_rule("NO-REGULARIZATION-HELPER", ...
        "No regularization, jitter, or diagonal-shift helper call", ...
        "(?<![A-Za-z0-9_])(?:regulari[sz]e|add_?jitter|" + ...
        "diagonal_?shift)\s*\(")
    make_rule("NO-SYMMETRIZATION-HELPER", ...
        "No automatic symmetrization helper call", ...
        "(?<![A-Za-z0-9_])(?:symmetri[sz]e|make_?symmetric)\s*\(")
    make_rule("NO-LARGE-FULL-CONVERSION", ...
        "No full conversion of a complete KKT or reduced day chain", ...
        "(?<![A-Za-z0-9_])full\s*\(\s*(?:fullAssembly|assembly|" + ...
        "kkt|partition|reduced)\s*\.\s*(?:matrix|M|day)\b")
    make_rule("NO-PREDICTOR-CORRECTOR", ...
        "No Mehrotra or predictor-corrector helper call", ...
        "(?<![A-Za-z0-9_])(?:mehrotra|predictor_?corrector|" + ...
        "predictorcorrector)\s*\(")];

rowCount = numel(rules)+17;
checkId = strings(rowCount,1);
requirement = strings(rowCount,1);
matchCount = zeros(rowCount,1);
matchedFiles = strings(rowCount,1);
details = strings(rowCount,1);
filesScanned = zeros(rowCount,1);
status = repmat("PASS",rowCount,1);
row = 0;
for ruleIndex = 1:numel(rules)
    row = row+1;
    hits = strings(0,1);
    count = 0;
    for fileIndex = 1:numel(productionFiles)
        found = regexpi(char(codeText(fileIndex)), ...
            char(rules(ruleIndex).pattern),'match');
        count = count+numel(found);
        if ~isempty(found)
            hits(end+1,1) = relative_path( ...
                productionFiles(fileIndex),projectRoot); %#ok<AGROW>
        end
    end
    checkId(row) = rules(ruleIndex).id;
    requirement(row) = rules(ruleIndex).requirement;
    matchCount(row) = count;
    matchedFiles(row) = strjoin(unique(hits,'stable'),"; ");
    details(row) = "pattern="+rules(ruleIndex).pattern;
    filesScanned(row) = numel(productionFiles);
    if count ~= 0
        status(row) = "FAIL";
    end
end

row = row+1;
checkId(row) = "NO-A42B-ADDITIONAL-DENSE-CONDITION-NUMBER";
requirement(row) = ...
    "A4-2B adds no dense condition-number or full-matrix diagnostic";
a42bDiagnosticPaths = [entryPaths(3);complementarityAuditPath; ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_complementarity_gap_diagnostic.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_five_iteration_diagnostic.m")];
denseHits = strings(0,1);
for fileIndex = 1:numel(a42bDiagnosticPaths)
    targetCode = strip_matlab_noncode(fileread(a42bDiagnosticPaths(fileIndex)));
    found = regexpi(char(targetCode), ...
        '(?<![A-Za-z0-9_])(?:cond|full)\s*\(','match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        denseHits(end+1,1) = relative_path( ...
            a42bDiagnosticPaths(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(denseHits,'stable'),"; ");
if matchCount(row)>0
    status(row) = "FAIL";
end
details(row) = "targeted A4-2B diagnostic-source scan for cond/full calls";
filesScanned(row) = numel(a42bDiagnosticPaths);

row = row+1;
checkId(row) = "NO-A42C-ADDITIONAL-DENSE-CONDITION-NUMBER";
requirement(row) = ...
    "A4-2C adds no dense condition-number or full-matrix diagnostic";
a42cDiagnosticPaths = [entryPaths(4); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_step_strategy_ab_diagnostic.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_five_iteration_diagnostic.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "execute_stage_a4_iteration.m");complementarityAuditPath];
denseHits = strings(0,1);
for fileIndex = 1:numel(a42cDiagnosticPaths)
    targetCode = strip_matlab_noncode(fileread(a42cDiagnosticPaths(fileIndex)));
    found = regexpi(char(targetCode), ...
        '(?<![A-Za-z0-9_])(?:cond|full)\s*\(','match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        denseHits(end+1,1) = relative_path( ...
            a42cDiagnosticPaths(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(denseHits,'stable'),"; ");
if matchCount(row)>0
    status(row) = "FAIL";
end
details(row) = "targeted A4-2C diagnostic-source scan for cond/full calls";
filesScanned(row) = numel(a42cDiagnosticPaths);

row = row+1;
checkId(row) = "NO-A42D1-ADDITIONAL-DENSE-CONDITION-NUMBER";
requirement(row) = ...
    "A4-2D-1 adds no dense condition-number or full-matrix diagnostic";
a42dDiagnosticPaths = [entryPaths(5);a42dAuditPath];
denseHits = strings(0,1);
for fileIndex = 1:numel(a42dDiagnosticPaths)
    targetCode = strip_matlab_noncode(fileread(a42dDiagnosticPaths(fileIndex)));
    found = regexpi(char(targetCode), ...
        '(?<![A-Za-z0-9_])(?:cond|full)\s*\(','match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        denseHits(end+1,1) = relative_path( ...
            a42dDiagnosticPaths(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(denseHits,'stable'),"; ");
if matchCount(row)>0
    status(row) = "FAIL";
end
details(row) = "targeted A4-2D-1 diagnostic-source scan for cond/full calls";
filesScanned(row) = numel(a42dDiagnosticPaths);

row = row+1;
checkId(row) = "NO-A42D2A-ADDITIONAL-DENSE-CONDITION-NUMBER";
requirement(row) = ...
    "A4-2D-2A adds no dense condition-number or full-matrix diagnostic";
a42d2aDiagnosticPaths = [entryPaths(6); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "build_stage_a4_scaled_objective_linearization.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_scaled_objective_chain.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "evaluate_stage_a4_scaled_five_round_gate.m"); ...
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_objective_unitization_diagnostic.m")];
denseHits = strings(0,1);
for fileIndex = 1:numel(a42d2aDiagnosticPaths)
    targetCode = strip_matlab_noncode( ...
        fileread(a42d2aDiagnosticPaths(fileIndex)));
    found = regexpi(char(targetCode), ...
        '(?<![A-Za-z0-9_])(?:cond|full)\s*\(','match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        denseHits(end+1,1) = relative_path( ...
            a42d2aDiagnosticPaths(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(denseHits,'stable'),"; ");
if matchCount(row)>0
    status(row) = "FAIL";
end
details(row) = ...
    "targeted A4-2D-2A diagnostic-source scan for cond/full calls";
filesScanned(row) = numel(a42d2aDiagnosticPaths);

row = row+1;
checkId(row) = "NO-A42D1-AUDIT-SOLVER-OR-STATE-UPDATE";
requirement(row) = ...
    "The read-only A4-2D-1 audit excludes all solver and state-update paths";
a42dAuditDependencies = project_m_files( ...
    dependency_files(a42dAuditPath),projectRoot);
forbiddenAuditDependencies = [ ...
    fullfile(projectRoot,"src","diagnostics", ...
        "execute_stage_a4_iteration.m")
    fullfile(projectRoot,"src","diagnostics", ...
        "run_stage_a4_step_strategy_ab_diagnostic.m")
    fullfile(projectRoot,"src","solver", ...
        "solve_stage_a_multiday_recursive_direction.m")
    fullfile(projectRoot,"src","solver", ...
        "solve_stage_a_multiday_full_kkt_direction.m")
    fullfile(projectRoot,"src","solver","update_primal_dual_state.m")];
dependencyCanonical = arrayfun(@canonical_path,a42dAuditDependencies);
forbiddenCanonical = arrayfun(@canonical_path,forbiddenAuditDependencies);
forbiddenMask = ismember(lower(dependencyCanonical),lower(forbiddenCanonical));
matchCount(row) = nnz(forbiddenMask);
matchedFiles(row) = strjoin(relative_paths( ...
    a42dAuditDependencies(forbiddenMask),projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(a42dAuditPath,projectRoot);
filesScanned(row) = numel(a42dAuditDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-A42D1R-REFACTOR-DIRECT-SOLVE-OR-STATE-UPDATE";
requirement(row) = ...
    "A4-2D-1R responses reuse retained factors without direct solve or update";
diagnosticRhsDependencies = project_m_files( ...
    dependency_files(diagnosticRhsPath),projectRoot);
forbiddenDiagnosticDependencies = [ ...
    fullfile(projectRoot,"src","solver","private", ...
        "factor_symmetric_ldl.m")
    directPath
    fullfile(projectRoot,"src","solver","update_primal_dual_state.m")];
diagnosticCanonical = arrayfun(@canonical_path,diagnosticRhsDependencies);
forbiddenDiagnosticCanonical = ...
    arrayfun(@canonical_path,forbiddenDiagnosticDependencies);
forbiddenDiagnosticMask = ismember(lower(diagnosticCanonical), ...
    lower(forbiddenDiagnosticCanonical));
matchCount(row) = nnz(forbiddenDiagnosticMask);
matchedFiles(row) = strjoin(relative_paths( ...
    diagnosticRhsDependencies(forbiddenDiagnosticMask),projectRoot), ...
    "; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(diagnosticRhsPath,projectRoot);
filesScanned(row) = numel(diagnosticRhsDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-A42D1-STAGE-B-DEPENDENCY";
requirement(row) = "The A4-2D-1 entry dependency closure excludes Stage B";
a42dEntryDependencies = project_m_files( ...
    dependency_files(entryPaths(5)),projectRoot);
stageBRoot = canonical_path(fullfile(projectRoot,"stages","stage_B"));
stageBPrefix = lower(stageBRoot+filesep);
a42dCanonical = arrayfun(@canonical_path,a42dEntryDependencies);
stageBMask = startsWith(lower(a42dCanonical),stageBPrefix);
matchCount(row) = nnz(stageBMask);
matchedFiles(row) = strjoin(relative_paths( ...
    a42dEntryDependencies(stageBMask),projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(entryPaths(5),projectRoot);
filesScanned(row) = numel(a42dEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-A42D2A-STAGE-B-DEPENDENCY";
requirement(row) = "The A4-2D-2A entry dependency closure excludes Stage B";
a42d2aEntryDependencies = project_m_files( ...
    dependency_files(entryPaths(6)),projectRoot);
stageBRoot = canonical_path(fullfile(projectRoot,"stages","stage_B"));
stageBPrefix = lower(stageBRoot+filesep);
a42d2aCanonical = arrayfun(@canonical_path,a42d2aEntryDependencies);
stageBMask = startsWith(lower(a42d2aCanonical),stageBPrefix);
matchCount(row) = nnz(stageBMask);
matchedFiles(row) = strjoin(relative_paths( ...
    a42d2aEntryDependencies(stageBMask),projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(entryPaths(6),projectRoot);
filesScanned(row) = numel(a42d2aEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "A42D2A-OBJECTIVE-SCALE-DEFAULT-OFF";
requirement(row) = ...
    "Pre-existing A4 entries do not explicitly enable objective unitization";
formalEntryPaths = entryPaths(1:5);
enableHits = strings(0,1);
for fileIndex = 1:numel(formalEntryPaths)
    targetCode = strip_matlab_noncode(fileread(formalEntryPaths(fileIndex)));
    found = regexp(char(targetCode), ...
        'ObjectiveScaleMode\s*[,=]','match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        enableHits(end+1,1) = relative_path( ...
            formalEntryPaths(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(enableHits,'stable'),"; ");
details(row) = "targeted pre-existing A4 entry scan";
filesScanned(row) = numel(formalEntryPaths);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-RECURSIVE-FULL-DIRECTION-FALLBACK";
requirement(row) = ...
    "The official recursive dependency closure excludes the direct solver";
directCanonical = canonical_path(directPath);
recursiveCanonical = arrayfun(@canonical_path,recursiveDependencies);
matchCount(row) = nnz(strcmpi(recursiveCanonical,directCanonical));
matchedFiles(row) = strjoin(relative_paths( ...
    recursiveDependencies(strcmpi(recursiveCanonical,directCanonical)), ...
    projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(recursivePath,projectRoot);
filesScanned(row) = numel(recursiveDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "AUTOMATIC-REGULARIZATION-DISABLED";
requirement(row) = "automatic_regularization is explicitly false";
matchCount(row) = double(config.linear_algebra.automatic_regularization);
details(row) = "config/solver.yaml";
filesScanned(row) = numel(productionFiles);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "AUTOMATIC-SYMMETRIZATION-DISABLED";
requirement(row) = "automatic_symmetrization is explicitly false";
matchCount(row) = double(config.linear_algebra.automatic_symmetrization);
details(row) = "config/solver.yaml";
filesScanned(row) = numel(productionFiles);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "PARALLEL-MODE-OFF";
requirement(row) = "A4 parallel_mode remains off";
matchCount(row) = double(string(config.parallel_mode) ~= "off");
details(row) = "config/stage_A4.yaml";
filesScanned(row) = numel(productionFiles);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-RNS-DIRECT-RAW-OPERATOR-BACKSLASH";
requirement(row) = ...
    "A4-RNS-1 never falls back to direct M, partition.M, or rawOperator backslash";
rnsEntryDependencies = project_m_files( ...
    dependency_files(entryPaths(7)),projectRoot);
rnsCode = strings(numel(rnsEntryDependencies),1);
backslashHits = strings(0,1);
backslashPattern = ...
    "(?<![A-Za-z0-9_])(?:M|rawOperator|partition\s*\.\s*M|" + ...
    "core\s*\.\s*matrix)\s*\\";
for fileIndex = 1:numel(rnsEntryDependencies)
    rnsCode(fileIndex) = strip_matlab_noncode( ...
        fileread(rnsEntryDependencies(fileIndex)));
    found = regexp(char(rnsCode(fileIndex)), ...
        backslashPattern,'match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        backslashHits(end+1,1) = relative_path( ...
            rnsEntryDependencies(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(backslashHits,'stable'),"; ");
details(row) = "targeted A4-RNS-1 raw-operator direct-solve scan";
filesScanned(row) = numel(rnsEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-RNS-AUTOMATIC-SYMMETRIZATION";
requirement(row) = ...
    "A4-RNS-1 contains no arithmetic average with a transpose";
symmetrizationHits = strings(0,1);
symmetrizationPattern = ...
    "(?:(?:0?\.5)\s*\*\s*\(|\(\s*)" + ...
    "(?:M|matrix|rawOperator|partition\s*\.\s*M)\s*\+\s*" + ...
    "(?:M|matrix|rawOperator|partition\s*\.\s*M)\s*\.'";
for fileIndex = 1:numel(rnsEntryDependencies)
    found = regexp(char(rnsCode(fileIndex)), ...
        symmetrizationPattern,'match');
    matchCount(row) = matchCount(row)+numel(found);
    if ~isempty(found)
        symmetrizationHits(end+1,1) = relative_path( ...
            rnsEntryDependencies(fileIndex),projectRoot); %#ok<AGROW>
    end
end
matchedFiles(row) = strjoin(unique(symmetrizationHits,'stable'),"; ");
details(row) = "targeted A4-RNS-1 transpose-average scan";
filesScanned(row) = numel(rnsEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-RNS-DIRECT-SOLVER-DEPENDENCY";
requirement(row) = ...
    "The A4-RNS-1 dependency closure excludes the complete-KKT direct solver";
rnsCanonical = arrayfun(@canonical_path,rnsEntryDependencies);
directMask = strcmpi(rnsCanonical,canonical_path(directPath));
matchCount(row) = nnz(directMask);
matchedFiles(row) = strjoin(relative_paths( ...
    rnsEntryDependencies(directMask),projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(entryPaths(7),projectRoot);
filesScanned(row) = numel(rnsEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

row = row+1;
checkId(row) = "NO-RNS-STAGE-B-DEPENDENCY";
requirement(row) = "The A4-RNS-1 entry dependency closure excludes Stage B";
rnsStageBMask = startsWith(lower(rnsCanonical),stageBPrefix);
matchCount(row) = nnz(rnsStageBMask);
matchedFiles(row) = strjoin(relative_paths( ...
    rnsEntryDependencies(rnsStageBMask),projectRoot),"; ");
details(row) = "dependency closure rooted at "+ ...
    relative_path(entryPaths(7),projectRoot);
filesScanned(row) = numel(rnsEntryDependencies);
if matchCount(row) ~= 0
    status(row) = "FAIL";
end

audit = table(checkId,requirement,matchCount,matchedFiles,details, ...
    filesScanned,status,'VariableNames', ...
    {'check_id','requirement','match_count','matched_files', ...
    'details','files_scanned','status'});
end

function rule = make_rule(id,requirement,pattern)
rule = struct("id",string(id),"requirement",string(requirement), ...
    "pattern",string(pattern));
end

function files = dependency_files(entryPath)
try
    [requiredFiles,~] = matlab.codetools.requiredFilesAndProducts( ...
        char(entryPath));
catch cause
    wrapped = MException("stageA4:scan:DependencyAnalysisFailed", ...
        "Could not determine production dependencies for %s: %s", ...
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

function output = strip_matlab_noncode(textValue)
% Remove block/line comments and quoted literals before call matching.
output = string(textValue);
output = regexprep(output,'"(?:""|[^"])*"',' ');
% A quote preceded by an identifier, closing delimiter, or dot is treated
% as a transpose; other paired quotes are character literals.
output = regexprep(output, ...
    "(?<![A-Za-z0-9_\)\]\}\.])'(?:''|[^'])*'"," ");
output = regexprep(output,'(?s)%\{.*?%\}',' ');
lines = splitlines(output);
for lineIndex = 1:numel(lines)
    commentStart = regexp(char(lines(lineIndex)),'%', 'once');
    if ~isempty(commentStart)
        lines(lineIndex) = extractBefore(lines(lineIndex),commentStart);
    end
end
output = strjoin(lines,newline);
end

function values = relative_paths(paths,root)
values = strings(numel(paths),1);
for index = 1:numel(paths)
    values(index) = relative_path(paths(index),root);
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
