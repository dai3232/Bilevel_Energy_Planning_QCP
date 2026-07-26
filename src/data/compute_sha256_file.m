function sha256 = compute_sha256_file(filePath)
%COMPUTE_SHA256_FILE Compute the lowercase SHA-256 digest of a file.
%   SHA256 = COMPUTE_SHA256_FILE(FILEPATH) reads FILEPATH as bytes and
%   returns a 64-character lowercase string scalar.  The file is never
%   opened for writing.

arguments
    filePath (1, 1) string
end

if strlength(filePath) == 0
    error("stage0:EmptyFilePath", "The SHA-256 input path must not be empty.");
end
if ~isfile(filePath)
    error("stage0:InputFileMissing", "Cannot compute SHA-256; file does not exist: %s", filePath);
end

[fileId, message] = fopen(filePath, "rb");
if fileId < 0
    error("stage0:InputFileOpenFailed", "Cannot open input file '%s': %s", filePath, message);
end
closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>

messageDigest = java.security.MessageDigest.getInstance("SHA-256");
% Feed bounded chunks to Java.  Passing a whole large MAT file as one
% MATLAB-to-Java argument is not reliable in R2024a (the overload
% resolution can reject a non-scalar byte vector); chunking also keeps the
% historical-run snapshot memory bounded.
chunkSize = 1024*1024;
while true
    fileBytes = fread(fileId, chunkSize, "*uint8");
    if isempty(fileBytes)
        break
    end
    byteVector = typecast(fileBytes(:), "int8");
    messageDigest.update(byteVector, 0, int32(numel(byteVector)));
end
digestBytes = mod(double(messageDigest.digest()), 256);
sha256 = lower(join(compose("%02x", digestBytes), ""));
sha256 = reshape(sha256, 1, 1);

if strlength(sha256) ~= 64
    error("stage0:SHA256InternalError", "SHA-256 digest did not contain 64 hexadecimal characters.");
end
end
