function digest = compute_stage_a4_checkpoint_state_fingerprint(state)
%COMPUTE_STAGE_A4_CHECKPOINT_STATE_FINGERPRINT Hash a canonical A4 state.
%
% The byte contract intentionally matches the fingerprint used by the
% frozen A4-2D-2A-R1 evidence: vector lengths, the four revision counters,
% and the exact xi/y/l/z double payload are hashed in that order.

required = ["xi","y","l","z","iteration_index","state_revision", ...
    "newton_direction_number","completed_newton_direction_count"];
assert(isstruct(state) && isscalar(state) && ...
    all(isfield(state,cellstr(required))), ...
    "stageA4:checkpoint:StateFingerprintFields", ...
    "The checkpoint state is missing a canonical vector or revision field.");

vectorNames = ["xi","y","l","z"];
payload = zeros(0,1);
lengths = zeros(numel(vectorNames),1);
for k = 1:numel(vectorNames)
    value = state.(vectorNames(k));
    assert(isa(value,"double") && isreal(value) && ...
        ismatrix(value) && size(value,2)==1 && ~isempty(value) && ...
        all(isfinite(value)), ...
        "stageA4:checkpoint:StateFingerprintVector", ...
        "state.%s must be a nonempty finite real double column.", ...
        vectorNames(k));
    lengths(k) = numel(value);
    payload = [payload;value]; %#ok<AGROW>
end

counterNames = ["iteration_index","state_revision", ...
    "newton_direction_number","completed_newton_direction_count"];
counters = zeros(numel(counterNames),1);
for k = 1:numel(counterNames)
    value = state.(counterNames(k));
    assert(isa(value,"double") && isreal(value) && isscalar(value) && ...
        isfinite(value) && value>=0 && value==fix(value), ...
        "stageA4:checkpoint:StateFingerprintCounter", ...
        "state.%s must be a finite nonnegative integer double.", ...
        counterNames(k));
    counters(k) = value;
end

bytes = typecast([lengths;counters;payload],"uint8");
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
messageDigest.update(typecast(bytes,"int8"));
digestBytes = mod(double(messageDigest.digest()),256);
digest = lower(join(compose("%02x",digestBytes),""));
digest = reshape(digest,1,1);
end
