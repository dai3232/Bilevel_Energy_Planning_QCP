function value = withoutTiming(input)
%WITHOUTTIMING Remove the nondeterministic top-level timing field.

value = input;
if isstruct(value) && isscalar(value) && isfield(value,"timing")
    value = rmfield(value,"timing");
end
end
