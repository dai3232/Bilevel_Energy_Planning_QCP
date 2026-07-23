function tests = test_stage_a4_small_step_root_cause_audit
%TEST_STAGE_A4_SMALL_STEP_ROOT_CAUSE_AUDIT Verify the fixed A4-2D-1 audit.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));
protectedBefore = capture_protected_snapshot(projectRoot);
result = main_stage_A4_2D_1();
protectedAfter = capture_protected_snapshot(projectRoot);
fixturePath = fullfile(projectRoot,"tests","fixtures", ...
    "stage_A4_2A_five_round_baseline.csv");
baseline = readtable(fixturePath,'Delimiter',',', ...
    'ReadVariableNames',true,'TextType','string', ...
    'VariableNamingRule','preserve');
testCase.TestData.project_root = projectRoot;
testCase.TestData.result = result;
testCase.TestData.baseline = baseline;
testCase.TestData.protected_before = protectedBefore;
testCase.TestData.protected_after = protectedAfter;
end

function testFrozenA42CBaselineReproducesFieldByField(testCase)
result = testCase.TestData.result;
expected = testCase.TestData.baseline;
actual = make_baseline_table(result.ab_result.chain_a.iterations);
verifyEqual(testCase,height(actual),5);
verifyEqual(testCase,string(actual.Properties.VariableNames), ...
    string(expected.Properties.VariableNames));
verifyEqual(testCase,actual.primal_limiter,string(expected.primal_limiter));
verifyEqual(testCase,actual.dual_limiter,string(expected.dual_limiter));
numericNames = setdiff(string(actual.Properties.VariableNames), ...
    ["primal_limiter","dual_limiter"],'stable');
for name = numericNames
    verifyEqual(testCase,actual.(name),double(expected.(name)), ...
        'AbsTol',0,sprintf('Frozen A4-2A mismatch in %s.',name));
end

firstA = result.ab_result.chain_a.iterations(1);
lastA = result.ab_result.chain_a.iterations(5);
lastB = result.ab_result.chain_b.iterations(5);
snapshot = firstA.root_cause_linearization_before;
verifyEqual(testCase,norm(snapshot.r_eq,inf), ...
    3623.4474999999998,'AbsTol',0);
verifyEqual(testCase,norm(snapshot.r_dual,inf),4920145.04,'AbsTol',0);
verifyEqual(testCase,mean(snapshot.l.*snapshot.z), ...
    177.48920736754982,'AbsTol',0);
verifyEqual(testCase, ...
    mean(lastA.canonical_state_after.l.*lastA.canonical_state_after.z), ...
    245.53321737907518,'AbsTol',0);
verifyEqual(testCase, ...
    mean(lastB.canonical_state_after.l.*lastB.canonical_state_after.z), ...
    176.41190650680699,'AbsTol',0);
verifyTrue(testCase,result.fixture_audit.passed);
end

function testAuditIsReadOnlyAndPreservesABStateAndDirectionFingerprints( ...
        testCase)
result = testCase.TestData.result;
audit = result.read_only_audit;
verifyTrue(testCase,audit.passed);
verifyTrue(testCase,audit.canonical_states_before_exact);
verifyTrue(testCase,audit.canonical_states_after_exact);
verifyTrue(testCase,audit.recursive_directions_exact);
verifyTrue(testCase,audit.linearization_snapshots_exact);
verifyTrue(testCase,audit.state_fingerprints_exact);
verifyTrue(testCase,audit.direction_fingerprints_exact);

chains = {result.ab_result.chain_a,result.ab_result.chain_b};
for c = 1:2
    for k = 1:5
        item = chains{c}.iterations(k);
        verifyEqual(testCase, ...
            local_vector_fingerprint(item.canonical_state_before,true), ...
            string(item.state_fingerprint_before));
        verifyEqual(testCase, ...
            local_vector_fingerprint(item.canonical_state_after,true), ...
            string(item.state_fingerprint_after));
        verifyEqual(testCase, ...
            local_vector_fingerprint( ...
                item.recursive_direction_components,false), ...
            string(item.direction_fingerprint));
        verifyEqual(testCase,item.root_cause_linearization_before.l, ...
            item.canonical_state_before.l,'AbsTol',0);
        verifyEqual(testCase,item.root_cause_linearization_before.z, ...
            item.canonical_state_before.z,'AbsTol',0);
    end
end
verifyEqual(testCase,result.execution.additional_audit_state_update_count,0);
verifyEqual(testCase, ...
    result.execution.additional_audit_newton_direction_count,0);
verifyEqual(testCase, ...
    result.execution.additional_audit_complete_kkt_solve_count,0);
end

function testAllStepCandidatesReconstructIndependentlyFromRawVectors( ...
        testCase)
