function requireTextScalar(value,context,options)
%REQUIRETEXTSCALAR Require scalar char/string text without normalization.

arguments
    value
    context (1,1) string = "value"
    options.AllowEmpty (1,1) logical = false
end

validType = ischar(value) || (isstring(value) && isscalar(value));
if ~validType
    error("rkkt:contracts:ExpectedTextScalar", ...
        "[%s] expected a text scalar; actual class=%s, size=%s.", ...
        context,class(value),describeSize(value));
end
textValue = string(value);
if ismissing(textValue) || (~options.AllowEmpty && ...
        strlength(strtrim(textValue))==0)
    error("rkkt:contracts:EmptyText", ...
        "[%s] expected nonempty text; actual value is empty or missing.",context);
end
end
