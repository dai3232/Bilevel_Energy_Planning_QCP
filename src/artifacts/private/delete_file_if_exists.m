function delete_file_if_exists(filePath)
%DELETE_FILE_IF_EXISTS Best-effort removal of a function-owned temp file.

    try
        if isfile(filePath)
            delete(filePath);
        end
    catch
        % Cleanup functions must not mask the original exception.
    end
end
