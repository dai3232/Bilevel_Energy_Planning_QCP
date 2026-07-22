function updated = update_primal_dual_state(state,direction,alphaPrimal,alphaDual)
%UPDATE_PRIMAL_DUAL_STATE Apply one prescribed primal-dual IPM state update.
%
% xi and l use alphaPrimal.  y and z use alphaDual.  The function performs
% no line search and leaves all noncanonical metadata fields unchanged.

if ~(isstruct(state) && isscalar(state))
    error("stageA4:update:InvalidState", ...
        "state must be a scalar struct.");
end
if ~(isstruct(direction) && isscalar(direction))
    error("stageA4:update:InvalidDirection", ...
        "direction must be a scalar struct.");
end
validate_step(alphaPrimal,"alphaPrimal");
validate_step(alphaDual,"alphaDual");

required = ["xi","y","l","z"];
for name = required
    field = char(name);
    if ~isfield(state,field)
        error("stageA4:update:MissingStateField", ...
            "state.%s is required.",name);
    end
    if ~isfield(direction,field)
        error("stageA4:update:MissingDirectionField", ...
            "direction.%s is required.",name);
    end
    validate_finite_column(state.(field),"state."+name);
    validate_finite_column(direction.(field),"direction."+name);
    if numel(state.(field)) ~= numel(direction.(field))
        error("stageA4:update:DimensionMismatch", ...
            "state.%s and direction.%s must have identical dimensions.", ...
            name,name);
    end
end
if any(state.l <= 0) || any(state.z <= 0)
    error("stageA4:update:NonpositiveInput", ...
        "state.l and state.z must be strictly positive componentwise.");
end

updated = state;
updated.xi = state.xi + alphaPrimal*direction.xi;
updated.l = state.l + alphaPrimal*direction.l;
updated.y = state.y + alphaDual*direction.y;
updated.z = state.z + alphaDual*direction.z;

for name = required
    field = char(name);
    if any(~isfinite(updated.(field)))
        error("stageA4:update:NonfiniteOutput", ...
            "The updated state.%s contains NaN or Inf.",name);
    end
end
if any(updated.l <= 0) || any(updated.z <= 0)
    error("stageA4:update:NonpositiveOutput", ...
        "The update must leave state.l and state.z strictly positive.");
end
end

function validate_step(alpha,name)
if ~(isa(alpha,"double") && isreal(alpha) && isscalar(alpha) && ...
        isfinite(alpha) && alpha > 0 && alpha <= 1)
    error("stageA4:update:InvalidStep", ...
        "%s must be a finite real double scalar in (0,1].",name);
end
end

function validate_finite_column(value,name)
if ~(isa(value,"double") && isreal(value) && ismatrix(value) && ...
        size(value,2) == 1 && ~isempty(value))
    error("stageA4:update:InvalidVector", ...
        "%s must be a nonempty real double column vector.",name);
end
if any(~isfinite(value))
    error("stageA4:update:NonfiniteVector", ...
        "%s must contain only finite values.",name);
end
end
