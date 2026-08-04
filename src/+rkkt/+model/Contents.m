% RKKT.MODEL Stable state and linearization interface namespace.
%   initialize    - Delegate formal A4 state initialization.
%   linearize     - Build one A4 linearization from the explicit state.
%   residualView  - Read residuals and simple norms from a linearization.
%   jacobianView  - Read the stored Jacobian, A, and G.
%   hessianView   - Read the stored Hessian and H.
%   initializeStageB2A - Delegate explicit B-2A state initialization.
%   linearizeStageB2A  - Delegate explicit B-2A linearization.
%   initializeStageB2B - Delegate explicit B-2B state initialization.
%   linearizeStageB2B  - Delegate explicit B-2B linearization.
