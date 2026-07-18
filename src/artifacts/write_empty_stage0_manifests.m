function createdPaths = write_empty_stage0_manifests(runContext)
%WRITE_EMPTY_STAGE0_MANIFESTS Create header-only stage_0 CSV artifacts.
%
% Existing files are never reset or overwritten. This makes repeated calls
% safe after a run has begun collecting real evidence.

    runRoot = resolve_run_root(runContext);
    specifications = manifest_specifications(runRoot);
    createdPaths = strings(0, 1);

    for k = 1:size(specifications, 1)
        targetPath = specifications{k, 1};
        columnNames = specifications{k, 2};
        ensure_parent_directory(targetPath);
        if ~isfile(targetPath)
            emptyTable = cell2table(cell(0, numel(columnNames)), ...
                'VariableNames', columnNames);
            write_table_csv_17g(targetPath, emptyTable);
            createdPaths(end + 1, 1) = string(targetPath); %#ok<AGROW>
        end
    end
end

function runRoot = resolve_run_root(runContext)
    if isstruct(runContext) && isscalar(runContext) && isfield(runContext, 'root')
        runRoot = runContext.root;
    elseif ischar(runContext) || (isstring(runContext) && isscalar(runContext))
        runRoot = char(string(runContext));
    else
        error('stage0:artifacts:InvalidRunContext', ...
            'Expected a run context or run root path.');
    end
    if ~isfolder(runRoot)
        error('stage0:artifacts:RunRootMissing', ...
            'Run root does not exist: %s', runRoot);
    end
end

function specs = manifest_specifications(root)
    specs = {
        fullfile(root, 'environment.csv'), ...
            {'run_id','check_id','name','value','expected','status','evidence','checked_at'}
        fullfile(root, 'input_hashes.csv'), ...
            {'run_id','relative_path','expected_sha256','actual_sha256','status','bytes','checked_at'}
        fullfile(root, 'iterations', 'iteration_summary.csv'), ...
            {'run_id','stage_id','solve_pass','iteration','objective_total','primal_eq_inf','primal_ineq_inf','dual_inf','complementarity_gap','mu','alpha_primal','alpha_dual','accepted_step','wall_time_seconds','status'}
        fullfile(root, 'iterations', 'objective_components.csv'), ...
            {'run_id','solve_pass','iteration','component_id','component_name','raw_value','normalized_value','weight','weighted_value','active'}
        fullfile(root, 'iterations', 'timing.csv'), ...
            {'run_id','solve_pass','iteration','component','day','block_id','worker_id','seconds','included_pool_startup'}
        fullfile(root, 'iterations', 'parallel_tasks.csv'), ...
            {'run_id','task_id','day','block_id','worker_id','started_at','ended_at','seconds','status','error_message'}
        fullfile(root, 'indices', 'variable_index.csv'), ...
            {'run_id','model_contract_version','day','hour','asset_type','asset_id','variable_name','unit','active_flag','fixed_reason','block_id','local_index_start','local_index_end','global_index_start','global_index_end'}
        fullfile(root, 'indices', 'constraint_index.csv'), ...
            {'run_id','constraint_id','constraint_type','day','hour','asset_type','asset_id','constraint_name','active_flag','local_row','global_row','unit'}
        fullfile(root, 'indices', 'fixed_zero_map.csv'), ...
            {'run_id','solve_pass','day','hour','asset_type','asset_id','variable_name','physical_array_index','fixed_value','reason','inequality_status'}
        fullfile(root, 'indices', 'block_index.csv'), ...
            {'run_id','block_id','day','hour_start','hour_end','variable_start','variable_end','equality_start','equality_end','dimension'}
        fullfile(root, 'indices', 'block_dimensions.csv'), ...
            {'run_id','solve_pass','iteration','day','hour','block_id','active_wind','active_solar','n_primal','n_equalities','dimension','fixed_zero_list'}
        fullfile(root, 'indices', 'permutation_map.csv'), ...
            {'run_id','space_name','canonical_index','solver_index','object_type','object_name'}
        fullfile(root, 'indices', 'thermal_mask.csv'), ...
            {'run_id','day','hour','thermal_unit','pmax_mw','threshold_fraction','threshold_mw','pass1_power_mw','mask_on','rule','sha256_group'}
        fullfile(root, 'matrices', 'matrix_manifest.csv'), ...
            {'run_id','solve_pass','iteration','matrix_name','block_id','day','hour_start','hour_end','rows','columns','nnz','row_global_start','row_global_end','column_global_start','column_global_end','symmetry_error','rank_estimate','condition_estimate','inertia_positive','inertia_negative','inertia_zero','storage_format','relative_path','sha256'}
        fullfile(root, 'checkpoints', 'checkpoint_manifest.csv'), ...
            {'run_id','stage_id','solve_pass','iteration','model_contract_version','input_hashes','index_contract_version','solver_version','path','sha256','created_at'}
        fullfile(root, 'issues', 'issue_log.csv'), ...
            {'issue_id','run_id','stage_id','first_seen_iteration','test_id','symptom','error_message','root_cause','proposed_solution','implemented_change','git_commit','regression_test','status','evidence_path'}
        fullfile(root, 'issues', 'decision_log.csv'), ...
            {'decision_id','run_id','stage_id','question','options','decision','decided_by','decided_at','affected_files'}
        fullfile(root, 'acceptance', 'acceptance_results.csv'), ...
            {'test_id','requirement','threshold','actual_value','comparison','status','blocking','evidence_path','checked_at'}
        };
end
