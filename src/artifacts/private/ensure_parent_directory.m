function ensure_parent_directory(filePath)
%ENSURE_PARENT_DIRECTORY Create a file's parent directory if necessary.

    parent = fileparts(filePath);
    if isempty(parent) || isfolder(parent)
        return;
    end
    if exist(parent, 'file')
        error('stage0:artifacts:PathConflict', ...
            'A file exists where a directory is required: %s', parent);
    end
    [created, message] = mkdir(parent);
    if ~created
        error('stage0:artifacts:CreateDirectoryFailed', ...
            'Could not create directory %s: %s', parent, message);
    end
end
