
function partition = partition_stage_a_multiday_recursive_system(lin,reduced,options)
%PARTITION_STAGE_A_MULTIDAY_RECURSIVE_SYSTEM Build independent day chains.

arguments
    lin (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
end
contract = stage_a_multiday_linearization_contract(lin);
assert(isequal(reduced.linearization_identity,contract.identity), ...
    "stageAMultiday:solver:LinearizationIdentityMismatch", ...
    "formal multi-day partition and inequality elimination identities differ.");
assert(isequal(size(reduced.W),[contract.nx,contract.nx]) && ...
    numel(reduced.b_xi)==contract.nx, ...
    "stageAMultiday:solver:ReducedSystemShape", ...
    "formal multi-day reduced W or RHS has an invalid shape.");

Q = sparse(reduced.W(contract.q_global,contract.q_global));
bq = reduced.b_xi(contract.q_global);
R = sparse(lin.A(contract.y_duration,contract.q_global));
rdur = contract.r_eq(contract.y_duration);
assert_duration_structure(lin,contract,R);

crossDayCouplingNnz = 0;
for d = 1:contract.n_days
    dayPartition = build_day_partition(lin,reduced,contract,d);
    if d==1
        days = dayPartition;
    else
        days(d,1) = dayPartition;
    end
    assert_binding_structure(lin,contract,d);
    currentY = vertcat(contract.y_by_day_hour{d,:});
    otherX = zeros(0,1);
    for other = setdiff(1:contract.n_days,d)
        otherX = [otherX;vertcat(contract.x_by_day_hour{other,:})]; %#ok<AGROW>
    end
    crossDayCouplingNnz = crossDayCouplingNnz+nnz(lin.A(currentY,otherX));
end
if crossDayCouplingNnz~=0
    error("stageAMultiday:solver:CrossDaySocCoupling", ...
        "formal multi-day equality Jacobian contains %d cross-day hourly coefficient(s).", ...
        crossDayCouplingNnz);
end

[permutation,expected,expectedRhs,dayRanges] = build_recursive_audit( ...
    contract,Q,bq,R,rdur,days);
permuted = reduced.saddle(permutation,permutation);
permutedRhs = reduced.rhs(permutation);
matrixDifference = permuted-expected;
rhsDifference = permutedRhs-expectedRhs;
matrixRelative = norm(matrixDifference,"fro")/max(1,norm(permuted,"fro"));
rhsRelative = norm(rhsDifference,2)/max(1,norm(permutedRhs,2));
if matrixRelative>options.AssemblyTolerance || rhsRelative>options.AssemblyTolerance
    error("stageAMultiday:solver:RecursiveAssemblyMismatch", ...
        "Seven-day reduced-system audit failed: matrix relative error " + ...
        "%.17g, RHS relative error %.17g, tolerance %.17g. " + ...
        "No matrix modification was applied.", ...
        matrixRelative,rhsRelative,options.AssemblyTolerance);
end

inversePermutation = zeros(size(permutation));
inversePermutation(permutation) = (1:numel(permutation)).';
[permutationMap,assemblyMap] = build_permutation_evidence( ...
    lin.index,contract,permutation,inversePermutation,dayRanges,days);
identityOrder = (1:numel(permutation)).';
forwardInverseExact = isequal(inversePermutation(permutation),identityOrder);
inverseForwardExact = isequal(permutation(inversePermutation),identityOrder);
reconstructedCanonical = expected(inversePermutation,inversePermutation);
reconstructedCanonicalRhs = expectedRhs(inversePermutation);
canonicalMatrixDifference = reconstructedCanonical-reduced.saddle;
canonicalRhsDifference = reconstructedCanonicalRhs-reduced.rhs;
partition = struct();
partition.stage_id = contract.stage_id;
partition.linearization_identity = contract.identity;
partition.days = contract.days;
partition.hours = contract.hours;
partition.contract = contract;
partition.global = struct("Q",Q,"b_q",bq,"R",R, ...
    "r_duration",rdur,"dimension",16);
partition.day = days;
partition.daily_partitions = days;
partition.permutation = struct( ...
    "recursive_to_canonical_reduced",permutation, ...
    "canonical_reduced_to_recursive",inversePermutation, ...
    "forward_recursive_to_canonical",permutation, ...
    "inverse_canonical_to_recursive",inversePermutation, ...
    "dimension",numel(permutation), ...
    "is_bijection",isequal(sort(permutation),identityOrder), ...
    "is_nonidentity",any(permutation~=identityOrder), ...
    "forward_inverse_composition_exact",forwardInverseExact, ...
    "inverse_forward_composition_exact",inverseForwardExact, ...
    "day_ranges",dayRanges,"assembly_map",assemblyMap, ...
    "map",permutationMap);
partition.assembly_audit = struct( ...
    "permuted_reduced_matrix",permuted, ...
    "expected_recursive_matrix",expected, ...
    "matrix_difference_nnz",nnz(matrixDifference), ...
    "matrix_relative_error",matrixRelative, ...
    "permuted_rhs",permutedRhs, ...
    "expected_rhs",expectedRhs, ...
    "rhs_relative_error",rhsRelative, ...
    "reconstructed_canonical_matrix",reconstructedCanonical, ...
    "canonical_matrix_difference_nnz",nnz(canonicalMatrixDifference), ...
    "canonical_matrix_relative_error", ...
        norm(canonicalMatrixDifference,"fro")/ ...
        max(1,norm(reduced.saddle,"fro")), ...
    "reconstructed_canonical_rhs",reconstructedCanonicalRhs, ...
    "canonical_rhs_difference_nnz",nnz(canonicalRhsDifference), ...
    "canonical_rhs_relative_error", ...
        norm(canonicalRhsDifference,2)/max(1,norm(reduced.rhs,2)), ...
    "permutation_dimension",numel(permutation), ...
    "permutation_is_bijection",isequal(sort(permutation),identityOrder), ...
    "permutation_is_nonidentity",any(permutation~=identityOrder), ...
    "forward_inverse_composition_exact",forwardInverseExact, ...
    "inverse_forward_composition_exact",inverseForwardExact, ...
    "assembly_map",assemblyMap, ...
    "cross_day_hourly_equality_nnz",crossDayCouplingNnz, ...
    "no_cross_day_soc_coupling",crossDayCouplingNnz==0, ...
    "tolerance",options.AssemblyTolerance, ...
    "passed",matrixRelative<=options.AssemblyTolerance && ...
        rhsRelative<=options.AssemblyTolerance && ...
        nnz(canonicalMatrixDifference)==0 && ...
        nnz(canonicalRhsDifference)==0 && ...
        any(permutation~=identityOrder) && forwardInverseExact && ...
        inverseForwardExact && crossDayCouplingNnz==0);
end

function [map,assemblyMap] = build_permutation_evidence(index,contract, ...
        forward,inverse,dayRanges,days)
n = contract.nx+contract.neq;
recursiveIndex = (1:n).';
canonicalIndex = forward(:);
canonicalLocalIndex = canonicalIndex;
isEquality = canonicalIndex>contract.nx;
canonicalLocalIndex(isEquality) = ...
    canonicalLocalIndex(isEquality)-contract.nx;

runId = repmat(string(index.variable_index.run_id(1)),n,1);
spaceName = repmat("variable",n,1);
spaceName(isEquality) = "equality_multiplier";
semanticRole = strings(n,1);
objectScope = strings(n,1);
objectKey = strings(n,1);
dayId = zeros(n,1);
hour = zeros(n,1);
assetType = strings(n,1);
assetId = zeros(n,1);
canonicalObjectId = strings(n,1);
objectLocalIndex = zeros(n,1);

variables = index.variable_index;
equalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type)=="equality",:);
for row = 1:n
    local = canonicalLocalIndex(row);
    if ~isEquality(row)
        metadata = variables(variables.global_index_start==local,:);
        assert(height(metadata)==1, ...
            "stageAMultiday:solver:PermutationVariableMetadata", ...
            "Canonical primal index %d does not have exactly one metadata row.", ...
            local);
        dayId(row) = metadata.day;
        hour(row) = metadata.hour;
        assetType(row) = string(metadata.asset_type);
        assetId(row) = metadata.asset_id;
        canonicalObjectId(row) = string(metadata.variable_name);
        if metadata.day==0
            semanticRole(row) = "global_capacity";
        elseif metadata.hour==0
            semanticRole(row) = "daily_capacity_copy";
        else
            semanticRole(row) = "hourly_primal_variable";
        end
    else
        metadata = equalities(equalities.global_row==local,:);
        assert(height(metadata)==1, ...
            "stageAMultiday:solver:PermutationEqualityMetadata", ...
            "Canonical equality index %d does not have exactly one metadata row.", ...
            local);
        dayId(row) = metadata.day;
        hour(row) = metadata.hour;
        assetType(row) = string(metadata.asset_type);
        assetId(row) = metadata.asset_id;
        canonicalObjectId(row) = string(metadata.constraint_id);
        if metadata.day==0
            semanticRole(row) = "duration_multiplier";
        elseif metadata.hour==0
            semanticRole(row) = "daily_binding_multiplier";
        else
            semanticRole(row) = "hourly_equality_multiplier";
        end
    end

    if recursiveIndex(row)<=16
        objectScope(row) = "annual_core";
        objectKey(row) = "annual_core";
        objectLocalIndex(row) = recursiveIndex(row);
    else
        dayPosition = find(recursiveIndex(row)>=dayRanges.start_index & ...
            recursiveIndex(row)<=dayRanges.end_index,1,"first");
        assert(~isempty(dayPosition), ...
            "stageAMultiday:solver:PermutationObjectRange", ...
            "Recursive index %d is outside every assembly object.", ...
            recursiveIndex(row));
        objectScope(row) = "daily_chain";
        objectKey(row) = sprintf("day_%02d",dayRanges.day_id(dayPosition));
        objectLocalIndex(row) = recursiveIndex(row)- ...
            dayRanges.start_index(dayPosition)+1;
    end
