function scope = get_stage_a4_3_code_analyzer_scope( ...
        projectRoot,dependencyClosure)
%GET_STAGE_A4_3_CODE_ANALYZER_SCOPE Freeze the A4-3 analyzer scope.
%
% The formal route depends on a larger legacy closure.  A4-3's blocking
% Code Analyzer gate is intentionally limited to the controlled
% implementation files introduced or changed for this milestone.  All
% other closure files are still hashed and may produce advisory findings;
% they are never silently treated as blocking scope.

arguments
    projectRoot (1,1) string
    dependencyClosure table
end
relative = [ ...
    "src/+rkkt/+workflows/stageA4.m"
    "src/+rkkt/+model/load_stage_a4_3_configuration.m"
    "src/+rkkt/+diagnostics/assert_stage_a4_3_preflight.m"
    "src/+rkkt/+diagnostics/audit_stage_a4_3_forbidden_execution.m"
    "src/+rkkt/+ipm/compute_stage_a4_unitized_metrics.m"
    "src/+rkkt/+diagnostics/evaluate_stage_a4_3_acceptance.m"
    "src/+rkkt/+diagnostics/evaluate_stage_a4_3_physical_audit.m"
    "src/+rkkt/+diagnostics/inspect_stage_a4_environment.m"
    "src/+rkkt/+diagnostics/scan_stage_a4_3_forbidden_code.m"
    "src/+rkkt/+diagnostics/snapshot_stage_a4_historical_runs.m"
    "src/+rkkt/+diagnostics/compare_stage_a4_historical_runs.m"
    "src/+rkkt/+model/build_stage_a4_scaled_objective_linearization.m"
    "src/+rkkt/+ipm/execute_stage_a4_iteration.m"
    "src/+rkkt/+artifacts/compute_stage_a4_checkpoint_state_fingerprint.m"
    "src/+rkkt/+artifacts/export_stage_a4_3_structural_artifacts.m"
    "src/+rkkt/+artifacts/export_stage_a4_result_artifacts.m"
    "src/+rkkt/+artifacts/finalize_stage_a4_3_run.m"
    "src/+rkkt/+artifacts/load_stage_a4_checkpoint.m"
    "src/+rkkt/+artifacts/mark_stage_a4_full_ipm_execution.m"
    "src/+rkkt/+artifacts/prepare_stage_a4_postprocess_resume.m"
    "src/+rkkt/+artifacts/reconcile_stage_a4_uncommitted_transactions.m"
    "src/+rkkt/+artifacts/validate_stage_a4_checkpoint.m"
    "src/+rkkt/+artifacts/write_stage_a4_checkpoint.m"
    "src/+rkkt/+artifacts/compute_stage_a4_checkpoint_input_fingerprint.m"
    "src/+rkkt/+artifacts/normalize_stage_a4_checkpoint_metadata.m"
    "src/+rkkt/+artifacts/write_stage_a4_checkpoint_manifest_atomic.m"
    "src/+rkkt/+artifacts/write_table_csv_17g_atomic.m"
    "src/+rkkt/+reporting/generate_stage_a4_reports.m"
    "src/+rkkt/+reporting/validate_stage_a4_report_set.m"
    "src/+rkkt/+reporting/write_stage_a4_docx.m"
    "src/+rkkt/+ipm/run_stage_a4_full_ipm.m"
    "src/+rkkt/+testing/bind_stage_a4_3_specialty_test_evidence.m"
    "src/+rkkt/+testing/persist_stage_a4_3_static_evidence.m"
    "src/+rkkt/+testing/run_fixed_test_inventory_with_evidence.m"];
required = ["relative_path","sha256","bytes"];
assert(all(ismember(required,string( ...
    dependencyClosure.Properties.VariableNames))), ...
    "stageA4:a43:AnalyzerScopeSchema", ...
    "The dependency closure lacks the fields required to freeze analyzer scope.");
closure = replace(string(dependencyClosure.relative_path),"\","/");
relative = relative(ismember(relative,closure));
assert(~isempty(relative) && ...
    all(isfile(fullfile(projectRoot,replace(relative,"/",filesep)))), ...
    "stageA4:a43:AnalyzerScopeClosure", ...
    "A controlled A4-3 analyzer file is absent from the formal closure.");
absolute = fullfile(projectRoot,replace(relative,"/",filesep));
sha256 = strings(numel(relative),1);
bytes = zeros(numel(relative),1);
for k = 1:numel(relative)
    sha256(k) = lower(string(rkkt.data.compute_sha256_file(absolute(k))));
    info = dir(absolute(k));
    bytes(k) = info.bytes;
end
scope = table(relative,repmat("A4-3 controlled implementation", ...
    numel(relative),1),sha256,bytes,repmat("PASS",numel(relative),1), ...
    'VariableNames',{'relative_path','scope_reason','sha256','bytes', ...
    'status'});
assert(numel(unique(scope.relative_path))==height(scope) && ...
    all(strlength(scope.sha256)==64), ...
    "stageA4:a43:AnalyzerScopeIdentity", ...
    "The A4-3 analyzer scope identity is not unique or hashed.");
end
