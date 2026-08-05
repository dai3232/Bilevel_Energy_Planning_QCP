function audit = verify_stage_a3_historical_run(projectRoot, runId, options)
%VERIFY_STAGE_A3_HISTORICAL_RUN Validate one immutable historical A3 run.
% PASS runs require a complete evidence inventory. Other project-defined
% terminal states require the evidence inventory that the run actually
% persisted; PASS-only artifacts are not assumed. A same-named ZIP, when
% present, must be a readable byte-for-byte snapshot of the run directory.

arguments
    projectRoot (1,1) string
    runId (1,1) string
    options.VerifyCommitAncestor (1,1) logical = true
end

commitPrefix=parse_valid_run_id(runId);
runRoot=fullfile(projectRoot,"runs",runId);
manifestPath=fullfile(runRoot,"run_manifest.json");
assert(isfolder(runRoot)&&isfile(manifestPath), ...
    "stageA3:gate:PriorA3RunMissing", ...
    "Preserved A3 run is incomplete: %s",runId);
initializingPath=fullfile(runRoot,".initializing");
assert(~isfile(initializingPath)&&~isfolder(initializingPath), ...
    "stageA3:gate:PriorA3InitializationIncomplete", ...
    "Terminal historical A3 run still contains .initializing: %s",runId);
try
    manifest=jsondecode(fileread(manifestPath));
catch exception
    error("stageA3:gate:PriorA3ManifestInvalid", ...
        "Could not decode preserved A3 manifest %s: %s", ...
        runId,exception.message);
end

requiredFields=["run_id","stage_id","status","git_commit"];
assert(all(isfield(manifest,cellstr(requiredFields))), ...
    "stageA3:gate:PriorA3Identity", ...
    "Preserved A3 manifest is missing identity fields: %s",runId);
status=string(manifest.status);
allowedStates=["PASS","FAIL_RETRYABLE","BLOCKED_EXTERNAL", ...
    "NEEDS_MODEL_DECISION"];
commit=lower(string(manifest.git_commit));
identityValid=isscalar(status)&&ismember(status,allowedStates)&& ...
    string(manifest.run_id)==runId&& ...
    string(manifest.stage_id)=="stage_A3"&& ...
    ~isempty(regexp(char(commit),'^[0-9a-f]{40}$','once'))&& ...
    startsWith(commit,commitPrefix);
assert(identityValid,"stageA3:gate:PriorA3Identity", ...
    "Preserved A3 run identity, commit, or terminal state is invalid: %s", ...
    runId);

if options.VerifyCommitAncestor
    [ancestorStatus,~]=git_command(projectRoot, ...
        "merge-base --is-ancestor "+commit+" HEAD");
    assert(ancestorStatus==0,"stageA3:gate:PriorA3Commit", ...
        "Preserved A3 run commit is not an ancestor of HEAD: %s",runId);
end

[inventoryPath,inventoryRelative]=resolve_evidence_inventory( ...
    runRoot,manifest,status);
inventoryAudit=verify_evidence_inventory(runRoot,inventoryPath, ...
    inventoryRelative,status);

zipPath=fullfile(projectRoot,"runs",runId+".zip");
zipPresent=isfile(zipPath);
zipFileCount=0; zipSha256="";
if zipPresent
    zipAudit=verify_matching_zip(runRoot,zipPath,runId);
    zipFileCount=zipAudit.file_count;
    zipSha256=zipAudit.sha256;
end

audit=struct( ...
    "run_id",runId, ...
    "status",status, ...
    "git_commit",commit, ...
    "evidence_inventory",inventoryRelative, ...
    "evidence_file_count",inventoryAudit.file_count, ...
    "zip_present",zipPresent, ...
    "zip_file_count",zipFileCount, ...
    "zip_sha256",zipSha256);
end

function commitPrefix=parse_valid_run_id(runId)
match=regexp(char(runId), ...
    ['^(?<base>[0-9]{8}_[0-9]{6}_stage_A3_[0-9a-f]{8})' ...
    '(?<collision>_[0-9]{3,})?$'], ...
    'names','once');