end

forwardRecursiveToCanonical = canonicalIndex;
inverseSourceCanonicalIndex = recursiveIndex;
inverseCanonicalToRecursive = inverse(:);
inverseForMappedCanonical = inverse(canonicalIndex);
isIdentityPosition = recursiveIndex==canonicalIndex;
map = table(runId,recursiveIndex,canonicalIndex, ...
    forwardRecursiveToCanonical,inverseSourceCanonicalIndex, ...
    inverseCanonicalToRecursive, ...
    inverseForMappedCanonical,spaceName,canonicalLocalIndex, ...
    semanticRole,objectScope,objectKey, ...
    objectLocalIndex,dayId,hour,assetType,assetId,canonicalObjectId, ...
    isIdentityPosition, ...
    'VariableNames',{'run_id','recursive_solver_index', ...
    'canonical_reduced_index','forward_recursive_to_canonical', ...
    'inverse_source_canonical_index','inverse_canonical_to_recursive', ...
    'inverse_for_mapped_canonical', ...
    'space_name', ...
    'canonical_local_index','semantic_role','object_scope', ...
    'object_key','object_local_index','day','hour','asset_type', ...
    'asset_id','canonical_object_id','is_identity_position'});

objectScope = ["annual_core";repmat("daily_chain",contract.n_days,1)];
objectKey = ["annual_core";compose("day_%02d",contract.days(:))];
dayId = [0;contract.days(:)];
startIndex = [1;dayRanges.start_index];
endIndex = [16;dayRanges.end_index];
dimension = endIndex-startIndex+1;
hourlyChainDimension = [0;arrayfun(@(x)size(x.M,1),days(:))];
capacityCopyDimension = [14;repmat(14,contract.n_days,1)];
multiplierDimension = [2;repmat(14,contract.n_days,1)];
assemblyMap = table(objectScope,objectKey,dayId,startIndex,endIndex, ...
    dimension,hourlyChainDimension,capacityCopyDimension, ...
    multiplierDimension, ...
    'VariableNames',{'object_scope','object_key','day_id', ...
    'recursive_start_index','recursive_end_index','dimension', ...
    'hourly_chain_dimension','capacity_copy_or_global_q_dimension', ...
    'binding_or_duration_multiplier_dimension'});
