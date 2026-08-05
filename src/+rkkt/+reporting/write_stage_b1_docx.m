function write_stage_b1_docx(outputPath,titleText,subtitleText,metadata,blocks)
%WRITE_STAGE_B1_DOCX Create a B-1 OOXML report with sanitized metadata.
%
% The established standard-business-brief layout engine is reused only in
% a temporary package. Every A4-specific package metadata token is replaced
% before the final non-overwriting B-1 document is published.

arguments
    outputPath (1,1) string
    titleText (1,1) string
    subtitleText (1,1) string
    metadata (1,1) struct
    blocks (:,1) struct
end
assert(~isfile(outputPath)&&~isfolder(outputPath), ...
    "stageB1:report:ArtifactExists","Refusing to overwrite %s.",outputPath);
parent = string(fileparts(outputPath));
if ~isfolder(parent)
    [created,message] = mkdir(parent);
    assert(created,"stageB1:report:Directory","%s",message);
end

temporaryDocx = string(tempname(parent))+".docx";
temporaryGuard = onCleanup(@()delete_if_exists(temporaryDocx));
rkkt.reporting.write_stage_a4_docx(temporaryDocx,titleText,subtitleText,metadata,blocks);

packageRoot = string(tempname(tempdir));
mkdir(packageRoot);
packageGuard = onCleanup(@()remove_tree(packageRoot));
unzip(temporaryDocx,packageRoot);
xmlFiles = [dir(fullfile(packageRoot,"**","*.xml")); ...
    dir(fullfile(packageRoot,"**","*.rels"))];
for k = 1:numel(xmlFiles)
    pathValue = fullfile(xmlFiles(k).folder,xmlFiles(k).name);
    textValue = string(fileread(pathValue));
    textValue = replace(textValue, ...
        ["stage_A4","Stage A4","STAGE A4"], ...
        ["stage_B_1","Stage B-1","STAGE B-1"]);
    write_utf8(pathValue,textValue);
end

files = dir(fullfile(packageRoot,"**","*"));
files = files(~[files.isdir]);
relative = strings(numel(files),1);
for k = 1:numel(files)
    absolute = string(fullfile(files(k).folder,files(k).name));
    relative(k) = erase(absolute,packageRoot+filesep);
end
zipPath = string(tempname(parent))+".zip";
zipGuard = onCleanup(@()delete_if_exists(zipPath));
zip(zipPath,cellstr(relative),packageRoot);
[moved,message] = movefile(zipPath,outputPath);
assert(moved,"stageB1:report:PackageWrite","%s",message);
clear zipGuard packageGuard temporaryGuard
end

function write_utf8(pathValue,textValue)
[fileId,message] = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0,"stageB1:report:Write","%s",message);
guard = onCleanup(@()close_file(fileId));
bytes = unicode2native(char(textValue),"UTF-8");
written = fwrite(fileId,bytes,"uint8");
assert(written==numel(bytes),"stageB1:report:Write", ...
    "Incomplete write: %s",pathValue);
status = fclose(fileId);
clear guard
assert(status==0,"stageB1:report:Write", ...
    "Could not close %s.",pathValue);
end

function close_file(fileId)
try
    if ischar(fopen(fileId))
        fclose(fileId);
    end
catch
end
end

function delete_if_exists(pathValue)
try
    if isfile(pathValue)
        delete(pathValue);
    end
catch
end
end

function remove_tree(pathValue)
try
    if isfolder(pathValue)
        rmdir(pathValue,"s");
    end
catch
end
end
