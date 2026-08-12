function residual = compute_sparse_residual_double_double( ...
        matrix,solution,rhs)
%COMPUTE_SPARSE_RESIDUAL_DOUBLE_DOUBLE Rebuild rhs-M*x accurately.
% The operator, solution, and returned residual remain IEEE double.  Error-
% free product/sum transforms retain the low-order terms used only to form
% a residual-refinement right-hand side; no matrix or factor is changed.

arguments
    matrix {mustBeNumeric,mustBeReal}
    solution {mustBeNumeric,mustBeReal}
    rhs {mustBeNumeric,mustBeReal}
end
assert(size(matrix,1)==size(matrix,2) && ...
    size(matrix,1)==size(solution,1) && ...
    isequal(size(solution),size(rhs)), ...
    "stageB2C:extendedResidual:Shape", ...
    "Extended residual inputs have incompatible dimensions.");
assert(all(isfinite(nonzeros(matrix))) && ...
    all(isfinite(solution),"all") && all(isfinite(rhs),"all"), ...
    "stageB2C:extendedResidual:NonfiniteInput", ...
    "Extended residual inputs must be finite.");
[rowIndex,columnIndex,entry] = find(sparse(matrix));
residual = zeros(size(rhs));
for row = 1:size(matrix,1)
    positions = find(rowIndex==row);
    rowEntries=entry(positions);
    columns=columnIndex(positions);
    for rhsColumn=1:size(solution,2)
        residual(row,rhsColumn)=scaled_residual_entry( ...
            rowEntries,solution(columns,rhsColumn), ...
            rhs(row,rhsColumn));
    end
end
assert(all(isfinite(residual),"all"), ...
    "stageB2C:extendedResidual:Finite", ...
    "Extended residual reconstruction produced NaN or Inf.");
end

function value=scaled_residual_entry(entries,solution,rhsValue)
entries=full(entries(:));
solution=full(solution(:));
rhsValue=full(rhsValue);
active=entries~=0 & solution~=0;
entries=entries(active);
solution=solution(active);
[entryMantissa,entryExponent]=log2(entries);
[solutionMantissa,solutionExponent]=log2(solution);
productExponent=entryExponent+solutionExponent;
if rhsValue~=0
    [rhsMantissa,rhsExponent]=log2(rhsValue);
    scaleExponent=max([productExponent;rhsExponent]);
else
    rhsMantissa=0;
    rhsExponent=0;
    if isempty(productExponent)
        value=0;
        return
    end
    scaleExponent=max(productExponent);
end
sumHigh=0;
sumLow=0;
if rhsValue~=0
    [sumHigh,sumLow]=two_sum(0, ...
        pow2(rhsMantissa,rhsExponent-scaleExponent));
end
for k=1:numel(entries)
    [productHigh,productLow]=two_product_mantissa( ...
        entryMantissa(k),solutionMantissa(k));
    termHigh=-pow2(productHigh,productExponent(k)-scaleExponent);
    termLow=-pow2(productLow,productExponent(k)-scaleExponent);
    [candidate,additionError]=two_sum(sumHigh,termHigh);
    sumLow=sumLow+termLow+additionError;
    [sumHigh,carry]=two_sum(candidate,sumLow);
    sumLow=carry;
end
value=pow2(sumHigh+sumLow,scaleExponent);
end

function [product,errorValue] = two_product_mantissa(left,right)
splitter = 134217729;
product = left.*right;
leftSplit = splitter*left;
leftHigh = leftSplit-(leftSplit-left);
leftLow = left-leftHigh;
rightSplit = splitter.*right;
rightHigh = rightSplit-(rightSplit-right);
rightLow = right-rightHigh;
errorValue = ((leftHigh.*rightHigh-product)+ ...
    leftHigh.*rightLow+leftLow.*rightHigh)+leftLow.*rightLow;
end

function [sumValue,errorValue] = two_sum(left,right)
sumValue = left+right;
rightVirtual = sumValue-left;
errorValue = (left-(sumValue-rightVirtual))+(right-rightVirtual);
end