valid=~isempty(match);
if valid&&~isempty(match.collision)
    digits=string(match.collision(2:end));
    number=str2double(digits);
    valid=isfinite(number)&&number==fix(number)&&number>=2&& ...
        string(match.collision)==string(sprintf('_%03d',number));
end
assert(valid,"stageA3:gate:PriorA3RunId", ...
    "Invalid historical A3 run ID: %s",runId);
base=string(match.base);
commitPrefix=extractAfter(base,strlength(base)-8);
end

function [pathValue,relative]=resolve_evidence_inventory(runRoot,manifest,status)
relative="";
if isfield(manifest,"evidence_hashes")&& ...
        (ischar(manifest.evidence_hashes)|| ...
        (isstring(manifest.evidence_hashes)&&isscalar(manifest.evidence_hashes)))
    relative=string(manifest.evidence_hashes);
end
if strlength(relative)==0
    if status=="PASS"
        relative="acceptance/evidence_hashes.csv";
    elseif isfile(fullfile(runRoot,"acceptance", ...
            "evidence_hashes_failure_addendum.csv"))
        relative="acceptance/evidence_hashes_failure_addendum.csv";
    elseif isfile(fullfile(runRoot,"acceptance","evidence_hashes.csv"))
        relative="acceptance/evidence_hashes.csv";
    end
end
assert(strlength(relative)>0&&is_safe_relative_path(relative), ...
    "stageA3:gate:HistoricalEvidenceMissing", ...
    "%s run does not identify a safe persisted evidence inventory.",status);
pathValue=fullfile(runRoot,strrep(relative,'/',filesep));
assert(isfile(pathValue),"stageA3:gate:HistoricalEvidenceMissing", ...
    "%s evidence hash inventory is missing: %s",status,relative);
assert(isfield(manifest,"evidence_hashes_sha256"), ...
    "stageA3:gate:HistoricalEvidenceInventoryChanged", ...
    "%s manifest does not bind its evidence inventory SHA256.",status);
expected=lower(string(manifest.evidence_hashes_sha256));
actual=lower(string(rkkt.data.compute_sha256_file(pathValue)));
assert(~isempty(regexp(char(expected),'^[0-9a-f]{64}$','once'))&& ...
    actual==expected, ...
    "stageA3:gate:HistoricalEvidenceInventoryChanged", ...
    "%s evidence inventory SHA256 differs from its manifest.",status);
end

function audit=verify_evidence_inventory(runRoot,inventoryPath, ...
        inventoryRelative,status)
try
    inventory=readtable(inventoryPath,'TextType','string', ...
        'VariableNamingRule','preserve');
catch exception
    error("stageA3:gate:HistoricalEvidenceInventoryInvalid", ...
        "Could not read %s evidence inventory: %s",status,exception.message);
end
required=["relative_path","sha256","status"];
assert(all(ismember(required,string(inventory.Properties.VariableNames)))&& ...
    height(inventory)>0, ...
    "stageA3:gate:HistoricalEvidenceInventoryInvalid", ...
    "%s evidence inventory is empty or lacks required columns.",status);
