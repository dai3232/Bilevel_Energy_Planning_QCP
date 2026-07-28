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
