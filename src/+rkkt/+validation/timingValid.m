function value = timingValid(timing)
%TIMINGVALID Check that all timing measurements are finite and nonnegative.

values = struct2cell(timing);
value = all(cellfun(@(item)isnumeric(item) && isscalar(item) && ...
    isfinite(item) && item>=0,values));
end
