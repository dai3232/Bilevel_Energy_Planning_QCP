function target = build_stage_b2c_global_physical_core_base(lin,partition)
%BUILD_STAGE_B2C_GLOBAL_PHYSICAL_CORE_BASE Rebuild the physical 16-D base.
%
% The canonical global block is small, but its entries inherit products and
% divisions from inequality elimination.  This routine rebuilds that block
% directly from H/A/G and the current residuals while retaining a binary64
% high/low pair for every entry.  It changes neither the model nor the
% elimination equations.

arguments
    lin (1,1) struct
    partition (1,1) struct
end

contract = partition.contract;
q = contract.q_global(:);
yDuration = contract.y_duration(:);
assert(numel(q)==14 && numel(yDuration)==2 && ...
    isequal(partition.global.canonical_reduced_indices(:), ...
        [q;contract.nx+yDuration]), ...
    "stageB2C:globalPhysicalCore:Contract", ...
    "The global physical core does not match [14 capacity; 2 duration] order.");

gGlobal = sparse(lin.G(:,q));
touchingRows = find(any(gGlobal,2));
g = gGlobal(touchingRows,:);
l = contract.l(touchingRows);
z = contract.z(touchingRows);
rIneq = contract.r_ineq(touchingRows);
rComp = contract.r_comp(touchingRows);

[thetaHigh,thetaLow] = divide_pair_by_double(z,zeros(size(z)),l);
[zrHigh,zrLow] = two_product(z,rIneq);
[phiNumeratorHigh,phiNumeratorLow] = add_pair( ...
    rComp,zeros(size(rComp)),-zrHigh,-zrLow);
[phiHigh,phiLow] = divide_pair_by_double( ...
    phiNumeratorHigh,phiNumeratorLow,l);

nq = numel(q);
matrixHigh = zeros(nq+numel(yDuration));
matrixLow = zeros(size(matrixHigh));
[hRow,hColumn,hValue] = find(sparse(lin.H(q,q)));
for k = 1:numel(hValue)
    [matrixHigh(hRow(k),hColumn(k)),matrixLow(hRow(k),hColumn(k))] = ...
        add_pair(matrixHigh(hRow(k),hColumn(k)), ...
            matrixLow(hRow(k),hColumn(k)),hValue(k),0);
end

[gRow,gColumn,gValue] = find(g);
for localRow = 1:numel(touchingRows)
    positions = find(gRow==localRow);
    columns = gColumn(positions);
    values = gValue(positions);
    for left = 1:numel(positions)
        for right = 1:numel(positions)
            [coefficientHigh,coefficientLow] = ...
                two_product(values(left),values(right));
            [termHigh,termLow] = multiply_pair( ...
                thetaHigh(localRow),thetaLow(localRow), ...
                coefficientHigh,coefficientLow);
            row = columns(left);
            column = columns(right);
            [matrixHigh(row,column),matrixLow(row,column)] = ...
                add_pair(matrixHigh(row,column),matrixLow(row,column), ...
                    termHigh,termLow);
        end
    end
end

aDuration = full(sparse(lin.A(yDuration,q)));
matrixHigh(1:nq,nq+(1:numel(yDuration))) = aDuration.';
matrixHigh(nq+(1:numel(yDuration)),1:nq) = aDuration;

rhsHigh = zeros(nq+numel(yDuration),1);
rhsLow = zeros(size(rhsHigh));
rhsHigh(1:nq) = -contract.r_dual(q);
for k = 1:numel(gValue)
    row = gRow(k);
    column = gColumn(k);
    [termHigh,termLow] = multiply_pair( ...
        gValue(k),0,phiHigh(row),phiLow(row));
    [rhsHigh(column),rhsLow(column)] = add_pair( ...
        rhsHigh(column),rhsLow(column),termHigh,termLow);
end
rhsHigh(nq+(1:numel(yDuration))) = -contract.r_eq(yDuration);

