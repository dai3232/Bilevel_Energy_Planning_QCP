function tests = test_stage_a4_complementarity_gap_audit
%TEST_STAGE_A4_COMPLEMENTARITY_GAP_AUDIT Verify the fixed A4-2B audit.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
runsBefore = recursive_run_inventory(projectRoot);
currentStagePath = fullfile(projectRoot,"CURRENT_STAGE.md");
solverPath = fullfile(projectRoot,"config","solver.yaml");
stageConfigPath = fullfile(projectRoot,"config","stage_A4.yaml");
currentStageHashBefore = string(rkkt.data.compute_sha256_file(currentStagePath));
solverHashBefore = string(rkkt.data.compute_sha256_file(solverPath));
stageConfigHashBefore = string(rkkt.data.compute_sha256_file(stageConfigPath));
result = main_stage_A4_2B();
fixturePath = fullfile(projectRoot,"tests","fixtures", ...
    "stage_A4_2A_five_round_baseline.csv");
baseline = readtable(fixturePath,'Delimiter',',', ...
    'ReadVariableNames',true,'TextType','string', ...
    'VariableNamingRule','preserve');
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.baseline = baseline;
testCase.TestData.runs_before = runsBefore;
testCase.TestData.runs_after = recursive_run_inventory(projectRoot);
testCase.TestData.current_stage_hash_before = currentStageHashBefore;
testCase.TestData.current_stage_hash_after = ...
    string(rkkt.data.compute_sha256_file(currentStagePath));
testCase.TestData.solver_hash_before = solverHashBefore;
testCase.TestData.solver_hash_after = ...
    string(rkkt.data.compute_sha256_file(solverPath));
testCase.TestData.stage_config_hash_before = stageConfigHashBefore;
testCase.TestData.stage_config_hash_after = ...
    string(rkkt.data.compute_sha256_file(stageConfigPath));
end

