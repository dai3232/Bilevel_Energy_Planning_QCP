function step = execute_stage_b2c_water_corrected_iteration( ...
        stateBefore,data,index,config,options)
%EXECUTE_STAGE_B2C_WATER_CORRECTED_ITERATION Verify one formal corrected step.
%
% The exact water-slack correction is now part of the formal B-2C update.
% This diagnostic entry delegates once to that formal update and performs
% no additional state change.

arguments
    stateBefore (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    options.PreviousLinearizationIdentity (1,1) string = ""
end

formalStep = rkkt.diagnostics.execute_stage_b2c_iteration( ...
    stateBefore,data,index,config, ...
    PreviousLinearizationIdentity=options.PreviousLinearizationIdentity);
step = formalStep;
step.experimental_method = ...
    "formal_exact_water_remainder_with_centrality_limited_correction";
step.formal_solver_modified = true;
step.formal_direction_modified = false;
step.formal_step_lengths_modified = false;
assert(step.water_slack_second_order_correction_applied && ...
    step.only_water_slacks_corrected, ...
    "stageB2C:waterCorrection:FormalDelegation", ...
    "The diagnostic alias did not receive the formal correction audit.");
end
