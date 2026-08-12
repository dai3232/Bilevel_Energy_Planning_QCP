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
%   solve_stage_b2c_daily_joint_block - Factor one daily/core block for many RHS.
%   run_stage_b2c_full_ipm - Run the formal seven-day daily-joint IPM.
