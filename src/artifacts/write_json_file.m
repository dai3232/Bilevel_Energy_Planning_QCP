function write_json_file(filePath, value)
%WRITE_JSON_FILE Write pretty UTF-8 JSON and replace the target atomically.

    filePath = validate_path(filePath);
    ensure_parent_directory(filePath);

    try
        jsonText = jsonencode(value, 'PrettyPrint', true);
    catch exception
        error('stage0:artifacts:JsonEncodeFailed', ...
            'Could not encode JSON for %s: %s', filePath, exception.message);
    end

    parent = fileparts(filePath);
    temporaryPath = [tempname(parent), '.json.tmp'];
    cleanupGuard = onCleanup(@() delete_file_if_exists(temporaryPath));

    [fileId, message] = fopen(temporaryPath, 'wb', 'n', 'UTF-8');
    if fileId < 0
        error('stage0:artifacts:JsonOpenFailed', ...
            'Could not open temporary JSON file for %s: %s', filePath, message);
    end
    closeGuard = onCleanup(@() close_file_if_open(fileId));
    count = fwrite(fileId, unicode2native([jsonText, newline], 'UTF-8'), 'uint8');
    expectedCount = numel(unicode2native([jsonText, newline], 'UTF-8'));
    if count ~= expectedCount
        error('stage0:artifacts:JsonWriteFailed', ...
            'Incomplete JSON write for %s.', filePath);
    end
    closeStatus = fclose(fileId);
    clear closeGuard;
    if closeStatus ~= 0
        error('stage0:artifacts:JsonCloseFailed', ...
            'Could not close temporary JSON file for %s.', filePath);
    end

    [moved, moveMessage] = movefile(temporaryPath, filePath, 'f');
    if ~moved
        error('stage0:artifacts:JsonMoveFailed', ...
            'Could not finalize JSON file %s: %s', filePath, moveMessage);
    end
    clear cleanupGuard;
end

function filePath = validate_path(filePath)
    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
        error('stage0:artifacts:InvalidPath', 'File path must be a text scalar.');
    end
    filePath = char(string(filePath));
    if isempty(filePath)
        error('stage0:artifacts:InvalidPath', 'File path must not be empty.');
    end
end
