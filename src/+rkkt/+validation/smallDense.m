function value = smallDense(matrixValue,maximumDimension)
%SMALLDENSE Convert only a bounded diagnostic matrix to dense storage.

arguments
    matrixValue
    maximumDimension (1,1) double {mustBeInteger,mustBePositive}
end

assert(all(size(matrixValue)<=maximumDimension), ...
    "rkkt:validation:SmallMatrixLimit", ...
    "Diagnostic dense conversion is limited to %d-by-%d.", ...
    maximumDimension,maximumDimension);
value = zeros(size(matrixValue));
[rows,columns,entries] = find(matrixValue);
value(sub2ind(size(value),rows,columns)) = entries;
end
