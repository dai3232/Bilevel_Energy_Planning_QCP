% RKKT.MODEL Stable state and linearization interface namespace.
%   initialize    - Build the formal A4 initial state.
%   linearize     - Build one A4 linearization from the explicit state.
%   residualView  - Read residuals and simple norms from a linearization.
%   jacobianView  - Read the stored Jacobian, A, and G.
%   hessianView   - Read the stored Hessian and H.
%   initializeStageB2A - Build the explicit B-2A initial state.
%   linearizeStageB2A  - Build the explicit B-2A linearization.
%   initializeStageB2B - Build the explicit B-2B initial state.
%   linearizeStageB2B  - Build the explicit B-2B linearization.
%   build_stage_b2c_linearization_template - Freeze invariant B-2C structure.
%   evaluate_stage_b2c_water_template - Update all daily-water rows in bulk.
%   update_stage_b2c_scaled_objective_linearization - Refresh dynamic values.