function testReproducesFrozenA42AFiveRoundBaseline(testCase)
result = testCase.TestData.result;
expected = testCase.TestData.baseline;
actual = result.baseline_table;
verifyEqual(testCase,height(actual),5);
verifyEqual(testCase,actual.iteration,(1:5).','AbsTol',0);
verifyEqual(testCase,[result.iterations.state_revision_before],0:4);
verifyEqual(testCase,[result.iterations.state_revision_after],1:5);
verifyEqual(testCase,actual.primal_limiter,string(expected.primal_limiter));
verifyEqual(testCase,actual.dual_limiter,string(expected.dual_limiter));
numericNames = setdiff(string(actual.Properties.VariableNames), ...
    ["primal_limiter","dual_limiter"],'stable');
for name = numericNames
    verifyEqual(testCase,actual.(name),double(expected.(name)), ...
        'AbsTol',0,sprintf('Frozen A4-2A mismatch in %s.',name));
end
verifyEqual(testCase,result.linearization_after_identities(1:4), ...
    result.linearization_before_identities(2:5));
end

function testComplementarityGapDecompositionClosesAtMachinePrecision(testCase)
audits = testCase.TestData.result.complementarity_audits;
for k = 1:5
    audit = audits(k);
    d = audit.decomposition;
    rows = audit.delta_by_inequality;
    verifyEqual(testCase,d.gap_before,mean(rows.product_before),'AbsTol',0);
    verifyEqual(testCase,d.gap_after,mean(rows.product_after),'AbsTol',0);
    verifyEqual(testCase,d.alpha_primal_mean_delta_l_times_z, ...
        mean(rows.slack_term_contribution),'AbsTol',0);
    verifyEqual(testCase,d.alpha_dual_mean_l_times_delta_z, ...
        mean(rows.multiplier_term_contribution),'AbsTol',0);
    verifyEqual(testCase, ...
        d.alpha_primal_alpha_dual_mean_delta_l_times_delta_z, ...
        mean(rows.cross_term_contribution),'AbsTol',0);
    verifyLessThanOrEqual(testCase,d.closure_relative_error,2048*eps);
    verifyLessThanOrEqual(testCase, ...
        d.maximum_item_closure_relative_error,2048*eps);
    terms = [d.alpha_primal_mean_delta_l_times_z, ...
        d.alpha_dual_mean_l_times_delta_z, ...
        d.alpha_primal_alpha_dual_mean_delta_l_times_delta_z];
    names = ["alpha_primal_mean_delta_l_times_z", ...
        "alpha_dual_mean_l_times_delta_z", ...
        "alpha_primal_alpha_dual_mean_delta_l_times_delta_z"];
    positive = find(terms>0);
    [expectedValue,position] = max(terms(positive));
    verifyEqual(testCase,d.largest_positive_term, ...
        names(positive(position)));
    verifyEqual(testCase,d.largest_positive_term_value,expectedValue, ...
        'AbsTol',0);
    verifyTrue(testCase,audit.checks.gap_decomposition_closed);
    verifyTrue(testCase,audit.checks.item_decomposition_closed);
end
end

function testTopTwentyPositiveContributorsAreExactlyTraceable(testCase)
result = testCase.TestData.result;
inventory = result.inequality_inventory;
for k = 1:5
    audit = result.complementarity_audits(k);
    rows = audit.delta_by_inequality;
    top = audit.top20;
    verifyEqual(testCase,height(rows),7248);
    positiveRows = find(rows.delta_i>0);
    [~,order] = sortrows( ...
        [-rows.delta_i(positiveRows),rows.inequality_index(positiveRows)], ...
        [1,2]);
    expectedCount = min(20,numel(positiveRows));
    expectedRows = positiveRows(order(1:expectedCount));
    verifyEqual(testCase,height(top),expectedCount);
    verifyEqual(testCase,audit.decomposition.positive_constraint_count, ...
        numel(positiveRows));
    verifyEqual(testCase, ...
        audit.decomposition.top_positive_constraint_count,expectedCount);
    if expectedCount>0
        verifyGreaterThan(testCase,min(top.delta_i),0);
    end
    verifyEqual(testCase,top.inequality_index,expectedRows);
    verifyEqual(testCase,top.rank,(1:expectedCount).');
    meta = inventory(expectedRows,:);
    verifyEqual(testCase,top.constraint_global_row,meta.global_row);
    verifyEqual(testCase,top.constraint_id,string(meta.constraint_id));
    verifyEqual(testCase,top.constraint_name,string(meta.constraint_name));
    verifyEqual(testCase,top.day,meta.day);
    verifyEqual(testCase,top.hour,meta.hour);
    verifyEqual(testCase,top.asset_type,string(meta.asset_type));
    verifyEqual(testCase,top.asset_id,meta.asset_id);
    if expectedCount>0
        reconstructed = top.l_after.*top.z_after- ...
            top.l_before.*top.z_before;
        scale = max([ones(height(top),1),abs(top.delta_i)],[],2);
        verifyLessThanOrEqual(testCase,max(abs(top.delta_i- ...
            reconstructed)./scale),16*eps);
        verifyLessThanOrEqual(testCase,max(abs(top.delta_i- ...
            top.predicted_delta)./scale),2048*eps);
    end
    verifyTrue(testCase,audit.checks.top20_traceable);
end
end

function testConstraintFamilyAndAssetTypeContributionSummariesClose(testCase)
audits = testCase.TestData.result.complementarity_audits;
for k = 1:5
    audit = audits(k);
    verifyTrue(testCase,audit.contribution_analysis_evaluated);
    verifyEmpty(testCase,audit.not_evaluated_checks);
    rows = audit.delta_by_inequality;
    for summary = {audit.constraint_family_summary, ...
            audit.asset_type_summary}
        grouped = summary{1};
        verifyEqual(testCase,sum(grouped.inequality_count),7248);
        verifyEqual(testCase,sum(grouped.positive_count), ...
            nnz(rows.delta_i>0));
        verifyEqual(testCase,sum(grouped.negative_count), ...
            nnz(rows.delta_i<0));
        verifyEqual(testCase,sum(grouped.zero_count), ...
            nnz(rows.delta_i==0));
        verify_sum_close(testCase,sum(grouped.positive_contribution), ...
            sum(rows.delta_i(rows.delta_i>0)));
        verify_sum_close(testCase,sum(grouped.negative_contribution), ...
            sum(rows.delta_i(rows.delta_i<0)));
        verify_sum_close(testCase,sum(grouped.net_contribution), ...
            sum(rows.delta_i));
        verifyLessThanOrEqual(testCase, ...
            max(grouped.closure_relative_error),2048*eps);
    end
    gapChangeFromRows = sum(rows.delta_i)/height(rows);
    verify_sum_close(testCase,gapChangeFromRows, ...
        audit.decomposition.gap_change);
    verifyTrue(testCase,audit.checks.constraint_family_summary_closed);
    verifyTrue(testCase,audit.checks.asset_type_summary_closed);
end
end

function testCenteringAndScaleStatisticsCoverCanonicalVectors(testCase)
audits = testCase.TestData.result.complementarity_audits;
for k = 1:5
    audit = audits(k);
    centrality = audit.centrality_statistics;
    verifyEqual(testCase,height(centrality),4);
    verifyEqual(testCase,centrality.count,7248*ones(4,1));
    rows = audit.delta_by_inequality;
    expected = {rows.product_before;rows.product_after; ...
        rows.product_before/audit.decomposition.gap_before/0.1; ...
        rows.product_after/audit.decomposition.gap_after/0.1};
    for row = 1:4
        values = expected{row};
        verify_sum_close(testCase,centrality.minimum(row),min(values));
        verify_sum_close(testCase,centrality.median(row),median(values));
        verify_sum_close(testCase,centrality.p95(row),percentile95(values));
        verify_sum_close(testCase,centrality.maximum(row),max(values));
    end
    vectorScale = audit.vector_scale_statistics;
    verifyEqual(testCase,height(vectorScale),6);
    verifyEqual(testCase,vectorScale.count,7248*ones(6,1));
    verifyGreaterThanOrEqual(testCase,min(vectorScale.zero_count),0);
    verifyTrue(testCase,all(isfinite(vectorScale.maximum_absolute)));
    grouped = audit.group_scale_statistics;
    for quantity = ["objective_gradient","dual_residual"]
        for state = ["before","after"]
            mask = grouped.quantity==quantity & grouped.state==state;
            verifyEqual(testCase,sum(grouped.count(mask)),3722);
        end
    end
    for state = ["before","after"]
        mask = grouped.quantity=="equality_residual" & ...
            grouped.state==state;
        verifyEqual(testCase,sum(grouped.count(mask)),618);
    end
    objectiveBefore = grouped(grouped.quantity=="objective_gradient" & ...
        grouped.state=="before",:);
    verifyEqual(testCase,sum(objectiveBefore.nonzero_count),14);

    residualScale = audit.residual_scale_statistics;
    verifyEqual(testCase,height(residualScale),4);
    quantities = ["r_ineq";"r_ineq";"r_comp";"r_comp"];
    states = ["before";"after";"before";"after"];
    identities = [audit.linearization_identity_before; ...
        audit.linearization_identity_after; ...
        audit.linearization_identity_before; ...
        audit.linearization_identity_after];
    residualValues = {rows.r_ineq_before;rows.r_ineq_after; ...
        rows.r_comp_before;rows.r_comp_after};
    verifyEqual(testCase,residualScale.quantity,quantities);
    verifyEqual(testCase,residualScale.state,states);
    verifyEqual(testCase,residualScale.linearization_identity,identities);
    for residualIndex = 1:4
        verify_scale_statistics_row(testCase, ...
            residualScale(residualIndex,:),residualValues{residualIndex});
    end

    muBefore = 0.1*mean(rows.product_before);
    muAfter = 0.1*mean(rows.product_after);
    verifyEqual(testCase,rows.r_comp_before, ...
        rows.product_before-muBefore,'AbsTol',0);
    verifyEqual(testCase,rows.r_comp_after, ...
        rows.product_after-muAfter,'AbsTol',0);
    if k==1
        initialInequality = residualScale( ...
            residualScale.quantity=="r_ineq" & ...
            residualScale.state=="before",:);
        verifyEqual(testCase,initialInequality.nonzero_count,0);
        verifyEqual(testCase,initialInequality.zero_count,7248);
        verifyTrue(testCase,isnan( ...
            initialInequality.minimum_absolute_nonzero));
        verifyTrue(testCase,isnan( ...
            initialInequality.minimum_order_of_magnitude));
        verifyTrue(testCase,isnan( ...
            initialInequality.maximum_order_of_magnitude));
        verifyTrue(testCase,isnan( ...
            initialInequality.order_of_magnitude_span));
    end

    familyScale = audit.inequality_family_scale_statistics;
    expectedFamilies = expected_inequality_families();
    verifyEqual(testCase,height(familyScale),64);
    verifyEqual(testCase,unique(familyScale.group_kind), ...
        "constraint_family");
    for residualIndex = 1:4
        familyRows = familyScale( ...
            familyScale.quantity==quantities(residualIndex) & ...
            familyScale.state==states(residualIndex),:);
        verifyEqual(testCase,height(familyRows),16);
        verifyEqual(testCase,familyRows.group_name, ...
            expectedFamilies.constraint_family);
        verifyEqual(testCase,familyRows.count, ...
            expectedFamilies.inequality_count);
        verifyEqual(testCase,sum(familyRows.count),7248);
        verifyEqual(testCase,sum(familyRows.nonzero_count), ...
            residualScale.nonzero_count(residualIndex));
        verifyEqual(testCase,sum(familyRows.negative_count), ...
            residualScale.negative_count(residualIndex));
        verifyEqual(testCase,sum(familyRows.zero_count), ...
            residualScale.zero_count(residualIndex));
        verifyEqual(testCase,sum(familyRows.positive_count), ...
            residualScale.positive_count(residualIndex));
        verifyEqual(testCase,familyRows.linearization_identity, ...
            repmat(identities(residualIndex),16,1));
        for familyIndex = 1:16
            familyName = familyRows.group_name(familyIndex);
            mask = rows.constraint_name==familyName;
            verify_scale_statistics_row(testCase, ...
                familyRows(familyIndex,:), ...
                residualValues{residualIndex}(mask));
            verifyEqual(testCase,familyRows.asset_type_set(familyIndex), ...
                joined_unique(rows.asset_type(mask)));
            verifyEqual(testCase,familyRows.unit_set(familyIndex), ...
                joined_unique(rows.unit(mask)));
        end
    end
    verifyTrue(testCase,audit.checks.residual_definitions_exact);
    verifyTrue(testCase,audit.checks.residual_scale_coverage_closed);
end
end

function testCommonStepCounterfactualIsPositiveAndStateReadOnly(testCase)
result = testCase.TestData.result;
for k = 1:5
    audit = result.complementarity_audits(k);
    rows = audit.delta_by_inequality;
    c = audit.counterfactual;
    verifyEqual(testCase,c.alpha_common,min(c.official_alpha_primal, ...
        c.official_alpha_dual),'AbsTol',0);
    lCommon = rows.l_before+c.alpha_common*rows.delta_l;
    zCommon = rows.z_before+c.alpha_common*rows.delta_z;
    verifyEqual(testCase,c.gap_after,mean(lCommon.*zCommon),'AbsTol',0);
    verifyEqual(testCase,c.minimum_l,min(lCommon),'AbsTol',0);
    verifyEqual(testCase,c.minimum_z,min(zCommon),'AbsTol',0);
    verifyGreaterThan(testCase,c.minimum_l,0);
    verifyGreaterThan(testCase,c.minimum_z,0);
    verifyTrue(testCase,c.read_only);
    verifyFalse(testCase,c.used_for_official_state_update);
    verifyTrue(testCase,audit.official_state_unchanged);
    verifyEqual(testCase,audit.linearization_identity_after, ...
        result.iterations(k).linearization_identity_after);
    if k<5
        verifyEqual(testCase,audit.linearization_identity_after, ...
            result.complementarity_audits(k+1).linearization_identity_before);
    end
    verifyEqual(testCase,rows.l_after,rows.l_before+ ...
        c.official_alpha_primal*rows.delta_l,'AbsTol',0);
    verifyEqual(testCase,rows.z_after,rows.z_before+ ...
        c.official_alpha_dual*rows.delta_z,'AbsTol',0);
end
verifyEqual(testCase,result.execution.counterfactual_state_update_count,0);
verifyFalse(testCase, ...
    result.execution.counterfactual_consumed_by_official_state);
end

function testA42BProductionClosurePassesForbiddenCallScan(testCase)
result = testCase.TestData.result;
scan = rkkt.diagnostics.scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,result.config);
verifyEqual(testCase,string(scan.status),repmat("PASS",height(scan),1), ...
    evalc('disp(scan(scan.status~="PASS",:))'));
verifyEqual(testCase,scan.match_count,zeros(height(scan),1));
verifyTrue(testCase,any(scan.check_id== ...
    "NO-A42B-ADDITIONAL-DENSE-CONDITION-NUMBER"));
verifyTrue(testCase,any(scan.check_id=="NO-PREDICTOR-CORRECTOR"));
verifyFalse(testCase,any(contains(lower(scan.matched_files), ...
    ["tests/","runs/"])));
end

function testDiagnosticCreatesNoRunAndPreservesStageGovernance(testCase)
result = testCase.TestData.result;
verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyEqual(testCase,result.milestone_status,"PASS");
verifyEqual(testCase,result.iteration_count,5);
verifyEqual(testCase,result.execution.newton_direction_count,5);
verifyEqual(testCase,result.execution.state_update_count,5);
verifyEqual(testCase,result.execution.full_kkt_audit_count,5);
verifyEqual(testCase,result.execution.a4_2b_parameter_change_count,0);
verifyFalse(testCase, ...
    result.execution.a4_2b_additional_dense_condition_number_executed);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyEqual(testCase,result.config.initialization.centering_sigma,0.1, ...
    'AbsTol',0);
verifyEqual(testCase,result.config.fraction_to_boundary,0.9995,'AbsTol',0);
verifyEqual(testCase,testCase.TestData.runs_after, ...
    testCase.TestData.runs_before);
verifyEqual(testCase,testCase.TestData.current_stage_hash_after, ...
    testCase.TestData.current_stage_hash_before);
verifyEqual(testCase,testCase.TestData.solver_hash_after, ...
    testCase.TestData.solver_hash_before);
verifyEqual(testCase,testCase.TestData.stage_config_hash_after, ...
    testCase.TestData.stage_config_hash_before);
end

function verify_sum_close(testCase,actual,expected)
scale = max([1,abs(actual),abs(expected)]);
verifyLessThanOrEqual(testCase,abs(actual-expected)/scale,2048*eps);
end

function verify_scale_statistics_row(testCase,row,values)
values = values(:);
absoluteValues = abs(values);
nonzeroValues = absoluteValues(absoluteValues>0);
verifyEqual(testCase,row.count,numel(values));
verifyEqual(testCase,row.nonzero_count,numel(nonzeroValues));
verifyEqual(testCase,row.negative_count,nnz(values<0));
verifyEqual(testCase,row.zero_count,nnz(values==0));
verifyEqual(testCase,row.positive_count,nnz(values>0));
verifyEqual(testCase,row.minimum_value,min(values),'AbsTol',0);
verifyEqual(testCase,row.maximum_value,max(values),'AbsTol',0);
verifyEqual(testCase,row.median_absolute,median(absoluteValues),'AbsTol',0);
verifyEqual(testCase,row.p95_absolute,percentile95(absoluteValues), ...
    'AbsTol',0);
verifyEqual(testCase,row.maximum_absolute,max(absoluteValues),'AbsTol',0);
if isempty(nonzeroValues)
    verifyTrue(testCase,isnan(row.minimum_absolute_nonzero));
    verifyTrue(testCase,isnan(row.minimum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.maximum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.order_of_magnitude_span));
else
    minimumOrder = floor(log10(min(nonzeroValues)));
    maximumOrder = floor(log10(max(nonzeroValues)));
    verifyEqual(testCase,row.minimum_absolute_nonzero,min(nonzeroValues), ...
        'AbsTol',0);
    verifyEqual(testCase,row.minimum_order_of_magnitude,minimumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.maximum_order_of_magnitude,maximumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.order_of_magnitude_span, ...
        maximumOrder-minimumOrder,'AbsTol',0);
end
end

function expected = expected_inequality_families()
constraintFamily = [ ...
    "global_capacity_lower_bound"
    "global_capacity_upper_bound"
    "pch_lower_bound"
    "pch_upper_bound"
    "pdis_lower_bound"
    "pdis_upper_bound"
    "pf_lower_bound"
    "pf_upper_bound"
    "ph_lower_bound"
    "ph_upper_bound"
    "pp_lower_bound"
    "pp_upper_bound"
    "pw_lower_bound"
    "pw_upper_bound"
    "soc_lower_bound"
    "soc_upper_bound"];
inequalityCount = [14;14;336;336;336;336;672;672;672;672; ...
    420;420;838;838;336;336];
expected = table(constraintFamily,inequalityCount, ...
    'VariableNames',{'constraint_family','inequality_count'});
end

function value = joined_unique(values)
value = strjoin(sort(unique(string(values))),"+");
end

function value = percentile95(values)
values = sort(values(:));
position = 1+0.95*(numel(values)-1);
lowerPosition = floor(position);
upperPosition = ceil(position);
if lowerPosition==upperPosition
    value = values(lowerPosition);
else
    weight = position-lowerPosition;
    value = (1-weight)*values(lowerPosition)+weight*values(upperPosition);
end
end

function inventory = recursive_run_inventory(projectRoot)
runRoot = fullfile(projectRoot,"runs");
entries = dir(fullfile(runRoot,"**","*"));
entries = entries(~ismember(string({entries.name}),[".",".."])) ;
relativePath = strings(numel(entries),1);
for entryIndex = 1:numel(entries)
    absolutePath = fullfile(entries(entryIndex).folder,entries(entryIndex).name);
    relativePath(entryIndex) = replace(extractAfter(string(absolutePath), ...
        strlength(runRoot)+1),'\','/');
end
isDirectory = [entries.isdir].';
bytes = [entries.bytes].';
modifiedDatenum = [entries.datenum].';
[relativePath,order] = sort(relativePath);
inventory = table(relativePath,isDirectory(order),bytes(order), ...
    modifiedDatenum(order),'VariableNames', ...
    {'relative_path','is_directory','bytes','modified_datenum'});
end
