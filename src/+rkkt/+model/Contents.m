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
%   build_stage_b2c_recursive_block_template - Build global/day operators.
%   build_stage_b2c_recursive_runtime_maps - Compress audit indices to maps.
%   build_stage_b2c_structural_topology_fingerprint - Hash active topology.
%   build_stage_b2c_recursive_structure - Build compact topology directly.
%   build_stage_b2c_recursive_numerical_payload - Fill current coefficients.
%   build_stage_b2c_recursive_runtime_package - Audit baseline only.
%   initialize_stage_b2c_runtime_state - Initialize without canonical index.
%   recover_stage_b2c_runtime_physical_arrays - Restore from compact maps.
%   update_stage_b2c_recursive_block_linearization - Refresh block numerics.
%   apply_stage_b2c_equality_jacobian - Apply block A or A'.
%   apply_stage_b2c_inequality_jacobian - Apply block G or G'.
%   apply_stage_b2c_lagrangian_hessian - Apply the block water Hessian.
