function value = stateFingerprint(state)
%STATEFINGERPRINT Compute the deterministic state fingerprint.

value = rkkt.artifacts.compute_stage_a4_checkpoint_state_fingerprint(state);
end
