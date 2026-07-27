function requireFields(value,names,context,options)
%REQUIREFIELDS Require structure fields without adding or reordering fields.

arguments
    value
    names string
    context (1,1) string = "value"
    options.AllowAdditionalFields (1,1) logical = true
end

rkkt.contracts.requireStruct(value,context);
if ~isvector(names) || any(ismissing(names)) || ...
        any(strlength(strtrim(names))==0)
    error("rkkt:contracts:InvalidFieldContract", ...
        "[%s] required field names must be a nonempty text vector.",context);
end
names = reshape(names,[],1);
if numel(unique(names,"stable"))~=numel(names)
    error("rkkt:contracts:InvalidFieldContract", ...
        "[%s] required field names must be unique.",context);
end

actual = string(fieldnames(value));
missingNames = names(~ismember(names,actual));
if ~isempty(missingNames)
    error("rkkt:contracts:MissingField", ...
        "[%s] missing required field(s): %s. Actual fields: %s.", ...
        context,strjoin(missingNames,", "),fieldList(actual));
end
if ~options.AllowAdditionalFields
    extraNames = actual(~ismember(actual,names));
    if ~isempty(extraNames)
        error("rkkt:contracts:UnexpectedField", ...
            "[%s] contains unexpected field(s): %s. Expected exactly: %s.", ...
            context,strjoin(extraNames,", "),fieldList(names));
    end
end
end

function value = fieldList(names)
if isempty(names)
    value = "<none>";
else
    value = strjoin(names,", ");
end
end
