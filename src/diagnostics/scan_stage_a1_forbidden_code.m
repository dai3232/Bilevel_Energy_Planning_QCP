function audit = scan_stage_a1_forbidden_code(projectRoot,config)
%SCAN_STAGE_A1_FORBIDDEN_CODE Deterministically audit prohibited A1 paths.

arguments
    projectRoot (1,1) string
    config (1,1) struct
end
sourceRoots = [fullfile(projectRoot,"src","model"); ...
    fullfile(projectRoot,"src","indexing"); ...
    fullfile(projectRoot,"src","solver"); ...
    fullfile(projectRoot,"src","diagnostics"); ...
    fullfile(projectRoot,"src","artifacts"); ...
    fullfile(projectRoot,"src","reporting")];
files = strings(0,1);
for root = sourceRoots.'
    listing = dir(fullfile(root,"**","*.m"));
    for k = 1:numel(listing)
        files(end+1,1) = string(fullfile(listing(k).folder,listing(k).name)); %#ok<AGROW>
    end
end
mainPath = fullfile(projectRoot,"main_stage_A1.m");
if isfile(mainPath)
    files(end+1,1) = mainPath;
end
files = unique(files,"stable");

rules = [ ...
    struct("id","NO_INV","requirement","No inv call", ...
        "pattern","(?<![A-Za-z0-9_])inv\s*\("); ...
    struct("id","NO_PINV","requirement","No pinv call", ...
        "pattern","(?<![A-Za-z0-9_])pinv\s*\("); ...
    struct("id","NO_LSQMINNORM","requirement","No lsqminnorm call", ...
        "pattern","(?<![A-Za-z0-9_])lsqminnorm\s*\("); ...
    struct("id","NO_RANDOM_MATRIX","requirement","No rand or randn call", ...
        "pattern","(?<![A-Za-z0-9_])randn?\s*\("); ...
    struct("id","NO_FULL_KKT_DENSIFICATION", ...
        "requirement","No full conversion of complete KKT or chain", ...
        "pattern","full\s*\(\s*(?:[^\r\n)]*(?:kkt|saddle|fullAssembly\.matrix|partition\.M))"); ...
    struct("id","NO_PARALLEL_CALL", ...
        "requirement","No parallel execution call in the A1 path", ...
        "pattern","(?<![A-Za-z0-9_])(?:parpool|parfor|parfeval|backgroundPool|gcp)(?![A-Za-z0-9_])"); ...
    struct("id","NO_RECURSIVE_FULL_DIRECTION_FALLBACK", ...
        "requirement","Recursive route never calls the direct direction solver", ...
        "pattern","solve_full_kkt_direction\s*\(")];

n = numel(rules) + 4;
ruleId = strings(n,1);
requirement = strings(n,1);
matchCount = zeros(n,1);
matchedFiles = strings(n,1);
details = strings(n,1);
status = repmat("PASS",n,1);
row = 0;
for r = 1:numel(rules)
    row = row + 1;
    hits = strings(0,1);
    filesForRule = files;
    if rules(r).id == "NO_PARALLEL_CALL"
        relativeFiles = arrayfun(@(file) relative_path(file,projectRoot), ...
            files,"UniformOutput",false);
        relativeFiles = string(relativeFiles);
        filesForRule = files(contains(lower(relativeFiles),"stage_a1") | ...
            startsWith(lower(relativeFiles),"src/solver/") | ...
            relativeFiles=="main_stage_A1.m");
        filesForRule = filesForRule(~endsWith(lower(filesForRule), ...
            lower(fullfile("diagnostics","scan_stage_a1_forbidden_code.m"))));
    end
    for file = filesForRule.'
        text = fileread(file);
        if ~isempty(regexpi(text,rules(r).pattern,'once'))
            hits(end+1,1) = relative_path(file,projectRoot); %#ok<AGROW>
        end
    end
    % The direct solver is allowed to call itself by function declaration;
    % the fallback audit is restricted to the recursive implementation.
    if rules(r).id == "NO_RECURSIVE_FULL_DIRECTION_FALLBACK"
        recursivePath = fullfile(projectRoot,"src","solver", ...
            "solve_recursive_direction.m");
        hits = strings(0,1);
        if isfile(recursivePath)
            recursiveText = fileread(recursivePath);
            if ~isempty(regexp(recursiveText,rules(r).pattern,'once'))
                hits = relative_path(recursivePath,projectRoot);
            end
        end
    end
    ruleId(row) = rules(r).id;
    requirement(row) = rules(r).requirement;
    matchCount(row) = numel(hits);
    matchedFiles(row) = strjoin(hits,"; ");
    details(row) = "regex=" + rules(r).pattern;
    if ~isempty(hits), status(row) = "FAIL"; end
end

row = row + 1;
ruleId(row) = "NO_AUTOMATIC_REGULARIZATION";
requirement(row) = "automatic_regularization is explicitly false";
matchCount(row) = double(config.linear_algebra.automatic_regularization);
details(row) = "config/solver.yaml";
if matchCount(row) ~= 0, status(row) = "FAIL"; end

row = row + 1;
ruleId(row) = "NO_AUTOMATIC_SYMMETRIZATION";
requirement(row) = "automatic_symmetrization is explicitly false";
matchCount(row) = double(config.linear_algebra.automatic_symmetrization);
details(row) = "config/solver.yaml";
if matchCount(row) ~= 0, status(row) = "FAIL"; end

row = row + 1;
ruleId(row) = "ONE_NEWTON_DIRECTION_ONLY";
requirement(row) = "Exactly one direction and no full IPM";
matchCount(row) = double(config.newton_direction_count ~= 1 || ...
    config.run_full_ipm);
details(row) = "config/stage_A1.yaml";
if matchCount(row) ~= 0, status(row) = "FAIL"; end

row = row + 1;
ruleId(row) = "NO_PARALLEL_EXECUTION";
requirement(row) = "Parallel mode remains off";
matchCount(row) = double(config.parallel_mode ~= "off");
details(row) = "config/stage_A1.yaml";
if matchCount(row) ~= 0, status(row) = "FAIL"; end

audit = table(ruleId,requirement,matchCount,matchedFiles,details,status, ...
    'VariableNames',{'rule_id','requirement','match_count', ...
    'matched_files','details','status'});
end

function value = relative_path(pathValue,projectRoot)
value = replace(extractAfter(string(pathValue),strlength(projectRoot)+1),'\','/');
end
