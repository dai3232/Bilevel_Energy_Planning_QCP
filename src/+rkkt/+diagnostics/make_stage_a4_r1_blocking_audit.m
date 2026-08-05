function audit = make_stage_a4_r1_blocking_audit( ...
        unscaled,five,twenty,prefix,initialization,structure, ...
        roundTable,refinementTable,forbiddenExecutionAudit)
%MAKE_STAGE_A4_R1_BLOCKING_AUDIT Assemble the independent R1 gates.

arguments
    unscaled (1,1) struct
    five (1,1) struct
    twenty (1,1) struct
    prefix (1,1) struct
    initialization (1,1) struct
    structure (1,1) struct
    roundTable table
    refinementTable table
    forbiddenExecutionAudit table
end

testId = [ ...
    "R1-EXEC-UNSCALED-5"
    "R1-EXEC-SCALED-5"
    "R1-EXEC-SCALED-20"
    "R1-DETERMINISM-PREFIX"
    "R1-INITIAL-STATE"
    "R1-STABLE-V2-PASSES"
    "R1-POSITIVITY"
    "R1-DIRECTION-TOTAL"
    "R1-DIRECTION-COMPONENTS"
    "R1-RECURSIVE-KKT"
    "R1-FULL-KKT"
    "R1-NO-FALLBACK"
    "R1-FROZEN-STRUCTURE"
    "R1-FORBIDDEN-EXECUTION"];
requirement = [ ...
    "Unscaled stable baseline completes five updates"
    "Scaled stable short chain completes five updates"
    "Scaled stable long chain completes twenty updates"
    "Scaled 5 and scaled 20 prefix match at zero tolerance"
    "All three chains share one exact initial xi/y/l/z state"
    "Every round explicitly enables stable-v2 MaxPasses=3"
    "Every round remains finite with l>0 and z>0"
    "Every total direction relative error is <=1e-10"
    "Every xi/y/l/z direction error is <=1e-10"
    "Every recursive direction full-KKT residual is <=1e-10"
    "Every direct audit direction residual is <=1e-10"
    "No complete-KKT direction fallback is used"
    "Model matrices, offsets, maps, index and dimensions are frozen"
    "No common step, dynamic sigma, PC, line search, regularization, "+ ...
        "parallel, formal run, 100 rounds or Stage B is executed"];
actual = false(numel(testId),1);
actual(1) = unscaled.iteration_count==5 && unscaled.all_pass;
actual(2) = five.iteration_count==5 && five.all_pass;
actual(3) = twenty.iteration_count==20 && twenty.all_pass && ...
    ~twenty.failure.present;
actual(4) = prefix.all_pass;
actual(5) = initialization.all_pass;
actual(6) = height(roundTable)==30 && ...
    all(roundTable.recursive_refinement_max_passes==3) && ...
    height(refinementTable)==240 && ...
    all(refinementTable.maximum_passes==3);
actual(7) = all(roundTable.min_l_before>0) && ...
    all(roundTable.min_l_after>0) && ...
    all(roundTable.min_z_before>0) && ...
    all(roundTable.min_z_after>0) && ...
    all(isfinite(roundTable{:,vartype("numeric")}),"all");
actual(8) = all(roundTable.direction_relative_error<=1e-10);
actual(9) = all(roundTable{:, ...
    {'xi_relative_error','y_relative_error', ...
    'l_relative_error','z_relative_error'}}<=1e-10,"all");
actual(10) = all( ...
    roundTable.recursive_full_kkt_relative_residual<=1e-10);
actual(11) = all(roundTable.full_kkt_relative_residual<=1e-10);
actual(12) = all(roundTable.no_full_direction_fallback);
actual(13) = structure.all_pass;
actual(14) = all(forbiddenExecutionAudit.status=="PASS");
status = repmat("FAIL",numel(testId),1);
status(actual) = "PASS";
audit = table(testId,requirement,actual,status, ...
    'VariableNames',{'test_id','requirement','actual','status'});
end