relative=replace(string(inventory.relative_path),'\','/');
hashes=lower(string(inventory.sha256));
rowStatus=string(inventory.status);
assert(numel(unique(relative))==height(inventory)&& ...
    all(rowStatus=="PASS")&&all(arrayfun(@is_safe_relative_path,relative))&& ...
    all(arrayfun(@(x)~isempty(regexp(char(x),'^[0-9a-f]{64}$','once')),hashes)), ...
    "stageA3:gate:HistoricalEvidenceInventoryInvalid", ...
    "%s evidence inventory has duplicate, unsafe, failed, or invalid rows.", ...
    status);
for rowNumber=1:height(inventory)
    pathValue=fullfile(runRoot,strrep(relative(rowNumber),'/',filesep));
    exists=isfile(pathValue);
    if exists
        actualHash=lower(string(rkkt.data.compute_sha256_file(pathValue)));
    else
        actualHash="";
    end
    assert(exists&&actualHash==hashes(rowNumber), ...
        "stageA3:gate:HistoricalEvidenceChanged", ...
        "%s evidence changed or is missing: %s",status,relative(rowNumber));
    if ismember("bytes",string(inventory.Properties.VariableNames))
        info=dir(pathValue);
        assert(isscalar(info)&&double(inventory.bytes(rowNumber))==info.bytes, ...
            "stageA3:gate:HistoricalEvidenceChanged", ...
            "%s evidence byte count changed: %s",status,relative(rowNumber));
    end
end

actual=recursive_file_inventory(runRoot);
excluded=["run_manifest.json",replace(inventoryRelative,'\','/')];
actual=setdiff(actual,excluded,'stable');
assert(isequal(sort(relative),sort(actual)), ...
    "stageA3:gate:HistoricalEvidenceSetMismatch", ...
    "%s evidence inventory does not exactly cover the persisted run files.", ...
    status);
audit=struct("file_count",height(inventory));
end

function audit=verify_matching_zip(runRoot,zipPath,runId)
assert(isfolder(runRoot),"stageA3:gate:PriorA3ZipWithoutDirectory", ...
    "Historical A3 ZIP has no same-named run directory: %s",runId);
sourceFiles=recursive_file_inventory(runRoot);
sourceDirectories=recursive_directory_inventory(runRoot);
entryAudit=inspect_zip_entries(zipPath,runId,runRoot, ...
    sourceFiles,sourceDirectories);
tempRoot=string(tempname(tempdir));
[created,message]=mkdir(tempRoot);
assert(created,"stageA3:gate:PriorA3ZipTemporaryDirectory", ...
    "Could not create ZIP validation directory: %s",message);
guard=onCleanup(@()remove_tree(tempRoot));
try
    unzip(zipPath,tempRoot);
catch exception
    error("stageA3:gate:PriorA3ZipUnreadable", ...
        "Could not extract historical A3 ZIP %s: %s",runId,exception.message);
end
extractedRoot=fullfile(tempRoot,runId);
assert(isfolder(extractedRoot),"stageA3:gate:PriorA3ZipTopLevel", ...
    "Historical A3 ZIP does not contain the required top-level directory %s.", ...
    runId);
zipFiles=recursive_file_inventory(extractedRoot);
assert(isequal(sort(sourceFiles),sort(zipFiles)), ...
    "stageA3:gate:PriorA3ZipFileSetMismatch", ...
    "Historical A3 ZIP file set differs from directory %s.",runId);
zipDirectories=recursive_directory_inventory(extractedRoot);
assert(isequal(sort(sourceDirectories),sort(zipDirectories)), ...
    "stageA3:gate:PriorA3ZipDirectorySetMismatch", ...
    "Historical A3 ZIP directory set differs from directory %s.",runId);
for k=1:numel(sourceFiles)
    relative=sourceFiles(k);
    source=fullfile(runRoot,strrep(relative,'/',filesep));
    extracted=fullfile(extractedRoot,strrep(relative,'/',filesep));
    sourceInfo=dir(source); extractedInfo=dir(extracted);
    sameBytes=isscalar(sourceInfo)&&isscalar(extractedInfo)&& ...
        sourceInfo.bytes==extractedInfo.bytes;
    sameHash=sameBytes&&lower(string(rkkt.data.compute_sha256_file(source)))== ...
        lower(string(rkkt.data.compute_sha256_file(extracted)));
    assert(sameHash,"stageA3:gate:PriorA3ZipContentMismatch", ...
        "Historical A3 ZIP content differs from directory %s at %s.", ...
        runId,relative);
end
audit=struct("file_count",entryAudit.file_count, ...
    "sha256",lower(string(rkkt.data.compute_sha256_file(zipPath))));
clear guard
end

function audit=inspect_zip_entries(zipPath,runId,runRoot, ...
        sourceFiles,sourceDirectories)
zipObject=[];
try
    zipObject=java.util.zip.ZipFile(char(zipPath));
    guard=onCleanup(@()close_zip(zipObject));
    entries=zipObject.entries(); rawNames=strings(0,1);
    fileNames=strings(0,1); fileSizes=zeros(0,1);
    explicitDirectories=strings(0,1);
    while entries.hasMoreElements()
        entry=entries.nextElement();
        raw=string(char(entry.getName()));
        isDirectory=logical(entry.isDirectory());
        assert(strlength(raw)>0&&~contains(raw,"\")&& ...
            ~startsWith(raw,"/")&& ...
            isempty(regexp(char(raw),'^[A-Za-z]:','once')), ...
            "stageA3:gate:PriorA3ZipUnsafeEntry", ...
            "Historical A3 ZIP contains an unsafe absolute/backslash entry: %s",raw);
        assert(isDirectory==endsWith(raw,"/"), ...
            "stageA3:gate:PriorA3ZipUnsafeEntry", ...
            "Historical A3 ZIP entry type and trailing slash disagree: %s",raw);
        normalized=raw;
        if isDirectory, normalized=extractBefore(raw,strlength(raw)); end
        pieces=split(normalized,"/");
        assert(~isempty(pieces)&&all(strlength(pieces)>0)&& ...
            ~any(ismember(pieces,[".",".."]))&&pieces(1)==runId, ...
            "stageA3:gate:PriorA3ZipTopLevel", ...
            "Historical A3 ZIP entry is outside the single %s top level: %s", ...
            runId,raw);
        assert(safe_windows_segments(pieces(2:end)), ...
            "stageA3:gate:PriorA3ZipUnsafeEntry", ...
            "Historical A3 ZIP entry is unsafe on Windows: %s",raw);
        rawNames(end+1,1)=raw; %#ok<AGROW>
        if ~isDirectory
            assert(numel(pieces)>1,"stageA3:gate:PriorA3ZipTopLevel", ...
                "Historical A3 ZIP contains a top-level file instead of %s/.", ...
                runId);
            fileNames(end+1,1)=strjoin(pieces(2:end),"/"); %#ok<AGROW>
            declaredSize=double(entry.getSize());
            assert(isfinite(declaredSize)&&declaredSize>=0&& ...
                declaredSize==fix(declaredSize), ...
                "stageA3:gate:PriorA3ZipUnreadable", ...
                "Historical A3 ZIP file has an invalid declared size: %s",raw);
            fileSizes(end+1,1)=declaredSize; %#ok<AGROW>
        elseif numel(pieces)>1
            explicitDirectories(end+1,1)= ...
                strjoin(pieces(2:end),"/"); %#ok<AGROW>
        end
    end
    assert(~isempty(fileNames),"stageA3:gate:PriorA3ZipUnreadable", ...
        "Historical A3 ZIP contains no files: %s",runId);
    assert(numel(unique(rawNames))==numel(rawNames)&& ...
        numel(unique(fileNames))==numel(fileNames), ...
        "stageA3:gate:PriorA3ZipDuplicateEntry", ...
        "Historical A3 ZIP contains duplicate entries: %s",runId);

    impliedDirectories=parent_directories(fileNames);
    directoryParents=parent_directories(explicitDirectories);
    zipDirectories=unique([explicitDirectories;impliedDirectories; ...
        directoryParents],'sorted');
    fileCase=lower(fileNames); directoryCase=lower(zipDirectories);
    aliasFree=numel(unique(fileCase))==numel(fileCase)&& ...
        numel(unique(directoryCase))==numel(directoryCase)&& ...
        isempty(intersect(fileCase,directoryCase));
    assert(aliasFree,"stageA3:gate:PriorA3ZipWindowsAlias", ...
        "Historical A3 ZIP contains a case-folded or file/directory alias: %s", ...
        runId);

    [sortedFiles,fileOrder]=sort(fileNames);
    sortedSizes=fileSizes(fileOrder);
    assert(isequal(sortedFiles,sort(sourceFiles)), ...
        "stageA3:gate:PriorA3ZipFileSetMismatch", ...
        "Historical A3 ZIP central file inventory differs from directory %s.", ...
        runId);
    assert(isequal(sort(zipDirectories),sort(sourceDirectories)), ...
        "stageA3:gate:PriorA3ZipDirectorySetMismatch", ...
        "Historical A3 ZIP contains missing or extra directories for %s.",runId);
    sourceBytes=zeros(numel(sortedFiles),1);
    for k=1:numel(sortedFiles)
        sourcePath=fullfile(runRoot,strrep(sortedFiles(k),'/',filesep));
        info=dir(sourcePath);
        assert(isscalar(info)&&~info.isdir, ...
            "stageA3:gate:PriorA3ZipFileSetMismatch", ...
            "Historical A3 source file disappeared during ZIP audit: %s", ...
            sortedFiles(k));
        sourceBytes(k)=double(info.bytes);
    end
    assert(isequal(sortedSizes,sourceBytes)&& ...
        sum(sortedSizes)==sum(sourceBytes), ...
        "stageA3:gate:PriorA3ZipContentMismatch", ...
        "Historical A3 ZIP declared byte sizes differ from directory %s.",runId);
    audit=struct("file_count",numel(sortedFiles), ...
        "directory_count",numel(zipDirectories), ...
        "declared_bytes",sum(sortedSizes));
    clear guard
catch exception
    close_zip(zipObject);
    if startsWith(string(exception.identifier),"stageA3:gate:")
        rethrow(exception);
    end
    error("stageA3:gate:PriorA3ZipUnreadable", ...
        "Could not read historical A3 ZIP %s: %s",runId,exception.message);
end
end

function valid=safe_windows_segments(segments)
if isempty(segments), valid=true; return; end
segments=string(segments(:));
valid=all(strlength(segments)>0)&&~any(contains(segments,":"))&& ...
    ~any(endsWith(segments,"."))&&~any(endsWith(segments," "));
if ~valid, return; end
reserved=["CON","PRN","AUX","NUL",compose("COM%d",1:9), ...
    compose("LPT%d",1:9)];
for k=1:numel(segments)
    token=split(segments(k),".");
    if ismember(upper(token(1)),reserved)
        valid=false;
        return
    end
end
end

function directories=parent_directories(paths)
directories=strings(0,1);
for k=1:numel(paths)
    pieces=split(string(paths(k)),"/");
    for depth=1:numel(pieces)-1
        directories(end+1,1)=strjoin(pieces(1:depth),"/"); %#ok<AGROW>
    end
end
directories=unique(directories,'sorted');
end

function files=recursive_file_inventory(root)
listing=dir(fullfile(root,"**","*")); files=strings(0,1);
prefixLength=strlength(string(root))+1;
for k=1:numel(listing)
    if listing(k).isdir, continue; end
    absolute=string(fullfile(listing(k).folder,listing(k).name));
    relative=replace(extractAfter(absolute,prefixLength),'\','/');
    files(end+1,1)=relative; %#ok<AGROW>
end
files=sort(files);
end

function directories=recursive_directory_inventory(root)
listing=dir(fullfile(root,"**","*")); directories=strings(0,1);
prefixLength=strlength(string(root))+1;
for k=1:numel(listing)
    if ~listing(k).isdir||ismember(string(listing(k).name),[".",".."])
        continue
    end
    absolute=string(fullfile(listing(k).folder,listing(k).name));
    relative=replace(extractAfter(absolute,prefixLength),'\','/');
    if strlength(relative)>0
        directories(end+1,1)=relative; %#ok<AGROW>
    end
end
directories=sort(unique(directories));
end

function valid=is_safe_relative_path(value)
value=replace(string(value),'\','/');
parts=split(value,"/");
valid=isscalar(value)&&strlength(value)>0&&~startsWith(value,"/")&& ...
    isempty(regexp(char(value),'^[A-Za-z]:','once'))&& ...
    ~endsWith(value,"/")&&all(strlength(parts)>0)&& ...
    ~any(ismember(parts,[".",".."]))&&~contains(value,":");
end

function [status,output]=git_command(root,arguments)
safe=replace(string(root),'\','/');
quotedSafe='"'+replace(safe,'"','\"')+'"';
quotedRoot='"'+replace(string(root),'"','\"')+'"';
command="git -c safe.directory="+quotedSafe+" -C "+quotedRoot+" "+arguments;
[status,output]=system(char(command));
end

function close_zip(zipObject)
try
    if ~isempty(zipObject), zipObject.close(); end
catch
end
end

function remove_tree(pathValue)
try
    if isfolder(pathValue), rmdir(pathValue,'s'); end
catch
end
end
