function scan = scan_stage_b2c_initial_day_pivots(dayBlocks)
%SCAN_STAGE_B2C_INITIAL_DAY_PIVOTS Inspect sparse LDL pivots without solve.
%
% Numerical pivots that would trip the current production gate are
% recorded and scanning continues.  No regularization, pseudoinverse,
% direction solve, or replacement threshold is used.

arguments
    dayBlocks (:,1) struct
end

count = numel(dayBlocks);
day = zeros(count,1);
dimension = zeros(count,1);
matrixNnz = zeros(count,1);
structuralRank = zeros(count,1);
symmetryRelative = zeros(count,1);
factorWarningId = strings(count,1);
factorWarningMessage = strings(count,1);
minimumPivot = nan(count,1);
maximumPivot = nan(count,1);
pivotTolerance = nan(count,1);
numericalZeroCount = zeros(count,1);
inertiaPositive = zeros(count,1);
inertiaNegative = zeros(count,1);
inertiaZero = zeros(count,1);
pivotDynamicRange = nan(count,1);
factorSeconds = nan(count,1);
wouldTrigger = false(count,1);
status = strings(count,1);

for position = 1:count
    matrix = sparse(dayBlocks(position).matrix);
    n = size(matrix,1);
    day(position) = dayBlocks(position).day_id;
    dimension(position) = n;
    matrixNnz(position) = nnz(matrix);
    structuralRank(position) = sprank(matrix);
    symmetryRelative(position) = ...
        norm(matrix-matrix.',"fro")/max(1,norm(matrix,"fro"));
    if structuralRank(position)<n
        status(position) = "STRUCTURAL_RANK_DEFICIENT";
        continue
    end

    lastwarn("");
    timer = tic;
    try
        [~,D,~,~] = ldl(matrix,0.5,"vector");
        factorSeconds(position) = toc(timer);
    catch cause
        factorSeconds(position) = toc(timer);
        factorWarningId(position) = string(cause.identifier);
        factorWarningMessage(position) = string(cause.message);
        status(position) = "FACTORIZATION_FAILED";
        continue
    end
    [warningMessage,warningId] = lastwarn;
    factorWarningId(position) = string(warningId);
    factorWarningMessage(position) = string(warningMessage);

    pivots = block_pivot_eigenvalues(D);
    absolutePivots = abs(pivots);
    minimumPivot(position) = min(absolutePivots);
    maximumPivot(position) = max(absolutePivots);
    pivotTolerance(position) = n*eps(max(1,maximumPivot(position)));
    numericalZeroCount(position) = nnz( ...
        absolutePivots<=pivotTolerance(position));
    inertiaPositive(position) = nnz(pivots>pivotTolerance(position));
    inertiaNegative(position) = nnz(pivots<-pivotTolerance(position));
    inertiaZero(position) = numericalZeroCount(position);
    pivotDynamicRange(position) = maximumPivot(position)/minimumPivot(position);
    wouldTrigger(position) = numericalZeroCount(position)>0;

    if strlength(factorWarningId(position))>0 || ...
            strlength(factorWarningMessage(position))>0
        status(position) = "FACTOR_WARNING_RECORDED";
    elseif wouldTrigger(position)
        status(position) = "NUMERICAL_WEAK_PIVOT_RECORDED";
    else
        status(position) = "PASS";
    end
end

scan = table(day,dimension,matrixNnz,structuralRank, ...
    symmetryRelative,factorWarningId,factorWarningMessage, ...
    minimumPivot,maximumPivot,pivotTolerance,numericalZeroCount, ...
    inertiaPositive,inertiaNegative,inertiaZero,pivotDynamicRange, ...
    factorSeconds,wouldTrigger,status, ...
    'VariableNames',{'day','dimension','nnz','structural_rank', ...
    'symmetry_relative','factor_warning_id','factor_warning_message', ...
    'minimum_absolute_pivot','maximum_absolute_pivot', ...
    'pivot_reference_tolerance','numerical_zero_count', ...
    'inertia_positive','inertia_negative','inertia_zero', ...
    'pivot_dynamic_range','factor_seconds', ...
    'would_trigger_current_gate','status'});
end

function values = block_pivot_eigenvalues(D)
n = size(D,1);
values = zeros(n,1);
cursor = 1;
row = 1;
while row<=n
    if row<n && D(row+1,row)~=0
        values(cursor:cursor+1) = eig(full(D(row:row+1,row:row+1)));
        cursor = cursor+2;
        row = row+2;
    else
        values(cursor) = D(row,row);
        cursor = cursor+1;
        row = row+1;
    end
end
values = values(1:cursor-1);
end
