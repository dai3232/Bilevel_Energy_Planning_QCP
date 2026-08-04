% RKKT.SOLVER.VALIDATION Manual KKT-validation entry points.
%   runFullKKT        - Validate complete KKT assembly and audit direction.
%   runReducedKKT     - Validate exact inequality elimination.
%   runPartition      - Validate the seven-day recursive partition.
%   runDayChain       - Validate seven 24-hour multi-RHS chain solves.
%   runDayResponse    - Validate seven daily affine responses.
%   runDayAggregation - Validate fixed-order response aggregation.
%   runGlobalCore     - Validate the retained 16-dimensional core.
%   runRecovery       - Validate strict reverse canonical recovery.
%   runEquivalence    - Cross-check the staged chain and direction audit.
%   runStageB2B       - Validate one B-2B recursive/full audit pair.
