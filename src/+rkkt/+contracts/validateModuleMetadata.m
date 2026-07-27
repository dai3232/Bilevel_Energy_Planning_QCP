function validateModuleMetadata(metadata)
%VALIDATEMODULEMETADATA Validate moduleResult.meta without modifying it.

context = "moduleResult.meta";
rkkt.contracts.requireFields(metadata, ...
    rkkt.contracts.requiredFields("moduleMetadata"),context, ...
    "AllowAdditionalFields",true);

textFields = ["interface_name";"production_function";"input_artifact"; ...
    "input_sha256";"git_commit";"stage_id";"matlab_version"; ...
    "generated_at";"contract_version"];
for k = 1:numel(textFields)
    name = textFields(k);
    rkkt.contracts.requireTextScalar(metadata.(name),context+"."+name);
end

interfaceName = string(metadata.interface_name);
if ~startsWith(interfaceName,"rkkt.")
    error("rkkt:contracts:InvalidInterfaceName", ...
        "[%s.interface_name] expected an rkkt.* public interface; actual=%s.", ...
        context,interfaceName);
end
sha256 = string(metadata.input_sha256);
if isempty(regexp(char(sha256),"^[0-9a-f]{64}$","once"))
    error("rkkt:contracts:InvalidSha256", ...
        "[%s.input_sha256] expected 64 lowercase hexadecimal characters; actual=%s.", ...
        context,sha256);
end
commit = string(metadata.git_commit);
if commit~="NOT_AVAILABLE" && ...
        isempty(regexp(char(commit),"^[0-9a-f]{40}$","once"))
    error("rkkt:contracts:InvalidGitCommit", ...
        "[%s.git_commit] expected 40 lowercase hexadecimal characters or NOT_AVAILABLE; actual=%s.", ...
        context,commit);
end
if string(metadata.contract_version)~=rkkt.contracts.version()
    error("rkkt:contracts:ContractVersionMismatch", ...
        "[%s.contract_version] expected=%s; actual=%s.",context, ...
        rkkt.contracts.version(),string(metadata.contract_version));
end

requireIntegerContext(metadata.day,context+".day",1);
requireIntegerContext(metadata.hour,context+".hour",1);
requireIntegerContext(metadata.iteration,context+".iteration",0);
requireIntegerContext(metadata.revision,context+".revision",0);
end

function requireIntegerContext(value,context,minimum)
if isempty(value)
    return
end
if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
        any(~isfinite(value),"all") || any(value<minimum,"all") || ...
        any(value~=fix(value),"all")
    error("rkkt:contracts:InvalidContextIndex", ...
        "[%s] expected an empty value or integer vector with entries >= %d; actual class=%s, size=%s.", ...
        context,minimum,class(value), ...
        describeSize(value));
end
end
