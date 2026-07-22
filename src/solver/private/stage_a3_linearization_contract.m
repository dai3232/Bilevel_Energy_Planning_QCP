function contract = stage_a3_linearization_contract(lin)
%STAGE_A3_LINEARIZATION_CONTRACT Backward-compatible A3 contract wrapper.
contract = stage_a_multiday_linearization_contract(lin);
assert(contract.stage_id=="stage_A3","stageA3:solver:StageId", ...
    "The stage_A3 compatibility contract requires a stage_A3 linearization.");
end
