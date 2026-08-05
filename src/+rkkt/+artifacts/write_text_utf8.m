function write_text_utf8(filePath, textValue)
%WRITE_TEXT_UTF8 Write a text scalar as UTF-8 bytes.

    rkkt.artifacts.ensure_parent_directory(filePath);
    [fileId, message] = fopen(filePath, 'wb');
    if fileId < 0
        error('stage0:artifacts:TextOpenFailed', ...
            'Could not open text file %s: %s', filePath, message);
    end
    closeGuard = onCleanup(@() rkkt.artifacts.close_file_if_open(fileId));
    bytes = unicode2native(char(string(textValue)), 'UTF-8');
    if fwrite(fileId, bytes, 'uint8') ~= numel(bytes)
        error('stage0:artifacts:TextWriteFailed', ...
            'Incomplete text write for %s.', filePath);
    end
    closeStatus = fclose(fileId);
    clear closeGuard;
    if closeStatus ~= 0
        error('stage0:artifacts:TextCloseFailed', ...
            'Could not close text file %s.', filePath);
    end
end
