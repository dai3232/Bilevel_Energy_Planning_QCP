function audit = scan_stage_a3_forbidden_code(projectRoot,config)
%SCAN_STAGE_A3_FORBIDDEN_CODE Audit the frozen serial/sparse A3 scope.

arguments
    projectRoot (1,1) string
    config (1,1) struct
end
solverFiles=dir(fullfile(projectRoot,"src","+rkkt","+solver","**","*.m"));
solverPaths=strings(numel(solverFiles),1); solverText=strings(numel(solverFiles),1);
for k=1:numel(solverFiles)
    solverPaths(k)=string(fullfile(solverFiles(k).folder,solverFiles(k).name));
    solverText(k)=string(fileread(solverPaths(k)));
end
check_id=["FORBIDDEN-INV";"FORBIDDEN-PINV";"FORBIDDEN-LSQMINNORM"; ...
    "FORBIDDEN-RANDOM";"RECURSIVE-FULL-DIRECTION-FALLBACK"; ...
    "FULL-KKT-OR-DAY-CHAIN-DENSE-CONVERSION"; ...
    "AUTOMATIC-REGULARIZATION";"AUTOMATIC-SYMMETRIZATION"; ...
    "A3-PARALLEL-CALL"];
requirement=["No inv call";"No pinv call";"No lsqminnorm call"; ...
    "No random-number call";"No recursive fallback to a full-KKT direction"; ...
    "No dense conversion of complete KKT or any day chain"; ...
    "Automatic regularization disabled";"Automatic symmetrization disabled"; ...
    "No parpool, parfor, parfeval, backgroundPool, or gcp call"];
patterns=["(?<![A-Za-z0-9_])inv\s*\("; ...
    "(?<![A-Za-z0-9_])pinv\s*\(";"lsqminnorm\s*\("; ...
    "(?<![A-Za-z0-9_])randn?\s*\("; ...
    "solve_(?:stage_a3_)?full_kkt_direction\s*\("; ...
    "full\s*\(\s*(?:assembly\.matrix|fullAssembly\.matrix|partition\.M|kkt\.matrix)"; ...
    "";""; ...
    "(?<![A-Za-z0-9_])(?:parpool|parfor|parfeval|backgroundPool|gcp)(?![A-Za-z0-9_])"];
match_count=zeros(numel(check_id),1);
details=repmat("No forbidden match.",numel(check_id),1);
for row=1:6
    matches=strings(0,1);
    for k=1:numel(solverFiles)
        if row==5 && solverFiles(k).name~="solve_stage_a3_recursive_direction.m"
            continue
        end
        found=regexp(char(solverText(k)),char(patterns(row)),'match');
        match_count(row)=match_count(row)+numel(found);
        if ~isempty(found), matches(end+1,1)=relative_path(solverPaths(k),projectRoot); end %#ok<AGROW>
    end
    if ~isempty(matches), details(row)=strjoin(unique(matches),"; "); end
end
match_count(7)=double(config.linear_algebra.automatic_regularization);
match_count(8)=double(config.linear_algebra.automatic_symmetrization);
details(7:8)="Configuration flag must be false.";
parallelCandidates=[string(fullfile(projectRoot,"main_stage_A3.m")); ...
    list_m_files(fullfile(projectRoot,"src","+rkkt","+model"),"*stage_a3*.m"); ...
    list_m_files(fullfile(projectRoot,"src","+rkkt","+indexing"),"*stage_a3*.m"); ...
    list_m_files(fullfile(projectRoot,"src","+rkkt","+solver"),"*stage_a3*.m"); ...
    string(fullfile(projectRoot,"src","+rkkt","+diagnostics", ...
        "run_stage_a3_direction_verification.m")); ...
    string(fullfile(projectRoot,"src","+rkkt","+artifacts", ...
        "export_stage_a3_artifacts.m"))];
parallelCandidates=unique(parallelCandidates(isfile(parallelCandidates)),'stable');
matched=strings(0,1);
for pathValue=parallelCandidates.'
    found=regexp(fileread(pathValue),char(patterns(9)),'match');
    match_count(9)=match_count(9)+numel(found);
    if ~isempty(found), matched(end+1,1)=relative_path(pathValue,projectRoot); end %#ok<AGROW>
end
if ~isempty(matched), details(9)=strjoin(unique(matched),"; "); end
files_scanned=repmat(numel(solverFiles),numel(check_id),1);
files_scanned(9)=numel(parallelCandidates);
status=repmat("PASS",numel(check_id),1); status(match_count~=0)="FAIL";
actual=match_count; evidence=details;
audit=table(check_id,requirement,actual,status,evidence, ...
    files_scanned,match_count,details);
end

function paths=list_m_files(folder,pattern)
files=dir(fullfile(folder,pattern)); paths=strings(numel(files),1);
for k=1:numel(files), paths(k)=string(fullfile(files(k).folder,files(k).name)); end
end
function value=relative_path(pathValue,root)
pathValue=string(char(java.io.File(char(pathValue)).getCanonicalPath()));
root=string(char(java.io.File(char(root)).getCanonicalPath()));
value=replace(extractAfter(pathValue,strlength(root)+1),'\','/');
end
