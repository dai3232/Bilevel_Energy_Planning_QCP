% RKKT.CONTRACTS Read-only public contract infrastructure.
%
%   version                - Return the frozen public contract version.
%   requiredFields         - Return a named contract's required fields.
%   requireStruct          - Require a scalar structure without modifying it.
%   requireFields          - Require structure fields without adding any.
%   requireTextScalar      - Require a text scalar.
%   requireNumericArray    - Require numeric type/shape/value properties.
%   moduleResultTemplate   - Create the canonical manual-validation envelope.
%   validateModuleMetadata - Validate moduleResult.meta.
%   validateModuleResult   - Validate a complete moduleResult envelope.
