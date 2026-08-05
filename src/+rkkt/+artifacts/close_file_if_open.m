function close_file_if_open(fileId)
%CLOSE_FILE_IF_OPEN Best-effort cleanup for a MATLAB file identifier.

    if ~isnumeric(fileId) || ~isscalar(fileId) || fileId < 0
        return;
    end
    try
        openName = fopen(fileId);
        if ischar(openName) && ~isempty(openName)
            fclose(fileId);
        end
    catch
        % Cleanup functions must not mask the original exception.
    end
end
