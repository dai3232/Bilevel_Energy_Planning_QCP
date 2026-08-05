function response = form_day_response(partition, thomas)
%FORM_DAY_RESPONSE Form the exact 14-dimensional daily Schur response.

arguments
    partition (1,1) struct
    thomas (1,1) struct
end

assert(isequal(partition.linearization_identity,thomas.linearization_identity), ...
    "stageA1:solver:LinearizationIdentityMismatch", ...
    "Thomas solution and partition identities differ.");
assert(thomas.rhs_count == 15, "stageA1:solver:DayResponseRhsCount", ...
    "Day response requires one physical RHS and fourteen capacity RHS columns.");

nHours = numel(partition.hour);
aByHour = cell(nHours,1);
uByHour = cell(nHours,1);
schurCorrection = sparse(14,14);
rhsCorrection = zeros(14,1);
for t = 1:nHours
    X = thomas.X_by_hour{t};
    aByHour{t} = X(:,1);
    uByHour{t} = X(:,2:15);
    schurCorrection = schurCorrection + partition.hour(t).B.' * uByHour{t};
    rhsCorrection = rhsCorrection + partition.hour(t).B.' * aByHour{t};
end

S = partition.C - schurCorrection;
c = partition.r_q_day - rhsCorrection;
beta = -partition.r_binding;
gamma = c - S*beta;
symmetryRelative = norm(S-S.',"fro") / max(1,norm(S,"fro"));
if any(~isfinite(nonzeros(S))) || any(~isfinite(c)) || ...
        any(~isfinite(beta)) || any(~isfinite(gamma))
    error("stageA1:solver:DayResponseNonfinite", ...
        "Day response contains NaN or Inf.");
end

response = struct();
response.linearization_identity = partition.linearization_identity;
response.a_by_hour = aByHour;
response.U_by_hour = uByHour;
response.S = sparse(S);
response.c = c;
response.beta = beta;
response.gamma = gamma;
response.diagnostics = struct( ...
    "dimension",size(S,1), ...
    "symmetry_relative",symmetryRelative, ...
    "chain_relative_residual",thomas.diagnostics.chain_relative_residual, ...
    "chain_max_absolute_residual",thomas.diagnostics.chain_max_absolute_residual);
assert(isequal(size(S),[14,14]) && numel(c)==14, ...
    "stageA1:solver:DayResponseDimension", ...
    "Day response must be 14-by-14 with a 14-vector RHS.");
end
