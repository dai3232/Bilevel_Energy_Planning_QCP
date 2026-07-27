function requireStruct(value,context)
%REQUIRESTRUCT Require a scalar structure without changing the input.

arguments
    value
    context (1,1) string = "value"
end

if ~isstruct(value) || ~isscalar(value)
    error("rkkt:contracts:ExpectedScalarStruct", ...
        "[%s] expected a 1x1 struct; actual class=%s, size=%s.", ...
        context,class(value),describeSize(value));
end
end
