function tests = test_stage_a3_historical_preflight
%TEST_STAGE_A3_HISTORICAL_PREFLIGHT Validate retry and ZIP evidence gates.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
originalPath=path; addpath(genpath(fullfile(root,"src")));
testCase.addTeardown(@()path(originalPath));
end

function testPassHistoricalDirectoryAccepted(testCase)
fixture=create_fixture(testCase,"PASS");
audit=rkkt.artifacts.verify_stage_a3_historical_run(fixture.root,fixture.run_id);
verifyEqual(testCase,audit.status,"PASS");
verifyEqual(testCase,audit.evidence_file_count,1);
verifyFalse(testCase,audit.zip_present);
end

function testFailRetryableHistoricalDirectoryAccepted(testCase)
fixture=create_fixture(testCase,"FAIL_RETRYABLE");
audit=rkkt.artifacts.verify_stage_a3_historical_run(fixture.root,fixture.run_id);
verifyEqual(testCase,audit.status,"FAIL_RETRYABLE");
verifyEqual(testCase,audit.evidence_file_count,1);
verifyFalse(testCase,isfolder(fullfile(fixture.run_root,"matrices")), ...
    "The non-PASS fixture deliberately has no PASS-only matrix artifacts.");
end

function testOtherDefinedNonPassStatesAccepted(testCase)
states=["BLOCKED_EXTERNAL","NEEDS_MODEL_DECISION"];
for k=1:numel(states)
    fixture=create_fixture(testCase,states(k));
    audit=rkkt.artifacts.verify_stage_a3_historical_run(fixture.root,fixture.run_id);
    verifyEqual(testCase,audit.status,states(k));
end
end

function testFailureAddendumInventoryAccepted(testCase)
fixture=create_fixture(testCase,"FAIL_RETRYABLE");
promote_to_failure_addendum(fixture);
audit=rkkt.artifacts.verify_stage_a3_historical_run(fixture.root,fixture.run_id);
verifyEqual(testCase,audit.status,"FAIL_RETRYABLE");
verifyEqual(testCase,audit.evidence_inventory, ...
    "acceptance/evidence_hashes_failure_addendum.csv");
verifyEqual(testCase,audit.evidence_file_count,2);
end

function testMatchingHistoricalDirectoryAndZipAccepted(testCase)
fixture=create_fixture(testCase,"PASS");
create_matching_zip(fixture);
audit=rkkt.artifacts.verify_stage_a3_historical_run(fixture.root,fixture.run_id);
verifyTrue(testCase,audit.zip_present);
verifyEqual(testCase,audit.zip_file_count,3);
verifyEqual(testCase,strlength(audit.zip_sha256),64);
end

function testCollisionSuffixDirectoryAndZipAccepted(testCase)
for suffix=["002","1000"]
    fixture=create_fixture(testCase,"PASS");
    fixture=add_collision_suffix(fixture,suffix);
    create_matching_zip(fixture);
    lines=["?? runs/"+fixture.run_id+"/"; ...
        "?? runs/"+fixture.run_id+".zip"];
    audits=rkkt.artifacts.verify_stage_a3_historical_preflight(fixture.root,lines);
    verifyEqual(testCase,numel(audits),1);
    verifyEqual(testCase,audits.run_id,fixture.run_id);
    verifyTrue(testCase,audits.zip_present);
    verifyEqual(testCase,audits.git_commit,fixture.commit);
end
end

function testInvalidCollisionSuffixRejected(testCase)
fixture=create_fixture(testCase,"PASS");
invalid=fixture.run_id+"_001";
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,invalid),"stageA3:gate:PriorA3RunId");
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_preflight( ...
    fixture.root,"?? runs/"+invalid+"/"), ...
    "stageA3:gate:UnknownUntracked");
end

function testResidualInitializingMarkerRejected(testCase)
fixture=create_fixture(testCase,"FAIL_RETRYABLE");
write_bytes(fullfile(fixture.run_root,".initializing"),uint8([]));
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id), ...
    "stageA3:gate:PriorA3InitializationIncomplete");
end