[matrixHigh,matrixLow] = normalize_pair(matrixHigh,matrixLow);
[rhsHigh,rhsLow] = normalize_pair(rhsHigh,rhsLow);
matrixRounded = matrixHigh+matrixLow;
rhsRounded = rhsHigh+rhsLow;
canonicalMatrix = full(partition.global.matrix);
canonicalRhs = full(partition.global.rhs);
target = struct( ...
    "stage_id","stage_B","milestone_id","B-2C", ...
    "linearization_identity",lin.identity,"dimension",16, ...
    "matrix_high",matrixHigh,"matrix_low",matrixLow, ...
    "rhs_high",rhsHigh,"rhs_low",rhsLow, ...
    "matrix",sparse(matrixRounded),"rhs",rhsRounded, ...
    "theta_high",thetaHigh,"theta_low",thetaLow, ...
    "phi_high",phiHigh,"phi_low",phiLow, ...
    "touching_inequality_rows",touchingRows, ...
    "canonical_matrix_relative_difference", ...
        norm(matrixRounded-canonicalMatrix,"fro")/ ...
            max(1,norm(canonicalMatrix,"fro")), ...
    "canonical_rhs_relative_difference", ...
        norm(rhsRounded-canonicalRhs,2)/max(1,norm(canonicalRhs,2)), ...
    "symmetry_relative", ...
        norm(matrixRounded-matrixRounded.',"fro")/ ...
            max(1,norm(matrixRounded,"fro")), ...
    "regularization_used",false,"model_changed",false);
end

function [quotientHigh,quotientLow] = divide_pair_by_double( ...
        numeratorHigh,numeratorLow,denominator)
assert(all(isfinite(denominator)) && all(denominator~=0), ...
    "stageB2C:globalPhysicalCore:Division", ...
    "A global physical-core denominator is zero or nonfinite.");
quotientHigh = numeratorHigh./denominator;
quotientLow = zeros(size(quotientHigh));
for pass = 1:2
    [productHigh,productLow] = multiply_pair( ...
        denominator,zeros(size(denominator)),quotientHigh,quotientLow);
    [remainderHigh,remainderLow] = add_pair( ...
        numeratorHigh,numeratorLow,-productHigh,-productLow);
    correction = (remainderHigh+remainderLow)./denominator;
    [quotientHigh,quotientLow] = add_pair( ...
        quotientHigh,quotientLow,correction,zeros(size(correction)));
end
end

function [productHigh,productLow] = multiply_pair( ...
        leftHigh,leftLow,rightHigh,rightLow)
[firstHigh,firstLow] = two_product(leftHigh,rightHigh);
[secondHigh,secondLow] = two_product(leftHigh,rightLow);
[thirdHigh,thirdLow] = two_product(leftLow,rightHigh);
[fourthHigh,fourthLow] = two_product(leftLow,rightLow);
[productHigh,productLow] = add_pair( ...
    firstHigh,firstLow,secondHigh,secondLow);
[productHigh,productLow] = add_pair( ...
    productHigh,productLow,thirdHigh,thirdLow);
[productHigh,productLow] = add_pair( ...
    productHigh,productLow,fourthHigh,fourthLow);
end

function [high,low] = add_pair(aHigh,aLow,bHigh,bLow)
[sumHigh,sumError] = two_sum(aHigh,bHigh);
[lowHigh,lowError] = two_sum(aLow,bLow);
[sumError,lowHighCarry] = two_sum(sumError,lowHigh);
[sumHigh,sumCarry] = two_sum(sumHigh,sumError);
low = sumCarry+lowHighCarry+lowError;
[high,low] = two_sum(sumHigh,low);
end

function [high,low] = normalize_pair(high,low)
[high,low] = two_sum(high,low);
end

function [product,errorValue] = two_product(left,right)
splitter = 134217729;
product = left.*right;
leftSplit = splitter.*left;
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
