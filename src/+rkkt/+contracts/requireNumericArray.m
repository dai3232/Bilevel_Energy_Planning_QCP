function requireNumericArray(value,context,options)
%REQUIRENUMERICARRAY Require numeric properties without changing the array.
%   ExpectedSize is exact when supplied. SparseMode is "either", "sparse",
%   or "full".

arguments
    value
    context (1,1) string = "value"
    options.ExpectedSize (1,:) double = double.empty(1,0)
    options.RequireFinite (1,1) logical = true
    options.RequireReal (1,1) logical = true
    options.SparseMode (1,1) string = "either"
end

if ~isnumeric(value)
    error("rkkt:contracts:ExpectedNumeric", ...
        "[%s] expected a numeric array; actual class=%s, size=%s.", ...
        context,class(value),describeSize(value));
end
if ~isempty(options.ExpectedSize)
    expected = double(options.ExpectedSize);
    if any(~isfinite(expected) | expected<0 | expected~=fix(expected))
        error("rkkt:contracts:InvalidExpectedSize", ...
            "[%s] ExpectedSize must contain finite nonnegative integers.",context);
    end
    if ~isequal(size(value),expected)
        error("rkkt:contracts:UnexpectedSize", ...
            "[%s] expected size=%s; actual size=%s.",context, ...
            sizeText(expected),describeSize(value));
    end
end
if options.RequireReal && ~isreal(value)
    error("rkkt:contracts:ExpectedReal", ...
        "[%s] expected a real numeric array; actual value is complex.",context);
end
if options.RequireFinite && any(~isfinite(value),"all")
    error("rkkt:contracts:ExpectedFinite", ...
        "[%s] expected all numeric entries to be finite.",context);
end

mode = lower(options.SparseMode);
if ~ismember(mode,["either","sparse","full"])
    error("rkkt:contracts:InvalidSparseMode", ...
        "[%s] SparseMode must be either, sparse, or full; actual=%s.", ...
        context,options.SparseMode);
end
if mode=="sparse" && ~issparse(value)
    error("rkkt:contracts:ExpectedSparse", ...
        "[%s] expected a sparse numeric array; actual storage is full.",context);
elseif mode=="full" && issparse(value)
    error("rkkt:contracts:ExpectedFull", ...
        "[%s] expected a full numeric array; actual storage is sparse.",context);
end
end

function value = sizeText(dimensions)
value = strjoin(string(dimensions),"x");
end