function testCorruptZipRejected(testCase)
fixture=create_fixture(testCase,"PASS");
write_bytes(fixture.zip_path,uint8('not a zip archive'));
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id),"stageA3:gate:PriorA3ZipUnreadable");
end

function testZipContentMismatchRejected(testCase)
fixture=create_fixture(testCase,"PASS");
staging=string(tempname(tempdir)); mkdir(staging);
testCase.addTeardown(@()remove_tree(staging));
copyfile(fixture.run_root,fullfile(staging,fixture.run_id));
write_bytes(fullfile(staging,fixture.run_id,"issues","record.txt"), ...
    uint8('different bytes'));
zip(fixture.zip_path,char(fixture.run_id),char(staging));
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id),"stageA3:gate:PriorA3ZipContentMismatch");
end

function testZipWrongTopLevelRejected(testCase)
fixture=create_fixture(testCase,"PASS");
staging=string(tempname(tempdir)); mkdir(staging);
testCase.addTeardown(@()remove_tree(staging));
wrong="wrong_stage_A3_top_level";
copyfile(fixture.run_root,fullfile(staging,wrong));
zip(fixture.zip_path,char(wrong),char(staging));
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id),"stageA3:gate:PriorA3ZipTopLevel");
end

function testZipExtraEmptyDirectoryRejected(testCase)
fixture=create_fixture(testCase,"PASS");
extra=fixture.run_id+"/extra_empty/";
create_zip_with_extra_entries(fixture,extra,true);
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id), ...
    "stageA3:gate:PriorA3ZipDirectorySetMismatch");
end

function testZipWindowsAliasesAndUnsafeEntriesRejected(testCase)
cases={ ...
    "issues/RECORD.txt",false,"stageA3:gate:PriorA3ZipWindowsAlias"; ...
    "issues/record.txt:stream",false,"stageA3:gate:PriorA3ZipUnsafeEntry"; ...
    "issues/trailing.",false,"stageA3:gate:PriorA3ZipUnsafeEntry"; ...
    "issues/trailing ",false,"stageA3:gate:PriorA3ZipUnsafeEntry"; ...
    "issues/CON.txt",false,"stageA3:gate:PriorA3ZipUnsafeEntry"; ...
    "issues\backslash.txt",false,"stageA3:gate:PriorA3ZipUnsafeEntry"; ...
    ["collision";"collision/child.txt"],[false;false], ...
        "stageA3:gate:PriorA3ZipWindowsAlias"};
for k=1:size(cases,1)
    fixture=create_fixture(testCase,"PASS");
    relative=string(cases{k,1});
    names=fixture.run_id+"/"+relative;
    create_zip_with_extra_entries(fixture,names,logical(cases{k,2}));
    verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
        fixture.root,fixture.run_id),string(cases{k,3}), ...
        "Unsafe ZIP case did not fail: "+strjoin(relative,", "));
end
end

function testIllegalTerminalStatusRejected(testCase)
fixture=create_fixture(testCase,"PASS");
manifest=jsondecode(fileread(fixture.manifest_path));
manifest.status='RUNNING'; rkkt.artifacts.write_json_file(fixture.manifest_path,manifest);
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id),"stageA3:gate:PriorA3Identity");
end

function testUntrackedClassifierAcceptsDirectoryAndZip(testCase)
fixture=create_fixture(testCase,"PASS"); create_matching_zip(fixture);
known="?? runs/known_stage_0_history/";
lines=["?? runs/"+fixture.run_id+"/"; ...
    "?? runs/"+fixture.run_id+".zip";known];
audits=rkkt.artifacts.verify_stage_a3_historical_preflight(fixture.root,lines, ...
    AllowedUntracked=known);
verifyEqual(testCase,numel(audits),1);
verifyEqual(testCase,audits.run_id,fixture.run_id);
verifyTrue(testCase,audits.zip_present);
end

function testUntrackedClassifierRejectsUnknownEntry(testCase)
fixture=create_fixture(testCase,"PASS");
lines=["?? runs/"+fixture.run_id+"/";"?? unexpected.txt"];
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_preflight( ...
    fixture.root,lines),"stageA3:gate:UnknownUntracked");
