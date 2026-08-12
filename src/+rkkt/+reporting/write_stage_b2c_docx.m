function write_stage_b2c_docx(outputPath,titleText,subtitleText,metadata,blocks)
%WRITE_STAGE_B2C_DOCX Create a standard-business-brief/memo-masthead DOCX.

arguments
    outputPath (1,1) string
    titleText (1,1) string
    subtitleText (1,1) string
    metadata (1,1) struct
    blocks (:,1) struct
end
assert(~isfile(outputPath)&&~isfolder(outputPath), ...
    "stageB2C:report:ArtifactExists", ...
    "Refusing to overwrite %s.",outputPath);
parent=string(fileparts(outputPath));
if ~isfolder(parent)
    [created,message]=mkdir(parent);
    assert(created,"stageB2C:report:Directory","%s",message);
end
temporaryDocx=string(tempname(parent))+".docx";
temporaryGuard=onCleanup(@()delete_if_exists(temporaryDocx));
% The established Stage-A engine already encodes the project's selected
% standard_business_brief token map and memo_masthead header pattern.
rkkt.reporting.write_stage_a4_docx(temporaryDocx,titleText,subtitleText,metadata,blocks);
packageRoot=string(tempname(tempdir)); mkdir(packageRoot);
packageGuard=onCleanup(@()remove_tree(packageRoot));
unzip(temporaryDocx,packageRoot);
xmlFiles=[dir(fullfile(packageRoot,"**","*.xml")); ...
    dir(fullfile(packageRoot,"**","*.rels"))];
for k=1:numel(xmlFiles)
    pathValue=string(fullfile(xmlFiles(k).folder,xmlFiles(k).name));
    source=string(fileread(pathValue));
    source=replace(source,["stage_A4","Stage A4","STAGE A4"], ...
        ["stage_B_2C","Stage B-2C","STAGE B-2C"]);
    write_utf8(pathValue,source);
end
files=dir(fullfile(packageRoot,"**","*")); files=files(~[files.isdir]);
relative=strings(numel(files),1);
for k=1:numel(files)
    relative(k)=erase(string(fullfile(files(k).folder,files(k).name)), ...
        packageRoot+filesep);
end
zipPath=string(tempname(parent))+".zip";
zipGuard=onCleanup(@()delete_if_exists(zipPath));
zip(zipPath,cellstr(relative),packageRoot);
[moved,message]=movefile(zipPath,outputPath);
assert(moved,"stageB2C:report:PackageWrite","%s",message);
clear zipGuard packageGuard temporaryGuard
end

function write_utf8(pathValue,textValue)
[fileId,message]=fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0,"stageB2C:report:Write","%s",message);
guard=onCleanup(@()close_file(fileId));
bytes=unicode2native(char(textValue),"UTF-8");
assert(fwrite(fileId,bytes,"uint8")==numel(bytes), ...
    "stageB2C:report:Write","Incomplete XML write: %s",pathValue);
assert(fclose(fileId)==0,"stageB2C:report:Write", ...
    "Could not close XML file %s.",pathValue);
clear guard
end
function close_file(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end
function delete_if_exists(pathValue)
try
    if isfile(pathValue), delete(pathValue); end
catch
end
end
function remove_tree(pathValue)
try
    if isfolder(pathValue), rmdir(pathValue,"s"); end
catch
end
end
