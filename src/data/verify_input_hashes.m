function [results, allMatch] = verify_input_hashes(projectRoot)
%VERIFY_INPUT_HASHES Compare controlled raw inputs with their manifest.
%   [RESULTS, ALLMATCH] = VERIFY_INPUT_HASHES(PROJECTROOT) reads
%   inputs/数据文件清单与SHA256.csv and verifies every listed file under
%   inputs/raw.  RESULTS is retained even when a file is missing or does
%   not match, so a caller can write truthful failure evidence.

if nargin < 1 || strlength(string(projectRoot)) == 0
    projectRoot = default_project_root();
else
    projectRoot = string(projectRoot);
end
projectRoot = reshape(projectRoot, 1, 1);

manifestPath = fullfile(projectRoot, "inputs", "数据文件清单与SHA256.csv");
rawDirectory = fullfile(projectRoot, "inputs", "raw");
if ~isfile(manifestPath)
    error("stage0:HashManifestMissing", "Input hash manifest does not exist: %s", manifestPath);
end
if ~isfolder(rawDirectory)
    error("stage0:RawInputDirectoryMissing", "Raw input directory does not exist: %s", rawDirectory);
end

manifest = readtable(manifestPath, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");
requiredColumns = ["文件名", "字节数", "SHA256"];
manifestColumns = string(manifest.Properties.VariableNames);
if ~all(ismember(requiredColumns, manifestColumns))
    missingColumns = requiredColumns(~ismember(requiredColumns, manifestColumns));
    error("stage0:InvalidHashManifest", ...
        "Hash manifest is missing required columns: %s", strjoin(missingColumns, ", "));
end

fileNames = strip(string(manifest.("文件名")));
expectedBytes = double(manifest.("字节数"));
expectedSHA256 = lower(strip(string(manifest.("SHA256"))));
fileNames = fileNames(:);
expectedBytes = expectedBytes(:);
expectedSHA256 = expectedSHA256(:);

if isempty(fileNames) || any(ismissing(fileNames) | strlength(fileNames) == 0)
    error("stage0:InvalidHashManifest", "Hash manifest contains an empty file name.");
end
if numel(unique(fileNames)) ~= numel(fileNames)
    error("stage0:DuplicateManifestFile", "Hash manifest contains duplicate file names.");
end
requiredFiles = ["基础参数.xlsx"; "输入数据.xlsx"];
for requiredIndex = 1:numel(requiredFiles)
    if nnz(fileNames == requiredFiles(requiredIndex)) ~= 1
        error("stage0:InvalidHashManifest", ...
            "Hash manifest must contain exactly one row for '%s'.", requiredFiles(requiredIndex));
    end
end
if any(~isfinite(expectedBytes) | expectedBytes < 0 | fix(expectedBytes) ~= expectedBytes)
    error("stage0:InvalidHashManifest", "Hash manifest contains an invalid byte count.");
end
for rowIndex = 1:numel(expectedSHA256)
    if isempty(regexp(char(expectedSHA256(rowIndex)), "^[0-9a-f]{64}$", "once")) %#ok<RGXP1>
        error("stage0:InvalidHashManifest", ...
            "Hash manifest contains an invalid SHA-256 value for '%s'.", fileNames(rowIndex));
    end
end

rowCount = numel(fileNames);
actualBytes = nan(rowCount, 1);
actualSHA256 = strings(rowCount, 1);
bytesMatch = false(rowCount, 1);
hashMatch = false(rowCount, 1);
status = repmat("MISSING", rowCount, 1);
filePath = strings(rowCount, 1);

for rowIndex = 1:rowCount
    [folderPart, baseName, extension] = fileparts(fileNames(rowIndex));
    if strlength(folderPart) ~= 0 || (baseName + extension) ~= fileNames(rowIndex)
        error("stage0:InvalidManifestPath", ...
            "Manifest file names must be leaf names under inputs/raw: %s", fileNames(rowIndex));
    end

    filePath(rowIndex) = fullfile(rawDirectory, fileNames(rowIndex));
    if ~isfile(filePath(rowIndex))
        continue;
    end

    fileInformation = dir(filePath(rowIndex));
    actualBytes(rowIndex) = double(fileInformation.bytes);
    actualSHA256(rowIndex) = compute_sha256_file(filePath(rowIndex));
    bytesMatch(rowIndex) = actualBytes(rowIndex) == expectedBytes(rowIndex);
    hashMatch(rowIndex) = actualSHA256(rowIndex) == expectedSHA256(rowIndex);
    if bytesMatch(rowIndex) && hashMatch(rowIndex)
        status(rowIndex) = "PASS";
    else
        status(rowIndex) = "MISMATCH";
    end
end

results = table(fileNames, expectedBytes, actualBytes, expectedSHA256, ...
    actualSHA256, bytesMatch, hashMatch, status, filePath, ...
    'VariableNames', cellstr(["fileName", "expectedBytes", "actualBytes", ...
    "expectedSHA256", "actualSHA256", "bytesMatch", "hashMatch", ...
    "status", "filePath"]));
allMatch = all(status == "PASS");
end

function projectRoot = default_project_root()
dataDirectory = fileparts(mfilename("fullpath"));
sourceDirectory = fileparts(dataDirectory);
projectRoot = string(fileparts(sourceDirectory));
end
