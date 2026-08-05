function [digest,normalized] = ...
        compute_stage_a4_checkpoint_input_fingerprint(inputHashes)
%COMPUTE_STAGE_A4_CHECKPOINT_INPUT_FINGERPRINT Canonicalize input SHA256s.

assert(isstruct(inputHashes) && isscalar(inputHashes), ...
    "stageA4:checkpoint:InputHashesType", ...
    "metadata.input_hashes must be a scalar struct.");
names = sort(string(fieldnames(inputHashes)));
assert(~isempty(names), ...
    "stageA4:checkpoint:InputHashesEmpty", ...
    "metadata.input_hashes must contain at least one controlled input.");

normalized = struct();
lines = strings(numel(names),1);
for k = 1:numel(names)
    name = names(k);
    value = lower(strip(text_scalar(inputHashes.(name), ...
        "metadata.input_hashes."+name)));
    assert(is_sha256(value), ...
        "stageA4:checkpoint:InputHashValue", ...
        "Input hash %s must be a 64-character SHA256 value.",name);
    normalized.(char(name)) = char(value);
    lines(k) = name+"="+value;
end
document = join(lines,newline);
bytes = unicode2native(char(document),"UTF-8");
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
messageDigest.update(typecast(uint8(bytes(:)),"int8"));
digestBytes = mod(double(messageDigest.digest()),256);
digest = lower(join(compose("%02x",digestBytes),""));
digest = reshape(digest,1,1);
end

function value = text_scalar(value,label)
assert(ischar(value) || (isstring(value) && isscalar(value)), ...
    "stageA4:checkpoint:InputHashText", ...
    "%s must be a text scalar.",label);
value = string(value);
assert(strlength(strip(value))>0, ...
    "stageA4:checkpoint:InputHashText", ...
    "%s must not be empty.",label);
end

function passed = is_sha256(value)
passed = ~isempty(regexp(char(value),"^[0-9a-f]{64}$","once"));
end
