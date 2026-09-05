% RKKT.SOLVER Stable KKT interface namespace.
%   assembleFullKKT        - Assemble the complete sparse KKT audit system.
%   solveFullKKT           - Solve the complete sparse KKT audit direction.
%   eliminateInequalities - Form the inequality-eliminated KKT system.
%   partitionRecursiveSystem - Partition the seven-day reduced system.
%   solveDayChain          - Solve one 24-hour chain with 15 RHS columns.
%   buildDayResponse       - Form one daily affine response.
%   aggregateDayResponses - Aggregate seven responses in fixed day order.
%   solveGlobalCore        - Solve the retained 16-dimensional core.
%   recoverDirection       - Recover the complete canonical direction.
%   verifyEquivalence      - Audit recursive and complete KKT directions.
%   assembleStageB2AFullKKT - Assemble the explicit B-2A audit KKT.
%   solveStageB2BRecursiveDirection - Compute one official B-2B direction.
%   solveStageB2BFullKKTDirection - Compute one independent B-2B audit.
%   verifyStageB2BDirectionEquivalence - Compare the two B-2B directions.
%   solve_stage_b2c_day_ldl - Solve one B-2C bordered day with pivoted LDL.
%   solve_stage_b2c_daily_joint_direction - Solve the formal B-2C direction.
%   build_stage_b2c_daily_joint_structure_template - Cache immutable day slices.
%   solve_stage_b2c_joint_microborder_direction - Solve one confirmed 17-D joint mode.
%   detect_stage_b2c_joint_microborder - Infer a unique model-derived joint mode.
%   build_stage_b2c_global_physical_core_base - Rebuild the physical 16-D base.
%   solve_stage_b2c_delayed_inequality_border - Solve flagged days in an exact expanded border.
%   solve_stage_b2c_daily_joint_block - Factor one daily/core block for many RHS.
%   apply_stage_b2c_daily_joint_factor - Apply a retained LDL to a final RHS.
%   compute_certified_retained_residual_metrics - Certify or accurately rebuild a residual.
%   compute_fraction_to_boundary_step_high_low - Step along a retained twofold direction.
%   update_primal_dual_state_high_low - Consume a retained high/low direction.
%   run_stage_b2c_full_ipm - Run a seven-day IPM with full-KKT audit.
%   run_stage_b2c_365day_serial_ipm - Run/resume a serial range IPM.
%   prepare_stage_b2c_parallel_pool - Create/reuse the configured process pool.
%   close_stage_b2c_parallel_pool - Close the configured process pool.