end

function testPassInventoryMustCoverEveryPersistedFile(testCase)
fixture=create_fixture(testCase,"PASS");
extra=fullfile(fixture.run_root,"diagnostics","unlisted.txt");
mkdir(fileparts(extra)); write_bytes(extra,uint8('unlisted'));
verifyError(testCase,@()rkkt.artifacts.verify_stage_a3_historical_run( ...
    fixture.root,fixture.run_id), ...
    "stageA3:gate:HistoricalEvidenceSetMismatch");
end

function fixture=create_fixture(testCase,status)
root=string(tempname(tempdir)); mkdir(root);
testCase.addTeardown(@()remove_tree(root));
run_git(root,"init");
run_git(root,'config user.email "stage-a3-test@example.invalid"');
run_git(root,'config user.name "Stage A3 Test"');
write_bytes(fullfile(root,"seed.txt"),uint8('tracked seed'));
run_git(root,"add seed.txt");
run_git(root,'commit -m "test fixture"');
[~,commitText]=run_git(root,"rev-parse HEAD");
commit=lower(strip(string(commitText)));
runId="20260721_120000_stage_A3_"+extractBefore(commit,9);
runsRoot=fullfile(root,"runs"); mkdir(runsRoot);
runRoot=fullfile(runsRoot,runId); mkdir(runRoot);
issuesDirectory=fullfile(runRoot,"issues"); mkdir(issuesDirectory);
recordPath=fullfile(issuesDirectory,"record.txt");
write_bytes(recordPath,uint8(char("status="+status)));
info=dir(recordPath);
inventory=table("issues/record.txt","issues",double(info.bytes), ...
    lower(string(rkkt.data.compute_sha256_file(recordPath))),"PASS", ...
    "2026-07-21T12:00:00+08:00",'VariableNames', ...
    {'relative_path','scope','bytes','sha256','status','checked_at'});
acceptanceDirectory=fullfile(runRoot,"acceptance"); mkdir(acceptanceDirectory);
inventoryPath=fullfile(acceptanceDirectory,"evidence_hashes.csv");
rkkt.artifacts.write_table_csv_17g(inventoryPath,inventory);
manifest=struct("run_id",char(runId),"stage_id","stage_A3", ...
    "status",char(status),"git_commit",char(commit), ...
    "evidence_hashes","acceptance/evidence_hashes.csv", ...
    "evidence_hashes_sha256",char(rkkt.data.compute_sha256_file(inventoryPath)));
manifestPath=fullfile(runRoot,"run_manifest.json");
rkkt.artifacts.write_json_file(manifestPath,manifest);
fixture=struct("root",root,"runs_root",string(runsRoot), ...
    "run_id",runId,"run_root",string(runRoot), ...
    "manifest_path",string(manifestPath), ...
    "zip_path",string(fullfile(runsRoot,runId+".zip")), ...
    "commit",commit);
end

function create_matching_zip(fixture)
zip(fixture.zip_path,char(fixture.run_id),char(fixture.runs_root));
end

function fixture=add_collision_suffix(fixture,suffix)
newId=fixture.run_id+"_"+string(suffix);
newRoot=fullfile(fixture.runs_root,newId);
[moved,message]=movefile(fixture.run_root,newRoot); assert(moved,message);
newManifest=fullfile(newRoot,"run_manifest.json");
manifest=jsondecode(fileread(newManifest)); manifest.run_id=char(newId);
rkkt.artifacts.write_json_file(newManifest,manifest);
fixture.run_id=newId;
fixture.run_root=string(newRoot);
fixture.manifest_path=string(newManifest);
fixture.zip_path=string(fullfile(fixture.runs_root,newId+".zip"));
end

function create_zip_with_extra_entries(fixture,extraNames,extraDirectories)
extraNames=string(extraNames(:));
extraDirectories=logical(extraDirectories(:));
assert(numel(extraNames)==numel(extraDirectories));
fileStream=javaObject('java.io.FileOutputStream',char(fixture.zip_path));
zipStream=javaObject('java.util.zip.ZipOutputStream',fileStream);
guard=onCleanup(@()close_zip_streams(zipStream,fileStream));
write_zip_entry(zipStream,fixture.run_id+"/",uint8([]),true);

