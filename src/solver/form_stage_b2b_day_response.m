function response = form_stage_b2b_day_response(day,solved,lin,reduced)
%FORM_STAGE_B2B_DAY_RESPONSE Persist the 14-by-14 bordered day response.
arguments
    day (1,1) struct
    solved (1,1) struct
    lin (1,1) struct
    reduced (1,1) struct
end
assert(isfield(solved,"a") && isfield(solved,"U") && ...
    isequal(size(solved.S),[14,14]), ...
    "stageB2B:response:Shape","Bordered day response has invalid fields.");
response = solved;
response.stage_id = "stage_B";
response.milestone_id = "B-2B";
response.linearization_identity = lin.identity;
response.c_gamma_distinct_formula = true;
response.response_formula = ...
    "a=M\\r; U=M\\B with daily water border; S=C-B'*U; c=r_qd-B'*a; gamma=c-S*beta";
response.diagnostics.day_response_dimension = 14;
response.diagnostics.c_gamma_distinct_formula = true;
response.diagnostics.linearization_identity = lin.identity;
response.diagnostics.water_rows = day.water.rows;
response.diagnostics.base_rhs_source = reduced.recursive_rhs_contract;
end
