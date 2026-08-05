function write_stage0_exception_junit(filePath, inventory, ...
        wallClockSeconds, exception)
%WRITE_STAGE0_EXCEPTION_JUNIT Persist well-formed JUnit for an interrupted run.
%
% This fallback is used only when the MATLAB JUnit plugin did not create an
% XML artifact.  Each inventory item is recorded as an infrastructure error;
% it is never represented as a passed test.

if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
    error('stage0:tests:InvalidJUnitPath', ...
        'JUnit path must be a text scalar.');
end
filePath = char(string(filePath));
if ~istable(inventory) || ~ismember('test_name', ...
        inventory.Properties.VariableNames)
    error('stage0:tests:InvalidJUnitInventory', ...
        'Inventory must be a table containing test_name.');
end
if isfile(filePath)
    fileInfo = dir(filePath);
    if fileInfo.bytes ~= 0
        error('stage0:tests:EvidenceArtifactExists', ...
            'Refusing to overwrite existing nonempty JUnit evidence: %s', ...
            filePath);
    end
end

errorText = xml_escape(string(exception.identifier) + ": " + ...
    string(exception.message));
testCount = height(inventory);
lines = strings(5 + 3 * testCount, 1);
lineIndex = 1;
lines(lineIndex) = "<?xml version=""1.0"" encoding=""UTF-8""?>";
lineIndex = lineIndex + 1;
lines(lineIndex) = sprintf([ ...
    '<testsuites name="stage_0" tests="%d" failures="0" errors="%d" ' ...
    'skipped="0" time="%.17g">'], ...
    testCount, testCount, wallClockSeconds);
lineIndex = lineIndex + 1;
lines(lineIndex) = sprintf([ ...
    '<testsuite name="fixed_stage_0_suite" tests="%d" failures="0" ' ...
    'errors="%d" skipped="0" time="%.17g">'], ...
    testCount, testCount, wallClockSeconds);
lineIndex = lineIndex + 1;
for rowIndex = 1:testCount
    testName = xml_escape(inventory.test_name(rowIndex));
    lines(lineIndex) = "<testcase classname=""stage_0"" name=""" + ...
        testName + """ time=""0"">";
    lineIndex = lineIndex + 1;
    lines(lineIndex) = "<error message=""Test execution incomplete"">" + ...
        errorText + "</error>";
    lineIndex = lineIndex + 1;
    lines(lineIndex) = "</testcase>";
    lineIndex = lineIndex + 1;
end
lines(lineIndex) = "</testsuite>";
lineIndex = lineIndex + 1;
lines(lineIndex) = "</testsuites>";

write_utf8_text(filePath, strjoin(lines, newline) + newline);
end

function value = xml_escape(value)
value = string(value);
value = replace(value, '&', '&amp;');
value = replace(value, '<', '&lt;');
value = replace(value, '>', '&gt;');
value = replace(value, '"', '&quot;');
value = replace(value, '''', '&apos;');
end

function write_utf8_text(filePath, textValue)
parentDirectory = fileparts(filePath);
if ~isempty(parentDirectory) && ~isfolder(parentDirectory)
    [created, message] = mkdir(parentDirectory);
    if ~created
        error('stage0:tests:EvidenceDirectoryCreateFailed', ...
            'Could not create evidence directory %s: %s', ...
            parentDirectory, message);
    end
end

[fileId, message] = fopen(filePath, 'wb', 'n', 'UTF-8');
if fileId < 0
    error('stage0:tests:EvidenceFileOpenFailed', ...
        'Could not open %s: %s', filePath, message);
end
closeGuard = onCleanup(@() close_file_safely(fileId));
bytes = unicode2native(char(textValue), 'UTF-8');
written = fwrite(fileId, bytes, 'uint8');
if written ~= numel(bytes)
    error('stage0:tests:EvidenceFileWriteFailed', ...
        'Incomplete write for %s.', filePath);
end
closeStatus = fclose(fileId);
clear closeGuard;
if closeStatus ~= 0
    error('stage0:tests:EvidenceFileCloseFailed', ...
        'Could not close %s after writing.', filePath);
end
end

function close_file_safely(fileId)
try
    openName = fopen(fileId);
    if ischar(openName) && ~isempty(openName)
        fclose(fileId);
    end
catch
end
end
