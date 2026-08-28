function manifest = persist_stage_b2c_final_matrix_artifacts( ...
        context,ipm,auditMode)
%PERSIST_STAGE_B2C_FINAL_MATRIX_ARTIFACTS Save final shared operators.

% The recursive-only route records H/A/G and the actual 16- or 17-dimensional
% core when it was produced in this invocation.  The seven-day audit route also
% records the independently assembled full KKT matrix and its direction.

arguments
    context (1,1) struct
    ipm (1,1) struct
    auditMode (1,1) string {mustBeMember(auditMode, ...
        ["full_kkt","recursive_only"])}
end
lin = ipm.final_linearization;
sharedPath = fullfile(context.matrices_dir,"final_recursive_operators.mat");
names = ["H_L";"A";"G"];
roles = repmat("recursive_shared",3,1);
matrices = {lin.H;lin.A;lin.G};
paths = repmat("matrices/final_recursive_operators.mat",3,1);

if auditMode=="full_kkt"
    assert(ipm.accepted_iteration_count>0 && ...
        isfield(ipm.last_step,"recursive") && ...
        isfield(ipm.last_step,"full_audit"), ...
        "stageB2C:configured:FinalMatrix", ...
        "The full-KKT route has no accepted final direction to persist.");
    core = ipm.last_step.recursive.core;
    audit = ipm.last_step.full_audit;
    rkkt.artifacts.save_mat_artifact(sharedPath, ...
        recursive_operator_payload(lin,core));
    auditPath = fullfile(context.matrices_dir,"final_full_kkt_audit.mat");
    rkkt.artifacts.save_mat_artifact(auditPath, ...
        "full_kkt_matrix",audit.kkt.matrix, ...
        "full_kkt_rhs",audit.kkt.rhs, ...
        "full_kkt_direction",audit.direction, ...
        "recursive_direction",ipm.last_step.recursive.direction, ...
        "direction_audit",ipm.last_step.direction_audit);
    names = [names;core_artifact_name(core);"full_KKT_audit"];
    roles = [roles;"recursive_formal";"independent_audit_only"];
    matrices = [matrices;{core.matrix};{audit.kkt.matrix}];
    paths = [paths;"matrices/final_recursive_operators.mat"; ...
        "matrices/final_full_kkt_audit.mat"];
else
    hasCore = isfield(ipm,"last_core") && isstruct(ipm.last_core) && ...
        isfield(ipm.last_core,"matrix");
    if hasCore
        core = ipm.last_core;
        rkkt.artifacts.save_mat_artifact(sharedPath, ...
            recursive_operator_payload(lin,core));
        names(end+1,1) = core_artifact_name(core);
        roles(end+1,1) = "recursive_formal";
        matrices{end+1,1} = core.matrix;
        paths(end+1,1) = "matrices/final_recursive_operators.mat";
    else
        rkkt.artifacts.save_mat_artifact(sharedPath, ...
            "H",lin.H,"A",lin.A,"G",lin.G, ...
            "linearization_identity",lin.identity);
    end
end

rowCount = zeros(numel(names),1);
columnCount = zeros(numel(names),1);
nonzeroCount = zeros(numel(names),1);
sha256 = strings(numel(names),1);
for k = 1:numel(names)
    [rowCount(k),columnCount(k)] = size(matrices{k});
    nonzeroCount(k) = nnz(matrices{k});
    sha256(k) = rkkt.data.compute_sha256_file( ...
        fullfile(context.root,paths(k)));
end
manifest = table(repmat(string(context.run_id),numel(names),1), ...
    names,roles,rowCount,columnCount,nonzeroCount,true(numel(names),1), ...
    paths,sha256,repmat(string(lin.identity),numel(names),1), ...
    repmat("PASS",numel(names),1), ...
    'VariableNames',{'run_id','matrix_name','role','row_count', ...
    'column_count','nonzero_count','is_sparse','artifact_path','sha256', ...
    'linearization_identity','status'});
rkkt.artifacts.write_table_csv_17g_atomic( ...
    context.matrix_manifest_path,manifest);
end

function value = core_artifact_name(core)
value = "global_core_"+string(size(core.matrix,1));
end

function payload = recursive_operator_payload(lin,core)
payload = struct("H",lin.H,"A",lin.A,"G",lin.G, ...
    "global_core_matrix",core.matrix, ...
    "global_core_rhs",core.rhs, ...
    "global_core_solution",core.solution, ...
    "linearization_identity",lin.identity);
if isfield(core,"matrix_high")
    payload.global_core_matrix_high = core.matrix_high;
    payload.global_core_matrix_low = core.matrix_low;
    payload.global_core_rhs_high = core.rhs_high;
    payload.global_core_rhs_low = core.rhs_low;
    payload.global_core_solution_high = core.solution_high;
    payload.global_core_solution_low = core.solution_low;
end
end