listing=dir(fullfile(fixture.run_root,"**","*"));
rootLength=strlength(fixture.run_root)+1;
directories=strings(0,1); files=strings(0,1);
for k=1:numel(listing)
    if ismember(string(listing(k).name),[".",".."]), continue; end
    absolute=string(fullfile(listing(k).folder,listing(k).name));
    relative=replace(extractAfter(absolute,rootLength),'\','/');
    if listing(k).isdir
        directories(end+1,1)=relative; %#ok<AGROW>
    else
        files(end+1,1)=relative; %#ok<AGROW>
    end
end
for relative=sort(unique(directories)).'
    write_zip_entry(zipStream,fixture.run_id+"/"+relative+"/", ...
        uint8([]),true);
end
for relative=sort(unique(files)).'
    bytes=read_bytes(fullfile(fixture.run_root, ...
        strrep(relative,'/',filesep)));
    write_zip_entry(zipStream,fixture.run_id+"/"+relative,bytes,false);
end
for k=1:numel(extraNames)
    write_zip_entry(zipStream,extraNames(k),uint8([]),extraDirectories(k));
end
zipStream.close(); clear guard;
end

function write_zip_entry(zipStream,name,bytes,isDirectory)
name=string(name);
if isDirectory&&~endsWith(name,"/"), name=name+"/"; end
entry=javaObject('java.util.zip.ZipEntry',char(name));
zipStream.putNextEntry(entry);
if ~isDirectory&&~isempty(bytes)
    signed=typecast(uint8(bytes(:)),'int8');
    zipStream.write(signed,0,numel(signed));
end
zipStream.closeEntry();
end

function bytes=read_bytes(pathValue)
fileId=fopen(pathValue,'rb'); assert(fileId>=0);
guard=onCleanup(@()close_if_open(fileId));
bytes=fread(fileId,Inf,'*uint8'); fclose(fileId); clear guard;
end

function close_zip_streams(zipStream,fileStream)
try
    zipStream.close();
catch
end
try
    fileStream.close();
catch
end
end

function promote_to_failure_addendum(fixture)
relative=["acceptance/evidence_hashes.csv";"issues/record.txt"];
scope=["acceptance";"issues"];
bytes=zeros(2,1); hashes=strings(2,1);
for k=1:2
    pathValue=fullfile(fixture.run_root,strrep(relative(k),'/',filesep));
    info=dir(pathValue); bytes(k)=info.bytes;
    hashes(k)=lower(string(rkkt.data.compute_sha256_file(pathValue)));
end
inventory=table(relative,scope,bytes,hashes,repmat("PASS",2,1), ...
    repmat("2026-07-21T12:00:00+08:00",2,1),'VariableNames', ...
    {'relative_path','scope','bytes','sha256','status','checked_at'});
pathValue=fullfile(fixture.run_root,"acceptance", ...
    "evidence_hashes_failure_addendum.csv");
rkkt.artifacts.write_table_csv_17g(pathValue,inventory);
manifest=jsondecode(fileread(fixture.manifest_path));
manifest.evidence_hashes='acceptance/evidence_hashes_failure_addendum.csv';
manifest.evidence_hashes_sha256=char(rkkt.data.compute_sha256_file(pathValue));
rkkt.artifacts.write_json_file(fixture.manifest_path,manifest);
end

function [status,output]=run_git(root,arguments)
safe=replace(string(root),'\','/');
command='git -c safe.directory="'+safe+'" -C "'+string(root)+'" '+arguments;
[status,output]=system(char(command));
assert(status==0,"Git fixture command failed: %s",string(output));
end

function write_bytes(pathValue,bytes)
parent=fileparts(pathValue); if ~isfolder(parent), mkdir(parent); end
fileId=fopen(pathValue,'wb'); assert(fileId>=0);
guard=onCleanup(@()close_if_open(fileId));
fwrite(fileId,bytes,'uint8'); fclose(fileId); clear guard;
end

function close_if_open(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end

function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