result = testCase.TestData.result;
tau = result.ab_result.config.fraction_to_boundary;
[chains,~] = chains_and_indices(result);
inventory = result.step_candidate_inventory;
summary = result.step_candidate_summary;
for c = 1:2
    chain = chains{c};
    for k = 1:5
        item = chain.iterations(k);
        for stepKind = ["primal","dual"]
            if stepKind=="primal"
                state = item.canonical_state_before.l;
                direction = item.recursive_direction_components.l;
                official = item.candidate_alpha_primal;
            else
                state = item.canonical_state_before.z;
                direction = item.recursive_direction_components.z;
                official = item.candidate_alpha_dual;
            end
            negative = find(direction<0);
            raw = -state(negative)./direction(negative);
            candidates = min(ones(numel(raw),1),tau*raw);
            [~,order] = sortrows([candidates,negative],[1,2]);
            negative = negative(order);
            raw = raw(order);
            candidates = candidates(order);
            rows = inventory( ...
                inventory.chain_id==chain.diagnostic_chain_id & ...
                inventory.iteration==k & ...
                inventory.step_kind==stepKind,:);
            verifyEqual(testCase,rows.inequality_index,negative);
            verifyEqual(testCase,rows.state_value,state(negative), ...
                'AbsTol',0);
            verifyEqual(testCase,rows.direction_value,direction(negative), ...
                'AbsTol',0);
            verifyEqual(testCase,rows.raw_boundary_ratio,raw,'AbsTol',0);
            verifyEqual(testCase,rows.reconstructed_candidate_alpha, ...
                candidates,'AbsTol',0);
            verifyEqual(testCase,rows.rank,(1:numel(negative)).');
            reconstructed = min(1,tau*min( ...
                -state(direction<0)./direction(direction<0)));
            verifyEqual(testCase,reconstructed,official,'AbsTol',0);

            summaryRow = summary( ...
                summary.chain_id==chain.diagnostic_chain_id & ...
                summary.iteration==k & ...
                summary.step_kind==stepKind,:);
            verifyEqual(testCase,height(summaryRow),1);
            verifyEqual(testCase,summaryRow.candidate_count,numel(negative));
            verifyEqual(testCase, ...
                summaryRow.minimum_candidate_alpha,min(candidates), ...
                'AbsTol',0);
            verifyEqual(testCase, ...
                summaryRow.median_candidate_alpha,median(candidates), ...
                'AbsTol',0);
            verifyEqual(testCase,summaryRow.p95_candidate_alpha, ...
                percentile95(candidates),'AbsTol',0);
            verifyEqual(testCase, ...
                summaryRow.maximum_candidate_alpha,max(candidates), ...
                'AbsTol',0);
            verifyEqual(testCase,summaryRow.within_2x_minimum_count, ...
                nnz(raw<=2*min(raw)));
            verifyEqual(testCase,summaryRow.within_10x_minimum_count, ...
                nnz(raw<=10*min(raw)));
            verifyEqual(testCase,summaryRow.within_100x_minimum_count, ...
                nnz(raw<=100*min(raw)));
            verifyEqual(testCase,summaryRow.concentration_basis, ...
                "raw_boundary_ratio");
            verifyEqual(testCase,summaryRow.reconstructed_global_alpha, ...
                official,'AbsTol',0);
            verifyLessThanOrEqual(testCase, ...
                summaryRow.alpha_closure_scaled_error,2048*eps);
        end
    end
end
verifyEqual(testCase,height(summary),20);
firstPrimal = summary(summary.chain_id=="A4-2C-A" & ...
    summary.iteration==1 & summary.step_kind=="primal",:);
firstDual = summary(summary.chain_id=="A4-2C-A" & ...
    summary.iteration==1 & summary.step_kind=="dual",:);
verifyEqual(testCase,[firstPrimal.within_2x_minimum_count, ...
    firstPrimal.within_10x_minimum_count, ...
    firstPrimal.within_100x_minimum_count],[10,1140,5569]);
verifyEqual(testCase,[firstDual.within_2x_minimum_count, ...
    firstDual.within_10x_minimum_count, ...
    firstDual.within_100x_minimum_count],[10,10,1294]);
end

function testTopTwentyLimitersTraceToCanonicalInequalityIndex(testCase)
result = testCase.TestData.result;
[chains,indices] = chains_and_indices(result);
inventory = result.step_candidate_inventory;
top = result.top20_step_candidates;
for c = 1:2
    inequalities = canonical_inequalities(indices{c});
    for k = 1:5
        for stepKind = ["primal","dual"]
            allRows = inventory( ...
                inventory.chain_id==chains{c}.diagnostic_chain_id & ...
                inventory.iteration==k & ...
                inventory.step_kind==stepKind,:);
            topRows = top(top.chain_id==chains{c}.diagnostic_chain_id & ...
                top.iteration==k & top.step_kind==stepKind,:);
            expectedCount = min(20,height(allRows));
            verifyEqual(testCase,height(topRows),expectedCount);
            verifyEqual(testCase,topRows.rank,(1:expectedCount).');
            verifyEqual(testCase,topRows.inequality_index, ...
                allRows.inequality_index(1:expectedCount));
            metadata = inequalities(topRows.inequality_index,:);
            verifyEqual(testCase,topRows.constraint_global_row, ...
                metadata.global_row);
            verifyEqual(testCase,topRows.constraint_id, ...
                string(metadata.constraint_id));
            verifyEqual(testCase,topRows.constraint_name, ...
                string(metadata.constraint_name));
            verifyEqual(testCase,topRows.day,metadata.day);
            verifyEqual(testCase,topRows.hour,metadata.hour);
            verifyEqual(testCase,topRows.asset_type, ...
                string(metadata.asset_type));
            verifyEqual(testCase,topRows.asset_id,metadata.asset_id);
            verifyEqual(testCase,topRows.unit,string(metadata.unit));
            verifyEqual(testCase,nnz(allRows.is_global_limiter),1);
            verifyTrue(testCase,allRows.is_global_limiter(1));
        end
    end
end

grouped = result.step_candidate_group_summary;
for rowIndex = 1:height(grouped)
    row = grouped(rowIndex,:);
    source = inventory(inventory.chain_id==row.chain_id & ...
        inventory.iteration==row.iteration & ...
        inventory.step_kind==row.step_kind,:);
    values = string(source.(row.group_kind));
    mask = values==row.group_name;
    verifyEqual(testCase,row.candidate_count,nnz(mask));
    verifyEqual(testCase,row.minimum_candidate_alpha, ...
        min(source.reconstructed_candidate_alpha(mask)),'AbsTol',0);
    verifyEqual(testCase,row.minimum_raw_boundary_ratio, ...
        min(source.raw_boundary_ratio(mask)),'AbsTol',0);
    verifyEqual(testCase,row.global_limiter_count, ...
        nnz(source.is_global_limiter(mask)));
end
end

function testInitialDualResidualDecompositionClosesForAllVariablesAndQP5( ...
        testCase)
result = testCase.TestData.result;
item = result.ab_result.chain_a.iterations(1);
snapshot = item.root_cause_linearization_before;
state = item.canonical_state_before;
variables = sortrows(result.index_a.variable_index,"global_index_start");
objective = snapshot.objective_gradient(:);
aTransposeY = snapshot.A.'*state.y;
gTransposeZ = snapshot.G.'*state.z;
reconstructed = objective+aTransposeY+gTransposeZ;
actual = snapshot.r_dual(:);
closure = reconstructed-actual;
scale = max(ones(numel(actual),1),abs(objective)+ ...
    abs(snapshot.A).'*abs(state.y)+ ...
    abs(snapshot.G).'*abs(state.z)+abs(actual));
verifyLessThanOrEqual(testCase,max(abs(closure)./scale),2048*eps);

rows = result.initial_dual_decomposition;
verifyEqual(testCase,rows.variable_global_index, ...
    variables.global_index_start);
verifyEqual(testCase,rows.objective_gradient,objective,'AbsTol',0);
verifyEqual(testCase,rows.a_transpose_y,aTransposeY,'AbsTol',0);
verifyEqual(testCase,rows.g_transpose_z,gTransposeZ,'AbsTol',0);
verifyEqual(testCase,rows.reconstructed_r_dual,reconstructed,'AbsTol',0);
verifyEqual(testCase,rows.actual_r_dual,actual,'AbsTol',0);
verifyEqual(testCase,rows.closure_error,closure,'AbsTol',0);
verifyEqual(testCase,rows.scaled_closure_error, ...
    abs(closure)./scale,'AbsTol',0);

qp5Mask = variables.day==0 & variables.hour==0 & ...
    string(variables.variable_name)=="QP5";
verifyEqual(testCase,nnz(qp5Mask),1);
qIndex = variables.global_index_start(qp5Mask);
qp5 = result.qp5_metadata;
verifyEqual(testCase,qp5.variable_global_index,qIndex);
verifyEqual(testCase,qp5.objective_gradient,objective(qIndex),'AbsTol',0);
verifyEqual(testCase,qp5.a_transpose_y,aTransposeY(qIndex),'AbsTol',0);
verifyEqual(testCase,qp5.g_transpose_z,gTransposeZ(qIndex),'AbsTol',0);
verifyEqual(testCase,qp5.r_dual,actual(qIndex),'AbsTol',0);
verifyLessThanOrEqual(testCase, ...
    qp5.scaled_dual_decomposition_closure,2048*eps);
verifyTrue(testCase,result.dual_decomposition_audit.passed);
end

function testNewtonDirectionEquationsAndQP5CausalChainClose(testCase)
result = testCase.TestData.result;
[chains,indices] = chains_and_indices(result);
tau = result.ab_result.config.fraction_to_boundary;
for c = 1:2
    inequalities = canonical_inequalities(indices{c});
    variables = indices{c}.variable_index;
    qMask = variables.day==0 & variables.hour==0 & ...
        string(variables.variable_name)=="QP5";
    qIndex = variables.global_index_start(qMask);
    lower = find(string(inequalities.constraint_id)== ...
        "INEQ-Q-LOWER-QP5");
    upper = find(string(inequalities.constraint_id)== ...
        "INEQ-Q-UPPER-QP5");
    for k = 1:5
        item = chains{c}.iterations(k);
        snapshot = item.root_cause_linearization_before;
        direction = item.recursive_direction_components;
        verifyEqual(testCase,nnz(snapshot.H),0);
        eqClosure = snapshot.A*direction.xi+snapshot.r_eq;
        eqScale = max(ones(size(eqClosure)), ...
            abs(snapshot.A)*abs(direction.xi)+abs(snapshot.r_eq));
        ineqClosure = snapshot.G*direction.xi+direction.l+ ...
            snapshot.r_ineq;
        ineqScale = max(ones(size(ineqClosure)), ...
            abs(snapshot.G)*abs(direction.xi)+abs(direction.l)+ ...
            abs(snapshot.r_ineq));
        compClosure = snapshot.z.*direction.l+ ...
            snapshot.l.*direction.z+snapshot.r_comp;
        compScale = max(ones(size(compClosure)), ...
            abs(snapshot.z.*direction.l)+ ...
            abs(snapshot.l.*direction.z)+abs(snapshot.r_comp));
        dualClosure = snapshot.H*direction.xi+ ...
            snapshot.A.'*direction.y+snapshot.G.'*direction.z+ ...
            snapshot.r_dual;
        dualScale = max(ones(size(dualClosure)), ...
            abs(snapshot.H)*abs(direction.xi)+ ...
            abs(snapshot.A.')*abs(direction.y)+ ...
            abs(snapshot.G.')*abs(direction.z)+abs(snapshot.r_dual));
        verifyLessThanOrEqual(testCase,max(abs(eqClosure)./eqScale), ...
            2048*eps);
        verifyLessThanOrEqual(testCase,max(abs(ineqClosure)./ineqScale), ...
            2048*eps);
        verifyLessThanOrEqual(testCase,max(abs(compClosure)./compScale), ...
            2048*eps);
        verifyLessThanOrEqual(testCase,max(abs(dualClosure)./dualScale), ...
            2048*eps);

        productionClosure = result.direction_equation_closure( ...
            result.direction_equation_closure.chain_id== ...
                chains{c}.diagnostic_chain_id & ...
            result.direction_equation_closure.iteration==k,:);
        verifyEqual(testCase,height(productionClosure),1);
        verifyLessThanOrEqual(testCase, ...
            productionClosure.maximum_scaled_closure,2048*eps);
        verifyLessThanOrEqual(testCase,item.direction_relative_error,1e-10);
        verifyLessThanOrEqual(testCase, ...
            item.recursive_kkt_relative_residual,1e-10);
        verifyLessThanOrEqual(testCase,item.full_kkt_relative_residual,1e-10);
        verifyTrue(testCase,item.no_full_direction_fallback);
        verifyGreaterThan(testCase,min(item.canonical_state_before.l),0);
        verifyGreaterThan(testCase,min(item.canonical_state_before.z),0);
        verifyGreaterThan(testCase,min(item.canonical_state_after.l),0);
        verifyGreaterThan(testCase,min(item.canonical_state_after.z),0);
        verifyLessThanOrEqual(testCase, ...
            item.residuals_after.physical_inequality_violation, ...
            256*eps*item.residuals_after.physical_inequality_scale);

        for row = [lower,upper]
            causal = result.qp5_causal_chain( ...
                result.qp5_causal_chain.chain_id== ...
                    chains{c}.diagnostic_chain_id & ...
                result.qp5_causal_chain.iteration==k & ...
                result.qp5_causal_chain.inequality_index==row,:);
            verifyEqual(testCase,height(causal),1);
            gDirection = snapshot.G(row,:)*direction.xi;
            dlExpected = -(gDirection+snapshot.r_ineq(row));
            dzExpected = -(snapshot.z(row)*direction.l(row)+ ...
                snapshot.r_comp(row))/snapshot.l(row);
            verifyLessThanOrEqual(testCase, ...
                abs(direction.l(row)-dlExpected)/max([1, ...
                abs(direction.l(row)),abs(dlExpected)]),2048*eps);
            verifyLessThanOrEqual(testCase, ...
                abs(direction.z(row)-dzExpected)/max([1, ...
                abs(direction.z(row)),abs(dzExpected)]),2048*eps);
            verifyEqual(testCase,causal.delta_qp5, ...
                direction.xi(qIndex),'AbsTol',0);
            verifyEqual(testCase,causal.g_delta_xi,gDirection,'AbsTol',0);
            verifyEqual(testCase,causal.delta_l,direction.l(row), ...
                'AbsTol',0);
            verifyEqual(testCase,causal.delta_z,direction.z(row), ...
                'AbsTol',0);
            verifyEqual(testCase,causal.slack_candidate_alpha, ...
                local_candidate(snapshot.l(row),direction.l(row),tau), ...
                'AbsTol',0);
            verifyEqual(testCase,causal.multiplier_candidate_alpha, ...
                local_candidate(snapshot.z(row),direction.z(row),tau), ...
                'AbsTol',0);
            verifyLessThanOrEqual(testCase, ...
                causal.maximum_scaled_closure,2048*eps);
        end
    end
end

first = result.ab_result.chain_a.iterations(1);
snapshot = first.root_cause_linearization_before;
direction = first.recursive_direction_components;
lower = result.qp5_metadata.chain_a_lower_inequality_index;
upper = result.qp5_metadata.chain_a_upper_inequality_index;
verifyEqual(testCase,snapshot.l(lower),98,'AbsTol',0);
verifyEqual(testCase,direction.l(lower),-54093170.124927469, ...
    'AbsTol',0);
verifyEqual(testCase,snapshot.z(upper),1,'AbsTol',0);
verifyEqual(testCase,direction.z(upper),-551971.94261231355, ...
    'AbsTol',0);
verifyEqual(testCase,first.candidate_alpha_primal, ...
    1.8107831316556869e-06,'AbsTol',0);
verifyEqual(testCase,first.candidate_alpha_dual, ...
    1.8107804452336358e-06,'AbsTol',0);
end

function testInitializationCentralityAndScaleCoverageMatchesRawSlices( ...
        testCase)
result = testCase.TestData.result;
item = result.ab_result.chain_a.iterations(1);
snapshot = item.root_cause_linearization_before;
state = item.canonical_state_before;
product = state.l.*state.z;
normalized = product/snapshot.mu;

stateRows = result.initial_state_scale_statistics;
verify_scale_row(testCase,stateRows(stateRows.quantity=="y",:),state.y);
verify_scale_row(testCase,stateRows(stateRows.quantity=="z",:),state.z);
verify_scale_row(testCase,stateRows(stateRows.quantity=="l",:),state.l);
verify_scale_row(testCase,stateRows(stateRows.quantity=="delta_l",:), ...
    item.recursive_direction_components.l);
verify_scale_row(testCase,stateRows(stateRows.quantity=="delta_z",:), ...
    item.recursive_direction_components.z);
verify_scale_row(testCase, ...
    stateRows(stateRows.quantity=="l_times_z",:),product);
verify_scale_row(testCase, ...
    stateRows(stateRows.quantity=="l_times_z_over_mu",:),normalized);

centrality = result.initial_centrality_statistics;
verify_distribution_row(testCase, ...
    centrality(centrality.metric=="l_times_z",:),product);
verify_distribution_row(testCase, ...
    centrality(centrality.metric=="l_times_z_over_mu",:),normalized);
verifyEqual(testCase,height(stateRows),7);

variables = sortrows(result.index_a.variable_index,"global_index_start");
groups = local_primal_groups(variables);
terms = struct( ...
    "objective_gradient",snapshot.objective_gradient(:), ...
    "a_transpose_y",snapshot.A.'*state.y, ...
    "g_transpose_z",snapshot.G.'*state.z, ...
    "r_dual",snapshot.r_dual(:));
rows = result.initial_user_group_scale_statistics;
for rowIndex = 1:height(rows)
    row = rows(rowIndex,:);
    if row.scope=="primal_variable"
        mask = groups==row.group_name;
        sourceValues = terms.(row.quantity);
        values = sourceValues(mask);
    elseif row.quantity=="delta_l"
        values = item.recursive_direction_components.l;
    elseif row.quantity=="delta_z"
        values = item.recursive_direction_components.z;
    elseif row.group_name=="equality_multiplier"
        values = state.y;
    elseif row.group_name=="inequality_multiplier"
        values = state.z;
    else
        values = state.l;
    end
    verify_scale_row(testCase,row,values);
end
expectedGroups = ["global_capacity","daily_capacity_copy","wind", ...
    "solar","hydro","thermal","pch","pdis","soc", ...
    "equality_multiplier","inequality_multiplier","slack"];
verifyEqual(testCase,sort(unique(rows.group_name)), ...
    sort(expectedGroups(:)));
primalExpectedNames = ["global_capacity","daily_capacity_copy","wind", ...
    "solar","hydro","thermal","pch","pdis","soc"];
primalExpectedCounts = [14,98,838,420,672,672,336,336,336];
for k = 1:numel(primalExpectedNames)
    verifyEqual(testCase,nnz(groups==primalExpectedNames(k)), ...
        primalExpectedCounts(k));
end
verifyEqual(testCase,numel(state.y),618);
verifyEqual(testCase,numel(state.l),7248);
verifyEqual(testCase,numel(state.z),7248);

constraints = result.index_a.constraint_index;
equalities = constraints(string(constraints.constraint_type)=="equality",:);
inequalities = canonical_inequalities(result.index_a);
residualRows = result.initial_residual_group_scale_statistics;
for rowIndex = 1:height(residualRows)
    row = residualRows(rowIndex,:);
    if row.scope=="equality_constraint"
        mask = string(equalities.constraint_name)==row.group_name;
        values = snapshot.r_eq(mask);
    else
        mask = string(inequalities.constraint_name)==row.group_name;
        if row.quantity=="delta_l"
            values = item.recursive_direction_components.l(mask);
        elseif row.quantity=="delta_z"
            values = item.recursive_direction_components.z(mask);
        else
            sourceValues = snapshot.(row.quantity);
            values = sourceValues(mask);
        end
    end
    verify_scale_row(testCase,row,values);
end
verifyEqual(testCase,height(residualRows),69);
verifyTrue(testCase,result.scale_audit.passed);
end

function testGovernanceScanAndProtectedArtifactsRemainUnchanged( ...
        testCase)
result = testCase.TestData.result;
before = testCase.TestData.protected_before;
after = testCase.TestData.protected_after;
verifyEqual(testCase,after,before);
scan = scan_stage_a4_forbidden_code( ...
    testCase.TestData.project_root,result.ab_result.config);
verifyEqual(testCase,string(scan.status),repmat("PASS",height(scan),1), ...
    evalc('disp(scan(scan.status~="PASS",:))'));
verifyEqual(testCase,scan.match_count,zeros(height(scan),1));
verifyTrue(testCase,any(contains(scan.check_id,"A42D1")));
verifyFalse(testCase,any(contains(lower(scan.matched_files), ...
    ["tests/","runs/"])));

verifyEqual(testCase,result.stage_id,"stage_A4");
verifyEqual(testCase,result.stage_status,"READY");
verifyEqual(testCase,result.milestone_status,"PASS");
verifyTrue(testCase,result.all_pass);
verifyEqual(testCase,result.execution.baseline_chain_count,2);
verifyEqual(testCase,result.execution.baseline_iterations_per_chain,5);
verifyEqual(testCase,result.execution.baseline_newton_direction_count,10);
verifyEqual(testCase,result.execution.baseline_state_update_count,10);
verifyEqual(testCase, ...
    result.execution.additional_audit_newton_direction_count,0);
verifyEqual(testCase, ...
    result.execution.additional_audit_complete_kkt_solve_count,0);
verifyEqual(testCase,result.execution.additional_audit_state_update_count,0);
verifyFalse(testCase,result.execution.formal_a4_run_created);
verifyFalse(testCase,result.execution.full_ipm_executed);
verifyFalse(testCase,result.execution.optimization_executed);
verifyFalse(testCase,result.execution.parallel_executed);
verifyFalse(testCase,result.execution.formal_step_rule_modified);
verifyFalse(testCase,result.execution.initialization_modified);
verifyFalse(testCase,result.execution.objective_or_model_scale_modified);
verifyFalse(testCase,result.execution.stage_b_entered);
verifyEqual(testCase,result.ab_result.config.fraction_to_boundary, ...
    0.9995,'AbsTol',0);
verifyEqual(testCase, ...
    result.ab_result.config.initialization.centering_sigma,0.1,'AbsTol',0);
verifyFalse(testCase,result.root_cause_conclusion.unique_root_cause_claimed);
verifyFalse(testCase,result.root_cause_conclusion. ...
    pure_equivalent_preconditioning_changes_exact_direction);
verifyTrue(testCase,result.root_cause_conclusion. ...
    objective_unitization_changes_algorithm_path);
verifyTrue(testCase,result.root_cause_conclusion. ...
    dual_initialization_changes_algorithm_path);
verifyEqual(testCase, ...
    result.root_cause_conclusion.next_single_factor_experiment, ...
    "dual_initialization");
end

function baseline = make_baseline_table(iterations)
n = numel(iterations);
iteration = reshape([iterations.iteration],[],1);
alphaPrimal = reshape([iterations.alpha_primal],[],1);
alphaDual = reshape([iterations.alpha_dual],[],1);
primalLimiter = strings(n,1);
dualLimiter = strings(n,1);
numericNames = ["equality_before","equality_after", ...
    "slack_equality_before","slack_equality_after","dual_before", ...
    "dual_after","complementarity_inf_before", ...
    "complementarity_inf_after","gap_before","gap_after", ...
    "minimum_l_after","minimum_z_after","direction_relative_error", ...
    "xi_relative_error","y_relative_error","l_relative_error", ...
    "z_relative_error","recursive_kkt_relative_residual", ...
    "full_kkt_relative_residual"];
values = zeros(n,numel(numericNames));
for k = 1:n
    item = iterations(k);
    primalLimiter(k) = item.primal_step.limiting_constraint_id;
    dualLimiter(k) = item.dual_step.limiting_constraint_id;
    before = item.residuals_before;
    after = item.residuals_after;
    values(k,:) = [before.equality_inf,after.equality_inf, ...
        before.slack_equality_inf,after.slack_equality_inf, ...
        before.dual_inf,after.dual_inf, ...
        before.complementarity_inf,after.complementarity_inf, ...
        before.complementarity_gap,after.complementarity_gap, ...
        after.minimum_l,after.minimum_z,item.direction_relative_error, ...
        item.component_relative_errors.xi, ...
        item.component_relative_errors.y, ...
        item.component_relative_errors.l, ...
        item.component_relative_errors.z, ...
        item.recursive_kkt_relative_residual, ...
        item.full_kkt_relative_residual];
end
baseline = table(iteration,alphaPrimal,alphaDual,primalLimiter, ...
    dualLimiter,values(:,1),values(:,2),values(:,3),values(:,4), ...
    values(:,5),values(:,6),values(:,7),values(:,8),values(:,9), ...
    values(:,10),values(:,11),values(:,12),values(:,13),values(:,14), ...
    values(:,15),values(:,16),values(:,17),values(:,18),values(:,19), ...
    'VariableNames',[{'iteration','alpha_primal','alpha_dual', ...
    'primal_limiter','dual_limiter'},cellstr(numericNames)]);
end

function [chains,indices] = chains_and_indices(result)
chains = {result.ab_result.chain_a,result.ab_result.chain_b};
indices = {result.index_a,result.index_b};
end

function inequalities = canonical_inequalities(index)
constraints = index.constraint_index;
inequalities = constraints( ...
    string(constraints.constraint_type)=="inequality",:);
end

function groups = local_primal_groups(variables)
groups = strings(height(variables),1);
for k = 1:height(variables)
    assetType = string(variables.asset_type(k));
    variableName = string(variables.variable_name(k));
    if variables.day(k)==0 && variables.hour(k)==0
        groups(k) = "global_capacity";
    elseif variables.day(k)>0 && variables.hour(k)==0
        groups(k) = "daily_capacity_copy";
    elseif assetType=="wind"
        groups(k) = "wind";
    elseif assetType=="solar"
        groups(k) = "solar";
    elseif assetType=="hydro"
        groups(k) = "hydro";
    elseif assetType=="thermal"
        groups(k) = "thermal";
    elseif variableName=="Pch"
        groups(k) = "pch";
    elseif variableName=="Pdis"
        groups(k) = "pdis";
    elseif variableName=="SOC"
        groups(k) = "soc";
    else
        error("stageA4:tests:A42D1VariableGroup", ...
            "Canonical variable %d has no independent test group.",k);
    end
end
end

function candidate = local_candidate(value,direction,tau)
if direction<0
    candidate = min(1,tau*(-value/direction));
else
    candidate = 1;
end
end

function verify_scale_row(testCase,row,values)
verifyEqual(testCase,height(row),1);
values = values(:);
absolute = abs(values);
nonzero = absolute(absolute>0);
verifyEqual(testCase,row.count,numel(values));
verifyEqual(testCase,row.nonzero_count,numel(nonzero));
verifyEqual(testCase,row.negative_count,nnz(values<0));
verifyEqual(testCase,row.zero_count,nnz(values==0));
verifyEqual(testCase,row.positive_count,nnz(values>0));
verifyEqual(testCase,row.minimum_value,min(values),'AbsTol',0);
verifyEqual(testCase,row.maximum_value,max(values),'AbsTol',0);
verifyEqual(testCase,row.median_absolute,median(absolute),'AbsTol',0);
verifyEqual(testCase,row.p95_absolute,percentile95(absolute),'AbsTol',0);
verifyEqual(testCase,row.maximum_absolute,max(absolute),'AbsTol',0);
if isempty(nonzero)
    verifyTrue(testCase,isnan(row.minimum_absolute_nonzero));
    verifyTrue(testCase,isnan(row.minimum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.maximum_order_of_magnitude));
    verifyTrue(testCase,isnan(row.order_of_magnitude_span));
else
    minimumOrder = floor(log10(min(nonzero)));
    maximumOrder = floor(log10(max(nonzero)));
    verifyEqual(testCase,row.minimum_absolute_nonzero,min(nonzero), ...
        'AbsTol',0);
    verifyEqual(testCase,row.minimum_order_of_magnitude,minimumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.maximum_order_of_magnitude,maximumOrder, ...
        'AbsTol',0);
    verifyEqual(testCase,row.order_of_magnitude_span, ...
        maximumOrder-minimumOrder,'AbsTol',0);
end
end

function verify_distribution_row(testCase,row,values)
verifyEqual(testCase,height(row),1);
values = values(:);
verifyEqual(testCase,row.count,numel(values));
verifyEqual(testCase,row.minimum,min(values),'AbsTol',0);
verifyEqual(testCase,row.median,median(values),'AbsTol',0);
verifyEqual(testCase,row.p95,percentile95(values),'AbsTol',0);
verifyEqual(testCase,row.maximum,max(values),'AbsTol',0);
verifyEqual(testCase,row.mean,mean(values),'AbsTol',0);
verifyEqual(testCase,row.standard_deviation,std(values,1),'AbsTol',0);
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

function digest = local_vector_fingerprint(value,includeMetadata)
fields = ["xi","y","l","z"];
payload = zeros(0,1);
lengths = zeros(numel(fields),1);
for k = 1:numel(fields)
    vector = value.(fields(k));
    lengths(k) = numel(vector);
    payload = [payload;vector]; %#ok<AGROW>
end
metadata = zeros(0,1);
if includeMetadata
    names = ["iteration_index","state_revision", ...
        "newton_direction_number","completed_newton_direction_count"];
    metadata = zeros(numel(names),1);
    for k = 1:numel(names)
        metadata(k) = value.(names(k));
    end
end
bytes = typecast([lengths;metadata;payload],"uint8");
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
messageDigest.update(typecast(bytes,"int8"));
digestBytes = mod(double(messageDigest.digest()),256);
digest = lower(join(compose("%02x",digestBytes),""));
digest = reshape(digest,1,1);
end

function snapshot = capture_protected_snapshot(projectRoot)
externalLog = "F:\我自己的Markdown\codex运行日志.md";
snapshot = struct( ...
    "current_stage",file_snapshot( ...
        fullfile(projectRoot,"CURRENT_STAGE.md")), ...
    "solver_config",file_snapshot( ...
        fullfile(projectRoot,"config","solver.yaml")), ...
    "formal_initializer",file_snapshot(fullfile(projectRoot,"src", ...
        "model","initialize_stage_a4_state.m")), ...
    "model_tree",tree_inventory(fullfile(projectRoot,"src","model"),true), ...
    "solver_tree",tree_inventory( ...
        fullfile(projectRoot,"src","solver"),true), ...
    "base_parameters_excel",file_snapshot(fullfile(projectRoot, ...
        "inputs","raw","基础参数.xlsx")), ...
    "input_data_excel",file_snapshot(fullfile(projectRoot, ...
        "inputs","raw","输入数据.xlsx")), ...
    "runs_tree",tree_inventory(fullfile(projectRoot,"runs"),false), ...
    "stage_b_tree",tree_inventory( ...
        fullfile(projectRoot,"stages","stage_B"),true), ...
    "external_codex_log",file_snapshot(externalLog));
end

function snapshot = file_snapshot(pathValue)
pathValue = string(pathValue);
if isfile(pathValue)
    info = dir(pathValue);
    snapshot = struct("path",pathValue,"exists",true, ...
        "bytes",double(info.bytes),"modified_datenum",double(info.datenum), ...
        "sha256",snapshot_sha256(pathValue,double(info.bytes)));
else
    snapshot = struct("path",pathValue,"exists",false, ...
        "bytes",NaN,"modified_datenum",NaN,"sha256","");
end
end

function inventory = tree_inventory(rootPath,includeHashes)
rootPath = string(rootPath);
relativePath = strings(0,1);
isDirectory = false(0,1);
bytes = zeros(0,1);
modifiedDatenum = zeros(0,1);
sha256 = strings(0,1);
if isfolder(rootPath)
    entries = dir(fullfile(rootPath,"**","*"));
    entries = entries(~ismember(string({entries.name}),[".",".."]));
    rowCount = numel(entries);
    relativePath = strings(rowCount,1);
    isDirectory = reshape([entries.isdir],[],1);
    bytes = reshape(double([entries.bytes]),[],1);
    modifiedDatenum = reshape(double([entries.datenum]),[],1);
    sha256 = repmat("",rowCount,1);
    for k = 1:rowCount
        absolutePath = fullfile(entries(k).folder,entries(k).name);
        relativePath(k) = replace(extractAfter(string(absolutePath), ...
            strlength(rootPath)+1),'\','/');
        if includeHashes && ~entries(k).isdir
            sha256(k) = snapshot_sha256( ...
                string(absolutePath),double(entries(k).bytes));
        end
    end
end
[relativePath,order] = sort(relativePath);
inventory = table(relativePath,isDirectory(order),bytes(order), ...
    modifiedDatenum(order),sha256(order), ...
    'VariableNames',{'relative_path','is_directory','bytes', ...
    'modified_datenum','sha256'});
end

function digest = snapshot_sha256(pathValue,byteCount)
if byteCount==0
    digest = ...
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
else
    digest = lower(string(compute_sha256_file(pathValue)));
end
end