assert(height(map)==n && numel(unique(map.recursive_solver_index))==n && ...
    numel(unique(map.canonical_reduced_index))==n && ...
    numel(unique(map.inverse_canonical_to_recursive))==n && ...
    all(map.inverse_for_mapped_canonical==map.recursive_solver_index) && ...
    any(~map.is_identity_position), ...
    "stageAMultiday:solver:PermutationEvidence", ...
    "formal multi-day recursive permutation evidence is not a nonidentity bijection.");
end

function day = build_day_partition(lin,reduced,contract,d)
nHours = contract.n_hours;
qDay = contract.q_day_by_day{d};
blocks = repmat(struct("day_id",0,"hour",0,"x_indices",[], ...
    "y_indices",[],"ineq_indices",[],"n_primal",0, ...
    "n_equalities",0,"dimension",0,"D",sparse(0,0), ...
    "E",sparse(0,0),"B",sparse(0,0),"r",[]),nHours,1);
for t = 1:nHours
    x = contract.x_by_day_hour{d,t};
    y = contract.y_by_day_hour{d,t};
    nxHour = numel(x);
    neqHour = numel(y);
    D = [reduced.W(x,x),sparse(lin.A(y,x).'); ...
        sparse(lin.A(y,x)),sparse(neqHour,neqHour)];
    B = [reduced.W(x,qDay);sparse(lin.A(y,qDay))];
    rhs = [reduced.b_xi(x);-contract.r_eq(y)];
    if t==1
        E = sparse(0,0);
    else
        previousX = contract.x_by_day_hour{d,t-1};
        previousY = contract.y_by_day_hour{d,t-1};
        predecessor = sparse(lin.A(y,previousX));
        E = [sparse(nxHour,numel(previousX)), ...
            sparse(nxHour,numel(previousY));predecessor, ...
            sparse(neqHour,numel(previousY))];
    end
    blocks(t).day_id = contract.days(d);
    blocks(t).hour = contract.hours(t);
    blocks(t).x_indices = x;
    blocks(t).y_indices = y;
    blocks(t).ineq_indices = contract.ineq_by_day_hour{d,t};
    blocks(t).n_primal = nxHour;
    blocks(t).n_equalities = neqHour;
    blocks(t).dimension = nxHour+neqHour;
    blocks(t).D = sparse(D);
    blocks(t).E = sparse(E);
    blocks(t).B = sparse(B);
    blocks(t).r = rhs;
end
[M,B,r,offsets] = stack_hour_chain(blocks);
day = struct();
day.stage_id = contract.stage_id;
day.linearization_identity = contract.identity;
day.day_id = contract.days(d);
day.hours = contract.hours;
day.hour = blocks;
day.M = M;
day.B = B;
day.r_v = r;
day.block_offsets = offsets;
day.C = sparse(reduced.W(qDay,qDay));
day.r_q_day = reduced.b_xi(qDay);
day.r_binding = contract.r_eq(contract.y_binding_by_day{d});
day.q_day_indices = qDay;
day.binding_indices = contract.y_binding_by_day{d};
day.hourly_chain_dimension = size(M,1);
end

function [M,B,r,offsets] = stack_hour_chain(blocks)
nHours = numel(blocks);
dimensions = reshape([blocks.dimension],[],1);
starts = cumsum([1;dimensions(1:end-1)]);
ends = cumsum(dimensions);
offsets = table(reshape([blocks.hour],[],1),starts,ends,dimensions, ...
    'VariableNames',{'hour','start_index','end_index','dimension'});
cells = cell(nHours,nHours);
for t = 1:nHours
    for u = 1:nHours
        cells{t,u} = sparse(dimensions(t),dimensions(u));
    end
    cells{t,t} = blocks(t).D;
end
for t = 2:nHours
    cells{t,t-1} = blocks(t).E;
    cells{t-1,t} = blocks(t).E.';
end
M = cell2mat(cells);
B = vertcat(blocks.B);
r = vertcat(blocks.r);
end

function assert_duration_structure(lin,contract,R)
expected = sparse([1,1,2,2],[11,13,12,14],[-2,1,-2,1],2,14);
assert(isequal(size(R),[2,14]) && nnz(R-expected)==0, ...
    "stageAMultiday:solver:DurationJacobian", ...
    "Duration equations must encode ES1-2*QS1 and ES2-2*QS2.");
other = setdiff((1:contract.nx).',contract.q_global,"stable");
assert(nnz(lin.A(contract.y_duration,other))==0, ...
    "stageAMultiday:solver:DurationJacobianSupport", ...
    "Duration rows may reference only the one global q block.");
end

function assert_binding_structure(lin,contract,d)
q = contract.q_global;
qd = contract.q_day_by_day{d};
rows = contract.y_binding_by_day{d};
assert(nnz(lin.A(rows,q)+speye(14))==0 && ...
    nnz(lin.A(rows,qd)-speye(14))==0, ...
    "stageAMultiday:solver:BindingJacobianSign", ...
    "Day %d bindings must be q_d-q=0.",contract.days(d));
other = setdiff((1:contract.nx).',[q;qd],"stable");
assert(nnz(lin.A(rows,other))==0, ...
    "stageAMultiday:solver:BindingJacobianSupport", ...
    "Day %d binding rows contain unsupported coefficients.",contract.days(d));
end

function [permutation,expected,rhs,ranges] = build_recursive_audit( ...
        contract,Q,bq,R,rdur,days)
nDays = contract.n_days;
dimensions = [16;arrayfun(@(x) 28+size(x.M,1),days)];
cells = cell(nDays+1,nDays+1);
for row = 1:nDays+1
    for column = 1:nDays+1
        cells{row,column} = sparse(dimensions(row),dimensions(column));
    end
end
cells{1,1} = [Q,R.';R,sparse(2,2)];
identity = speye(14);
rhsCells = cell(nDays+1,1);
rhsCells{1} = [bq;-rdur];
for d = 1:nDays
    nv = size(days(d).M,1);
    cells{d+1,d+1} = [days(d).C,identity,days(d).B.'; ...
        identity,sparse(14,14),sparse(14,nv); ...
        days(d).B,sparse(nv,14),days(d).M];
    globalToDay = [sparse(14,14),-identity,sparse(14,nv); ...
        sparse(2,28+nv)];
    cells{1,d+1} = globalToDay;
    cells{d+1,1} = globalToDay.';
    rhsCells{d+1} = [days(d).r_q_day;-days(d).r_binding;days(d).r_v];
end
expected = cell2mat(cells);
rhs = vertcat(rhsCells{:});
permutation = [contract.q_global;contract.nx+contract.y_duration];
ranges = zeros(nDays,3);
cursor = 17;
for d = 1:nDays
    start = cursor;
    local = [contract.q_day_by_day{d}; ...
        contract.nx+contract.y_binding_by_day{d}];
    for t = 1:contract.n_hours
        local = [local;contract.x_by_day_hour{d,t}; ...
            contract.nx+contract.y_by_day_hour{d,t}]; %#ok<AGROW>
    end
    permutation = [permutation;local]; %#ok<AGROW>
    cursor = cursor+numel(local);
    ranges(d,:) = [contract.days(d),start,cursor-1];
end
assert(numel(permutation)==contract.nx+contract.neq && ...
    isequal(sort(permutation),(1:contract.nx+contract.neq).'), ...
    "stageAMultiday:solver:ReducedPermutation", ...
    "formal multi-day reduced permutation is not bijective.");
ranges = array2table(ranges,'VariableNames', ...
    {'day_id','start_index','end_index'});
end
