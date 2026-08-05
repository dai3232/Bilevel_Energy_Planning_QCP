function audits = verify_stage_a3_historical_preflight( ...
        projectRoot,worktreeLines,options)
%VERIFY_STAGE_A3_HISTORICAL_PREFLIGHT Classify and validate A3 run evidence.
% Recognizes both untracked run directories and same-named ZIP files. Any
% other unapproved worktree entry remains a blocking unknown.

arguments
    projectRoot (1,1) string
    worktreeLines string
    options.AllowedUntracked string = strings(0,1)
    options.VerifyCommitAncestor (1,1) logical = true
end

lines=strip(worktreeLines(:)); lines=lines(strlength(lines)>0);
allowed=strip(options.AllowedUntracked(:));
unknown=strings(0,1); discovered=strings(0,1);
directoryPattern='^\?\? runs/([^/]+)/$';
zipPattern='^\?\? runs/([^/]+)\.zip$';
for lineNumber=1:numel(lines)
    if ismember(lines(lineNumber),allowed), continue; end
    token=regexp(char(lines(lineNumber)),directoryPattern,'tokens','once');
    if isempty(token)
        token=regexp(char(lines(lineNumber)),zipPattern,'tokens','once');
    end
    if isempty(token)||~is_valid_historical_run_id(string(token{1}))
        unknown(end+1,1)=lines(lineNumber); %#ok<AGROW>
    else
        discovered(end+1,1)=string(token{1}); %#ok<AGROW>
    end
end
assert(isempty(unknown),"stageA3:gate:UnknownUntracked", ...
    "Unknown untracked content exists: %s",strjoin(unknown,"; "));

% Enumerate strict historical names too, so a ZIP can never escape content
% validation merely because a Git ignore rule hid its status line.
runsRoot=fullfile(projectRoot,"runs");
if isfolder(runsRoot)
    directoryListing=dir(runsRoot);
    for k=1:numel(directoryListing)
        name=string(directoryListing(k).name);
        if directoryListing(k).isdir&&~ismember(name,[".",".."])&& ...
                is_valid_historical_run_id(name)
            discovered(end+1,1)=name; %#ok<AGROW>
        elseif ~directoryListing(k).isdir&&endsWith(name,".zip")
            base=extractBefore(name,strlength(name)-3);
            if is_valid_historical_run_id(base)
                discovered(end+1,1)=base; %#ok<AGROW>
            end
        end
    end
end
discovered=unique(discovered,'sorted');
if isempty(discovered)
    audits=repmat(empty_audit(),0,1);
    return
end
audits=repmat(empty_audit(),numel(discovered),1);
for k=1:numel(discovered)
    audits(k)=rkkt.artifacts.verify_stage_a3_historical_run(projectRoot,discovered(k), ...
        VerifyCommitAncestor=options.VerifyCommitAncestor);
end
end

function valid=is_valid_historical_run_id(runId)
match=regexp(char(runId), ...
    ['^(?<base>[0-9]{8}_[0-9]{6}_stage_A3_[0-9a-f]{8})' ...
    '(?<collision>_[0-9]{3,})?$'], ...
    'names','once');
valid=~isempty(match);
if ~valid||isempty(match.collision), return; end
digits=string(match.collision(2:end));
number=str2double(digits);
valid=isfinite(number)&&number==fix(number)&&number>=2&& ...
    string(match.collision)==string(sprintf('_%03d',number));
end

function value=empty_audit()
value=struct("run_id","","status","","git_commit","", ...
    "evidence_inventory","","evidence_file_count",0, ...
    "zip_present",false,"zip_file_count",0,"zip_sha256","");
end
