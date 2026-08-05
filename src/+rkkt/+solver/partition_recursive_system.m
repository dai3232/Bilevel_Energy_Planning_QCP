function partition = partition_recursive_system(lin, reduced, options)
%PARTITION_RECURSIVE_SYSTEM Extract D/E/B blocks from the shared W and b_xi.

arguments
    lin (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1.0e-12
end

contract = rkkt.solver.solver_linearization_contract(lin);
assert(isequal(reduced.linearization_identity, contract.identity), ...
    "stageA1:solver:LinearizationIdentityMismatch", ...
    "Recursive partition and linearization identities differ.");
assert(isequal(size(reduced.W), [contract.nx,contract.nx]) && ...
    numel(reduced.b_xi) == contract.nx, ...
    "stageA1:solver:ReducedSystemShape", ...
    "Reduced W or b_xi has an invalid shape.");

nHours = contract.n_hours;
hourBlocks = repmat(struct( ...
    "hour",0,"x_indices",[],"y_indices",[],"ineq_indices",[], ...
    "n_primal",0,"n_equalities",0,"dimension",0, ...
    "D",sparse(0,0),"E",sparse(0,0),"B",sparse(0,0),"r",[]), nHours,1);

for t = 1:nHours
    x = contract.x_by_hour{t};
    y = contract.y_by_hour{t};
    nxHour = numel(x);
    neqHour = numel(y);
    D = [reduced.W(x,x), sparse(lin.A(y,x).'); ...
         sparse(lin.A(y,x)), sparse(neqHour,neqHour)];
    B = [reduced.W(x,contract.q_day); sparse(lin.A(y,contract.q_day))];
    rhs = [reduced.b_xi(x); -contract.r_eq(y)];

    if t == 1
        E = sparse(0,0);
    else
        previousX = contract.x_by_hour{t-1};
        previousY = contract.y_by_hour{t-1};
        K = sparse(lin.A(y,previousX));
        E = [sparse(nxHour,numel(previousX)), sparse(nxHour,numel(previousY)); ...
             K, sparse(neqHour,numel(previousY))];
    end

    hourBlocks(t).hour = contract.hours(t);
    hourBlocks(t).x_indices = x;
    hourBlocks(t).y_indices = y;
    hourBlocks(t).ineq_indices = contract.ineq_by_hour{t};
    hourBlocks(t).n_primal = nxHour;
    hourBlocks(t).n_equalities = neqHour;
    hourBlocks(t).dimension = nxHour + neqHour;
    hourBlocks(t).D = sparse(D);
    hourBlocks(t).E = sparse(E);
    hourBlocks(t).B = sparse(B);
    hourBlocks(t).r = rhs;
end

[M,stackedB,stackedR,blockOffsets] = stack_hour_chain(hourBlocks);
Q = reduced.W(contract.q_global,contract.q_global);
bq = reduced.b_xi(contract.q_global);
R = sparse(lin.A(contract.y_duration,contract.q_global));
rdur = contract.r_eq(contract.y_duration);
C = reduced.W(contract.q_day,contract.q_day);
rq = reduced.b_xi(contract.q_day);
rbind = contract.r_eq(contract.y_binding);

assert_binding_and_duration_structure(lin,contract,R);

nq = numel(contract.q_global);
nrho = numel(contract.y_duration);
nqd = numel(contract.q_day);
npi = numel(contract.y_binding);
nv = size(M,1);
identityBinding = speye(nqd);
expected = [Q, R.', sparse(nq,nqd), -identityBinding, sparse(nq,nv); ...
            R, sparse(nrho,nrho), sparse(nrho,nqd), sparse(nrho,npi), sparse(nrho,nv); ...
            sparse(nqd,nq), sparse(nqd,nrho), C, identityBinding, stackedB.'; ...
            -identityBinding, sparse(npi,nrho), identityBinding, sparse(npi,npi), sparse(npi,nv); ...
            sparse(nv,nq), sparse(nv,nrho), stackedB, sparse(nv,npi), M];
expectedRhs = [bq; -rdur; rq; -rbind; stackedR];

permutation = [contract.q_global; contract.nx + contract.y_duration; ...
    contract.q_day; contract.nx + contract.y_binding];
for t = 1:nHours
    permutation = [permutation; contract.x_by_hour{t}; ...
        contract.nx + contract.y_by_hour{t}]; %#ok<AGROW>
end
assert(numel(permutation) == contract.nx + contract.neq && ...
    isequal(sort(permutation),(1:contract.nx+contract.neq).'), ...
    "stageA1:solver:ReducedPermutation", ...
    "Recursive reduced-system permutation is not bijective.");

permuted = reduced.saddle(permutation,permutation);
permutedRhs = reduced.rhs(permutation);
matrixDifference = permuted - expected;
rhsDifference = permutedRhs - expectedRhs;
matrixRelative = norm(matrixDifference,"fro") / max(1,norm(permuted,"fro"));
rhsRelative = norm(rhsDifference,2) / max(1,norm(permutedRhs,2));
if matrixRelative > options.AssemblyTolerance || rhsRelative > options.AssemblyTolerance
    message = "Reduced-system permutation check failed: matrix relative error %.17g, " + ...
        "RHS relative error %.17g, tolerance %.17g. No symmetrization was applied.";
    error("stageA1:solver:RecursiveAssemblyMismatch", ...
        message, ...
        matrixRelative, rhsRelative, options.AssemblyTolerance);
end

inversePermutation = zeros(size(permutation));
inversePermutation(permutation) = (1:numel(permutation)).';

partition = struct();
partition.linearization_identity = contract.identity;
partition.hours = contract.hours;
partition.contract = contract;
partition.hour = hourBlocks;
partition.M = M;
partition.B = stackedB;
partition.r_v = stackedR;
partition.block_offsets = blockOffsets;
partition.Q = sparse(Q);
partition.b_q = bq;
partition.R = R;
partition.r_duration = rdur;
partition.C = sparse(C);
partition.r_q_day = rq;
partition.r_binding = rbind;
partition.permutation = struct( ...
    "recursive_to_canonical_reduced",permutation, ...
    "canonical_reduced_to_recursive",inversePermutation);
partition.assembly_audit = struct( ...
    "permuted_reduced_matrix",permuted, ...
    "expected_recursive_matrix",expected, ...
    "matrix_difference_nnz",nnz(matrixDifference), ...
    "matrix_relative_error",matrixRelative, ...
    "permuted_rhs",permutedRhs, ...
    "expected_rhs",expectedRhs, ...
    "rhs_relative_error",rhsRelative, ...
    "tolerance",options.AssemblyTolerance, ...
    "passed",matrixRelative <= options.AssemblyTolerance && ...
        rhsRelative <= options.AssemblyTolerance);
end

function [M,B,r,offsets] = stack_hour_chain(hourBlocks)
nHours = numel(hourBlocks);
dimensions = reshape([hourBlocks.dimension],[],1);
starts = cumsum([1;dimensions(1:end-1)]);
ends = cumsum(dimensions);
offsets = table(reshape([hourBlocks.hour],[],1), starts, ends, dimensions, ...
    'VariableNames',{'hour','start_index','end_index','dimension'});

matrixCells = cell(nHours,nHours);
for t = 1:nHours
    for u = 1:nHours
        matrixCells{t,u} = sparse(dimensions(t),dimensions(u));
    end
    matrixCells{t,t} = hourBlocks(t).D;
end
for t = 2:nHours
    matrixCells{t,t-1} = hourBlocks(t).E;
    matrixCells{t-1,t} = hourBlocks(t).E.';
end
M = cell2mat(matrixCells);
B = vertcat(hourBlocks.B);
r = vertcat(hourBlocks.r);
end

function assert_binding_and_duration_structure(lin,contract,R)
nq = numel(contract.q_global);
assert(isequal(size(R),[2,nq]), "stageA1:solver:DurationMatrixShape", ...
    "Duration matrix R must be 2-by-14.");
expectedR = sparse([1,1,2,2],[11,13,12,14],[-2,1,-2,1],2,14);
if nnz(R-expectedR) ~= 0
    error("stageA1:solver:DurationJacobianValue", ...
        "R must encode ES1-2*QS1 and ES2-2*QS2 in canonical q order.");
end

bindingOnGlobal = sparse(lin.A(contract.y_binding,contract.q_global));
bindingOnDay = sparse(lin.A(contract.y_binding,contract.q_day));
if nnz(bindingOnGlobal + speye(nq)) ~= 0 || ...
        nnz(bindingOnDay - speye(nq)) ~= 0
    error("stageA1:solver:BindingJacobianSign", ...
        "Capacity binding must have q coefficient -I and q_d coefficient +I.");
end

allXi = (1:contract.nx).';
otherXi = setdiff(allXi,[contract.q_global;contract.q_day],"stable");
if nnz(lin.A(contract.y_binding,otherXi)) ~= 0
    error("stageA1:solver:BindingJacobianSupport", ...
        "Capacity-binding rows contain coefficients outside q and q_d.");
end

durationOther = setdiff(allXi,contract.q_global,"stable");
if nnz(lin.A(contract.y_duration,durationOther)) ~= 0
    error("stageA1:solver:DurationJacobianSupport", ...
        "Storage-duration rows may reference only global q.");
end
end
