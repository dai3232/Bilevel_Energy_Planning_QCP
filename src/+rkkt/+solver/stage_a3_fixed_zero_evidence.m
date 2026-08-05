function evidence = stage_a3_fixed_zero_evidence(index)
%STAGE_A3_FIXED_ZERO_EVIDENCE Backward-compatible A3 evidence wrapper.
evidence = rkkt.solver.stage_a_multiday_fixed_zero_evidence(index);
end
