function [scaledMatrix,scaleVector,trace] = ...
        equilibrate_symmetric_congruence(matrix,passes)
%EQUILIBRATE_SYMMETRIC_CONGRUENCE Deterministic diagonal congruence scaling.
%
% The transformation is M_s = D*M*D, where D is positive diagonal.  It is
% a congruence transformation, not a modification of the model operator:
% callers solve M*x=b by solving M_s*u=D*b and returning x=D*u.  The
% original operator must remain available for every residual audit.
%
% This helper deliberately performs only bounded, elementwise scaling.  It
% does not regularize, symmetrize, pivot-reorder the model, or form an
% inverse.  It is used by the independently authorized numerical-stability
% stress route; the default production route leaves it disabled.

arguments
    matrix {mustBeNumeric,mustBeReal}
    passes (1,1) double {mustBeInteger,mustBeNonnegative} = 8
end

assert(passes <= 8, ...
    "stageA4:scaling:PassLimit", ...
    "Congruence equilibration is bounded to at most eight passes.");
assert(ismatrix(matrix) && size(matrix,1)==size(matrix,2), ...
    "stageA4:scaling:NotSquare", ...
    "The congruence-scaled operator must be square.");
assert(all(isfinite(nonzeros(matrix))), ...
    "stageA4:scaling:Nonfinite", ...
    "The congruence-scaled operator contains NaN or Inf.");

scaledMatrix = sparse(matrix);
n = size(scaledMatrix,1);
scaleVector = ones(n,1);
traceRows = repmat(empty_trace_row(),passes+1,1);
traceRows(1) = make_trace_row(0,scaledMatrix,scaleVector);

for pass = 1:passes
    rowNorm = max(abs(scaledMatrix),[],2);
    if any(~isfinite(rowNorm)) || any(rowNorm <= 0)
        error("stageA4:scaling:ZeroRowNorm", ...
            "Congruence equilibration encountered a zero/nonfinite row norm.");
    end
    step = 1 ./ sqrt(max(rowNorm,realmin));
    if any(~isfinite(step)) || any(step <= 0)
        error("stageA4:scaling:NonfiniteScale", ...
            "Congruence equilibration generated an invalid diagonal scale.");
    end
    candidateScale = scaleVector .* step;
    diagonal = spdiags(step,0,n,n);
    candidateMatrix = diagonal * scaledMatrix * diagonal;
    if any(~isfinite(nonzeros(candidateMatrix))) || ...
            any(~isfinite(candidateScale))
        error("stageA4:scaling:NonfiniteResult", ...
            "Congruence equilibration generated NaN or Inf.");
    end
    scaleVector = candidateScale;
    scaledMatrix = sparse(candidateMatrix);
    traceRows(pass+1) = make_trace_row(pass,scaledMatrix,scaleVector);
end

trace = struct2table(traceRows);
end

function row = empty_trace_row()
row = struct( ...
    "pass",0, ...
    "condition_2",NaN, ...
    "numeric_rank",0, ...
    "rank_tolerance",NaN, ...
    "smax",NaN, ...
    "smin",NaN, ...
    "below_rank_tolerance",0, ...
    "symmetry_relative",NaN, ...
    "scale_min",NaN, ...
    "scale_max",NaN, ...
    "scale_ratio",NaN);
end

function row = make_trace_row(pass,matrix,scaleVector)
dense = full(matrix); % only a small hourly/core pivot is ever passed here.
singularValues = svd(dense);
row = empty_trace_row();
row.pass = pass;
row.condition_2 = cond(dense,2);
row.numeric_rank = rank(dense);
row.rank_tolerance = max(size(dense))*eps(norm(dense,2));
row.smax = singularValues(1);
row.smin = singularValues(end);
row.below_rank_tolerance = nnz(singularValues <= row.rank_tolerance);
row.symmetry_relative = norm(dense-dense.',"fro") / ...
    max(1,norm(dense,"fro"));
row.scale_min = min(scaleVector);
row.scale_max = max(scaleVector);
row.scale_ratio = row.scale_max/row.scale_min;
end
