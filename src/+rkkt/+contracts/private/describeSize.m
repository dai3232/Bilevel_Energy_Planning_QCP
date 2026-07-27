function value = describeSize(input)
%DESCRIBESIZE Render an array size for contract error messages.

dimensions = size(input);
value = strjoin(string(dimensions),"x");
end
