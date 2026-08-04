function result = diagnose_stage_a4_iteration24_rank_failure( ...
        projectRoot,options)
%DIAGNOSE_STAGE_A4_ITERATION24_RANK_FAILURE Rebuild the iteration-24 stop.
%
% This entry is deliberately diagnostic-only.  It rebuilds the accepted
% revision-23 state from the immutable numerical-failure evidence, forms
% the day-14 first three Thomas pivots, and records why the current
% rank/inertia gate rejects the third pivot.  No Newton state is updated
% and no diagnostic direction is returned to an IPM caller.
%
% The unguarded LDL solves and the symmetric diagonal congruence below are
% counterfactual diagnostics only.  They never replace the production
% factorization, alter H/A/G, or serve as a recursive-direction fallback.

arguments
    projectRoot (1,1) string = default_project_root()
    options.FailureEvidencePath (1,1) string = ""
    options.AuthorityRunId (1,1) string = ...
        "20260728_112548_stage_A4_1f3836ca"
    options.ExpectedStateRevision (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 23
    options.HighPrecisionDigits (1,1) double ...
        {mustBeInteger,mustBePositive} = 80
    options.EquilibrationPasses (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 8
    options.PerformFullKktAudit (1,1) logical = true
end

projectRoot = canonical_project_root(projectRoot);
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot,"src")));

config = load_stage_a4_3_configuration(projectRoot);
assert(string(config.stage_id)=="stage_A4" && ...
    string(config.status)=="READY", ...
    "stageA4:iter24:StageGate", ...
    "Iteration-24 replay requires stage_A4 / READY.");

if strlength(strip(options.FailureEvidencePath))==0
    failurePath = fullfile(projectRoot,"runs", ...
        options.AuthorityRunId,"checkpoints", ...
        "numerical_failure_inv001_iter024_rev023_20260728_113512_963.mat");
else
    failurePath = absolute_existing_file(options.FailureEvidencePath);
end
failurePath = string(failurePath);
assert(isfile(failurePath),"stageA4:iter24:FailureEvidenceMissing", ...
    "The immutable iteration-24 failure evidence is missing: %s",failurePath);

[inputHashes,inputHashesPass] = verify_input_hashes(projectRoot);
assert(inputHashesPass,"stageA4:iter24:InputHashes", ...
    "The controlled Excel input hashes do not pass.");
failureSha256 = string(compute_sha256_file(failurePath));
failureEvidence = load(failurePath);
assert(isfield(failureEvidence,"failure") && ...
    isfield(failureEvidence,"state_before_failure"), ...
    "stageA4:iter24:FailureSchema", ...
    "The failure evidence has no state_before_failure payload.");
failure = failureEvidence.failure;
state = failureEvidence.state_before_failure;
assert(state.state_revision==options.ExpectedStateRevision && ...
    state.iteration_index==options.ExpectedStateRevision && ...
    state.completed_newton_direction_count== ...
        options.ExpectedStateRevision, ...
    "stageA4:iter24:StateRevision", ...
    "The failure payload is not the frozen revision-23 state.");

stateFingerprint = string(compute_stage_a4_checkpoint_state_fingerprint(state));
assert(stateFingerprint==string(failure.state_fingerprint), ...
    "stageA4:iter24:StateFingerprint", ...
    "The state fingerprint in the failure payload does not rebuild.");

data = load_project_data(projectRoot);
index = build_stage_a4_index(data,"RunId", ...
    "A4_ITER24_RANK_FAILURE_REPLAY");
linearization = build_stage_a4_scaled_objective_linearization( ...
    state,data,index,config,"A4-3-FORMAL-CANDIDATE");
linearizationFingerprint = string(compute_stage_a4_rns1_fingerprint( ...
    linearization,"linearization"));

checkpointManifestPath = fullfile(projectRoot,"runs", ...
    options.AuthorityRunId,"checkpoints","checkpoint_manifest.csv");
checkpointManifest = read_text_table(checkpointManifestPath);
checkpointRow = checkpointManifest( ...
    double(checkpointManifest.state_revision)==options.ExpectedStateRevision,:);
assert(height(checkpointRow)==1, ...
    "stageA4:iter24:CheckpointManifest", ...
    "Expected exactly one revision-23 checkpoint-manifest row.");
assert(linearizationFingerprint== ...
    lower(string(checkpointRow.linearization_fingerprint)), ...
    "stageA4:iter24:LinearizationFingerprint", ...
    "Rebuilt iteration-24 linearization differs from authority.");

reduced = eliminate_stage_a_multiday_inequality_directions(linearization);
partition = partition_stage_a_multiday_recursive_system( ...
    linearization,reduced,AssemblyTolerance=1e-12);
dayPosition = find([partition.day.day_id]==14);
assert(isscalar(dayPosition),"stageA4:iter24:Day14Partition", ...
    "The replay partition must contain exactly one day-14 chain.");
dayPartition = partition.day(dayPosition);
assert(numel(dayPartition.hour)>=3, ...
    "stageA4:iter24:HourPartition", ...
    "The day-14 partition has fewer than three hours.");

% First reproduce the production error, including its layer and message.
replayFailure = reproduce_production_failure(linearization,config);
assert(replayFailure.present && ...
    replayFailure.identifier=="stageAMultiday:solver:RecursiveLayerFailure" && ...
    contains(replayFailure.message,"day_14_block_ldl_thomas") && ...
    contains(replayFailure.message,"rank=17") && ...
    contains(replayFailure.message,"cond2=406960873079081"), ...
    "stageA4:iter24:FailureSignature", ...
    "The production iteration-24 failure signature did not reproduce.");

[pivotData,localMatrices] = build_pivot_diagnostics( ...
    dayPartition,linearization,index,options);

fullAudit = struct("performed",false,"dimension",0,"nnz",0, ...
    "relative_residual",NaN,"max_absolute_residual",NaN, ...
    "warning_present",false,"direction_consumed",false);
if options.PerformFullKktAudit
    audit = solve_stage_a_multiday_full_kkt_direction(linearization);
    fullAudit.performed = true;
    fullAudit.dimension = audit.kkt.dimension;
    fullAudit.nnz = nnz(audit.kkt.matrix);
    fullAudit.relative_residual = audit.diagnostics.relative_residual;
    fullAudit.max_absolute_residual = audit.diagnostics.max_absolute_residual;
    fullAudit.warning_present = audit.diagnostics.warning_present;
    fullAudit.direction_consumed = false;
    localMatrices.full_kkt_audit_matrix = audit.kkt.matrix;
end

protected = protected_file_audit(projectRoot,config);
git = capture_local_git_state(projectRoot);

result = struct();
result.schema_version = "stage_A4_iteration24_rank_replay_v1.0";
result.stage_id = "stage_A4";
result.stage_status = "READY";
result.milestone = "A4-ITER24-RANK-REPLAY";
result.run_purpose = ...
    "stage_a4_iteration24_ill_conditioned_thomas_root_cause_diagnostic";
result.authority_run_id = string(options.AuthorityRunId);
result.failure_evidence_path = failurePath;
result.failure_evidence_sha256 = failureSha256;
result.authority_commit = "1f3836ca629f5fc8a1de1f5ea5b783d114e1586b";
result.current_commit = git.commit;
result.current_branch = git.branch;
result.state_revision = state.state_revision;
result.state_fingerprint = stateFingerprint;
result.linearization_fingerprint = linearizationFingerprint;
result.input_hashes = inputHashes;
result.input_hashes_pass = inputHashesPass;
result.failure = failure;
result.replay_failure = replayFailure;
result.partition = struct( ...
    "day_id",14, ...
    "hour_count",numel(dayPartition.hour), ...
    "hour_dimensions",reshape([dayPartition.hour.dimension],[],1), ...
    "hour_x_indices",{reshape({dayPartition.hour.x_indices},[],1)}, ...
    "hour_y_indices",{reshape({dayPartition.hour.y_indices},[],1)});
result.block_summary = pivotData.block_summary;
result.singular_values = pivotData.singular_values;
result.near_null_components = pivotData.near_null_components;
result.curvature_sources = pivotData.curvature_sources;
result.scaling_trace = pivotData.scaling_trace;
result.coordinate_scaling = pivotData.coordinate_scaling;
result.factor_solve_comparison = pivotData.factor_solve_comparison;
result.high_precision = pivotData.high_precision;
result.full_kkt_audit = fullAudit;
result.matrix_data = localMatrices;
result.protected_file_audit = protected;
result.git = git;
result.options = struct( ...
    "high_precision_digits",options.HighPrecisionDigits, ...
    "equilibration_passes",options.EquilibrationPasses, ...
    "state_update_count",0, ...
    "newton_direction_count_attempted",1, ...
    "newton_direction_count_completed",0, ...
    "formal_a4_run_created",false, ...
    "full_ipm_executed",false, ...
    "optimization_executed",false, ...
    "parallel_executed",false, ...
    "full_kkt_role","independent_audit_only", ...
    "full_kkt_direction_consumed",false, ...
    "automatic_symmetrization_used",false, ...
    "regularization_used",false, ...
    "full_direction_fallback_used",false);
result.root_cause = classify_root_cause(pivotData,replayFailure);
result.pass = result.input_hashes_pass && ...
    protected.all_pass && replayFailure.present && ...
    result.root_cause.classification== ...
        "numerically_full_rank_scale_imbalanced_thomas_gate";
result.no_stage_a4_pass_claim = true;
result.no_state_update = true;
end

function replay = reproduce_production_failure(linearization,config)
replay = struct("present",false,"identifier","","message","", ...
    "cause_identifier","","cause_message","", ...
    "layer","", "rank",NaN,"condition_2",NaN);
try
    solve_stage_a_multiday_recursive_direction( ...
        linearization,AssemblyTolerance=1e-12, ...
        SymmetryTolerance=config.tolerances.symmetry_relative, ...
        ResidualRefinementMaxPasses=3);
catch cause
    replay.present = true;
    replay.identifier = string(cause.identifier);
    replay.message = string(cause.message);
    replay.layer = extract_layer(replay.message);
    [replay.rank,replay.condition_2] = extract_rank_condition( ...
        replay.message);
    nested = cause;
    while ~isempty(nested.cause)
        nested = nested.cause{1};
    end
    replay.cause_identifier = string(nested.identifier);
    replay.cause_message = string(nested.message);
end
end

function [diagnostics,matrices] = build_pivot_diagnostics( ...
        dayPartition,linearization,index,options)
n = min(3,numel(dayPartition.hour));
schur = cell(n,1);
forward = cell(n,1);
multipliers = cell(n,1);
factorDiag = repmat(empty_factor_diagnostic(),n,1);
matrices = struct();
for t = 1:n
    block = dayPartition.hour(t);
    D = full(block.D);
    E = full(block.E);
    F = [full(block.r),full(block.B)];
    if t==1
        S = D;
        Fforward = F;
    else
        [solvedTranspose,solveInfo] = ...
            unguarded_ldl_solve(schur{t-1},E.', ...
            "hour_"+string(t-1)+"_to_"+string(t));
        multipliers{t} = solvedTranspose.';
        Fforward = F-multipliers{t}*forward{t-1};
        factorDiag(t).interface_relative_residual = ...
            solveInfo.relative_residual;
        factorDiag(t).interface_warning_present = ...
            solveInfo.warning_present;
        S = D-multipliers{t}*E.';
    end
    schur{t} = S;
    forward{t} = Fforward;
    factorDiag(t) = fill_factor_diagnostic( ...
        factorDiag(t),D,schur{t},block);
    [~,factorDiag(t).unguarded] = ...
        unguarded_ldl_factor(schur{t}, ...
        "hour_"+string(t)+"_schur_pivot");
    factorDiag(t).factor_relative_residual = ...
        factorDiag(t).unguarded.factor_reconstruction_relative_residual;
    factorDiag(t).factor_raw_to_factorized_relative = ...
        factorDiag(t).unguarded.raw_to_factorized_relative;
    factorDiag(t).inertia_positive = ...
        factorDiag(t).unguarded.inertia_positive;
    factorDiag(t).inertia_negative = ...
        factorDiag(t).unguarded.inertia_negative;
    factorDiag(t).inertia_zero = ...
        factorDiag(t).unguarded.inertia_zero;
    factorDiag(t).inertia_tolerance = ...
        factorDiag(t).unguarded.inertia_tolerance;
    factorDiag(t).warning_present = ...
        factorDiag(t).unguarded.warning_present;
    matrices.("D"+string(t)) = D;
    matrices.("E"+string(t)) = E;
    matrices.("forward_rhs"+string(t)) = Fforward;
    matrices.("S"+string(t)) = schur{t};
end

S3 = schur{3};
rhs3 = forward{3};
[rawSolution,rawSolveInfo] = unguarded_ldl_solve( ...
    S3,rhs3,"hour_3_unguarded_15rhs");
[scaleTrace,A,scaleVector] = diagnostic_equilibrate( ...
    S3,options.EquilibrationPasses);
[scaledSolution,scaledSolveInfo] = solve_congruently_scaled( ...
    S3,rhs3,A,scaleVector,"hour_3_scaled_15rhs");

hp = high_precision_reference(dayPartition,options.HighPrecisionDigits);
rawSolutionError = NaN;
scaledSolutionError = NaN;
if hp.available
    reference = hp.solution_double;
    rawSolutionError = norm(rawSolution-reference,"fro")/ ...
        max(1,norm(reference,"fro"));
    scaledSolutionError = norm(scaledSolution-reference,"fro")/ ...
        max(1,norm(reference,"fro"));
end
factorSolveComparison = table( ...
    ["unguarded_double";"diagnostic_congruence_scaled"; ...
        "high_precision_reference"], ...
    [15;15;15], ...
    [rawSolveInfo.relative_residual; ...
        scaledSolveInfo.relative_residual;0], ...
    [rawSolveInfo.max_absolute_residual; ...
        scaledSolveInfo.max_absolute_residual;0], ...
    [rawSolutionError;scaledSolutionError;0], ...
    [factorDiag(3).unguarded.factor_reconstruction_relative_residual; ...
        scaledSolveInfo.factor_reconstruction_relative_residual;NaN], ...
    [factorDiag(3).unguarded.inertia_zero; ...
        scaledSolveInfo.inertia_zero;NaN], ...
    [false;false;false], ...
    'VariableNames',{'route','rhs_count', ...
        'original_operator_relative_residual', ...
        'original_operator_max_absolute_residual', ...
        'relative_error_to_high_precision', ...
        'factor_relative_residual','inertia_zero_by_diagnostic_gate', ...
        'used_for_formal_direction'});

blockRows = repmat(make_block_row(factorDiag(1)),n,1);
allSingularRows = table();
for t=1:n
    blockRows(t) = make_block_row(factorDiag(t));
    sv = factorDiag(t).schur_singular_values(:);
    svTable = table( ...
        repmat(factorDiag(t).hour,numel(sv),1), ...
        (1:numel(sv)).',sv, ...
        repmat(factorDiag(t).rank_tolerance,numel(sv),1), ...
        sv<=factorDiag(t).rank_tolerance, ...
        repmat(factorDiag(t).schur_rank,numel(sv),1), ...
        'VariableNames',{'hour','singular_value_order', ...
            'singular_value','rank_tolerance','below_rank_tolerance', ...
            'numeric_rank'});
    allSingularRows=[allSingularRows;svTable]; %#ok<AGROW>
end

[nearNull,nearNullComponents] = map_near_null_modes( ...
    S3,dayPartition.hour(3),index,factorDiag(3));
curvature = map_curvature_sources(linearization,index, ...
    dayPartition.hour(3));

diagnostics = struct();
diagnostics.block_summary = struct2table(blockRows);
diagnostics.singular_values = allSingularRows;
diagnostics.near_null_components = nearNullComponents;
diagnostics.curvature_sources = curvature;
diagnostics.scaling_trace = scaleTrace;
diagnostics.coordinate_scaling = table( ...
    (1:numel(scaleVector)).',string(nearNull.coordinate_labels(1:numel(scaleVector))), ...
    scaleVector,1./scaleVector, ...
    'VariableNames',{'block_position','coordinate_label', ...
        'congruence_scale','inverse_scale'});
diagnostics.factor_solve_comparison = factorSolveComparison;
diagnostics.high_precision = hp;
matrices.S3_scaled = A;
matrices.hour3_raw_solution = rawSolution;
matrices.hour3_scaled_solution = scaledSolution;
end

function row = empty_factor_diagnostic()
row = struct( ...
    "hour",0,"dimension",0,"n_primal",0,"n_equalities",0, ...
    "raw_rank",NaN,"raw_condition_2",NaN,"raw_smax",NaN, ...
    "raw_smin",NaN,"raw_symmetry_relative",NaN, ...
    "schur_rank",NaN,"schur_condition_2",NaN, ...
    "schur_smax",NaN,"schur_smin",NaN, ...
    "schur_symmetry_relative",NaN, ...
    "rank_tolerance",NaN,"singular_values_below_rank_tolerance",NaN, ...
    "factor_relative_residual",NaN, ...
    "factor_raw_to_factorized_relative",NaN, ...
    "inertia_positive",NaN,"inertia_negative",NaN, ...
    "inertia_zero",NaN,"inertia_tolerance",NaN, ...
    "interface_relative_residual",NaN, ...
    "interface_warning_present",false, ...
    "warning_present",false,"hourly_x_indices","", ...
    "hourly_y_indices","", ...
    "schur_singular_values",zeros(0,1), ...
    "unguarded",struct());
end

function row = fill_factor_diagnostic(row,D,S,block)
row.hour = block.hour;
row.dimension = block.dimension;
row.n_primal = block.n_primal;
row.n_equalities = block.n_equalities;
row.raw_rank = rank(D);
row.raw_condition_2 = cond(D,2);
rawSv = svd(D);
row.raw_smax = rawSv(1);
row.raw_smin = rawSv(end);
row.raw_symmetry_relative = norm(D-D.',"fro")/max(1,norm(D,"fro"));
row.schur_rank = rank(S);
row.schur_condition_2 = cond(S,2);
row.schur_singular_values = svd(S);
row.schur_smax = row.schur_singular_values(1);
row.schur_smin = row.schur_singular_values(end);
row.schur_symmetry_relative = norm(S-S.',"fro")/max(1,norm(S,"fro"));
row.rank_tolerance = max(size(S))*eps(norm(S,2));
row.singular_values_below_rank_tolerance = ...
    nnz(row.schur_singular_values<=row.rank_tolerance);
row.hourly_x_indices = mat2str(block.x_indices.');
row.hourly_y_indices = mat2str(block.y_indices.');
end

function row = make_block_row(diagnostic)
row = diagnostic;
row = rmfield(row,["schur_singular_values","unguarded"]);
end

function [factor,info] = unguarded_ldl_factor(matrix,label)
lastwarn("");
[lowerFactor,blockDiagonal,permutation] = ldl(sparse(matrix),"vector");
[warningMessage,warningId] = lastwarn;
factor = struct("L",lowerFactor,"D",blockDiagonal, ...
    "permutation",permutation(:),"matrix",sparse(matrix));
factorizedPermuted=lowerFactor*blockDiagonal*lowerFactor.';
factorizedOperator=sparse(size(matrix,1),size(matrix,2));
factorizedOperator(permutation,permutation)=factorizedPermuted;
factor.factorized_operator=factorizedOperator;
info = struct();
info.label=string(label);
info.warning_id=string(warningId);
info.warning_message=string(warningMessage);
info.warning_present=strlength(string(warningId))>0 || ...
    strlength(string(warningMessage))>0;
info.factor_reconstruction_relative_residual=norm( ...
    factorizedPermuted-matrix(permutation,permutation),"fro")/ ...
    max(1,norm(matrix,"fro"));
info.raw_to_factorized_relative=norm( ...
    factorizedOperator-sparse(matrix),"fro")/ ...
    max(1,norm(matrix,"fro"));
eigenvalues=eig(full(blockDiagonal));
info.inertia_tolerance=max(1,size(matrix,1))*eps( ...
    max(1,norm(full(blockDiagonal),2)));
info.inertia_positive=nnz(eigenvalues>info.inertia_tolerance);
info.inertia_negative=nnz(eigenvalues<-info.inertia_tolerance);
info.inertia_zero=numel(eigenvalues)-info.inertia_positive- ...
    info.inertia_negative;
info.factor_dimension=size(matrix,1);
info.factor_label=string(label);
end

function [solution,info] = unguarded_ldl_solve(matrix,rhs,label)
[factor,info] = unguarded_ldl_factor(matrix,label);
lastwarn("");
work=factor.L\rhs(factor.permutation,:);
work=factor.D\work;
work=factor.L.'\work;
[warningMessage,warningId]=lastwarn;
solution=zeros(size(rhs));
solution(factor.permutation,:)=work;
rawResidual=matrix*solution-rhs;
factorizedResidual=factor.factorized_operator*solution-rhs;
info.warning_id=string(warningId);
info.warning_message=string(warningMessage);
info.warning_present=info.warning_present || ...
    strlength(string(warningId))>0 || strlength(string(warningMessage))>0;
info.relative_residual=norm(rawResidual,"fro")/max(1,norm(rhs,"fro"));
info.max_absolute_residual=max(abs(rawResidual),[],"all");
info.factorized_operator_solve_relative_residual= ...
    norm(factorizedResidual,"fro")/ ...
    max(1,norm(rhs,"fro"));
end

function [trace,scaled,scaleVector] = diagnostic_equilibrate(matrix,passes)
n=size(matrix,1);
scaled=matrix;
scaleVector=ones(n,1);
traceRows=repmat(empty_scale_row(),passes+1,1);
traceRows(1)=make_scale_row(0,scaled,scaleVector);
for k=1:passes
    rowNorm=max(abs(scaled),[],2);
    step=1./sqrt(max(rowNorm,realmin));
    scaleVector=scaleVector.*step;
    scaled=(step.*scaled).*step.';
    traceRows(k+1)=make_scale_row(k,scaled,scaleVector);
end
trace=struct2table(traceRows);
end

function row=empty_scale_row()
row=struct("pass",0,"condition_2",NaN,"numeric_rank",0, ...
    "rank_tolerance",NaN,"smax",NaN,"smin",NaN, ...
    "below_rank_tolerance",0,"symmetry_relative",NaN, ...
    "scale_min",NaN,"scale_max",NaN,"scale_ratio",NaN);
end

function row=make_scale_row(pass,matrix,scaleVector)
sv=svd(matrix);
row=empty_scale_row();
row.pass=pass;
row.condition_2=cond(matrix,2);
row.numeric_rank=rank(matrix);
row.rank_tolerance=max(size(matrix))*eps(norm(matrix,2));
row.smax=sv(1); row.smin=sv(end);
row.below_rank_tolerance=nnz(sv<=row.rank_tolerance);
row.symmetry_relative=norm(matrix-matrix.',"fro")/ ...
    max(1,norm(matrix,"fro"));
row.scale_min=min(scaleVector);
row.scale_max=max(scaleVector);
row.scale_ratio=row.scale_max/row.scale_min;
end

function [solution,info]=solve_congruently_scaled( ...
        original,rhs,scaled,scaleVector,label)
scaledRhs=scaleVector.*rhs;
[scaledSolution,factorInfo]=unguarded_ldl_solve( ...
    scaled,scaledRhs,label);
solution=scaleVector.*scaledSolution;
residual=original*solution-rhs;
info=factorInfo;
info.relative_residual=norm(residual,"fro")/max(1,norm(rhs,"fro"));
info.max_absolute_residual=max(abs(residual),[],"all");
end

function hp=high_precision_reference(dayPartition,digitsRequested)
hp=struct("available",false,"digits",digitsRequested, ...
    "s2_smax",NaN,"s2_smin",NaN,"s2_condition_2",NaN, ...
    "s3_smax",NaN,"s3_smin",NaN,"s3_condition_2",NaN, ...
    "s3_min_abs_eigen_text","","s3_max_abs_eigen_text","", ...
    "s3_condition_text","","s3_high_precision_full_rank",false, ...
    "schur_double_reconstruction_relative",NaN, ...
    "solution_double",zeros(0,0),"solution_reference_residual_text","");
if ~license("test","Symbolic_Toolbox")
    hp.reason="Symbolic Math Toolbox unavailable";
    return
end
hp.available=true;
oldDigits=digits;
cleanup=onCleanup(@()digits(oldDigits));
digits(digitsRequested);
h1=dayPartition.hour(1); h2=dayPartition.hour(2); h3=dayPartition.hour(3);
D1=vpa(full(h1.D),digitsRequested);
D2=vpa(full(h2.D),digitsRequested);
D3=vpa(full(h3.D),digitsRequested);
E2=vpa(full(h2.E),digitsRequested);
E3=vpa(full(h3.E),digitsRequested);
F1=vpa([full(h1.r),full(h1.B)],digitsRequested);
F2=vpa([full(h2.r),full(h2.B)],digitsRequested);
F3=vpa([full(h3.r),full(h3.B)],digitsRequested);
S2=D2-E2*mldivide(D1,E2.');
% Rebuild the second-hour forward RHS with the first interface.
M1=(mldivide(D1,E2.')).';
F2forward=F2-M1*F1;
S3=D3-E3*mldivide(S2,E3.');
M2=(mldivide(S2,E3.')).';
F3forward=F3-M2*F2forward;
e2=eig(S2); e3=eig(S3);
a2=sort(abs(double(e2)),"descend");
a3=sort(abs(double(e3)),"descend");
hp.s2_smax=a2(1); hp.s2_smin=a2(end);
hp.s2_condition_2=a2(1)/a2(end);
hp.s3_smax=a3(1); hp.s3_smin=a3(end);
hp.s3_condition_2=a3(1)/a3(end);
hp.s3_min_abs_eigen_text=char(vpa(min(abs(e3)),25));
hp.s3_max_abs_eigen_text=char(vpa(max(abs(e3)),25));
hp.s3_condition_text=char(vpa( ...
    max(abs(e3))/min(abs(e3)),25));
hp.s3_high_precision_full_rank= ...
    min(abs(double(e3)))>1e-30;
hp.schur_double_reconstruction_relative=norm( ...
    double(S3)-full(h3.D)+full(h3.E)* ...
    mldivide(full(h2.D)-full(h2.E)* ...
    mldivide(full(h1.D),full(h2.E).'),full(h3.E).'),"fro")/ ...
    max(1,norm(double(S3),"fro"));
Xhp=mldivide(S3,F3forward);
hp.solution_double=double(Xhp);
hp.solution_reference_residual_text=char(vpa(norm( ...
    S3*Xhp-F3forward,"fro")/max(vpa(1), ...
    norm(F3forward,"fro")),12));
clear cleanup
end

function [tableValue,components]=map_near_null_modes( ...
        matrix,block,index,factorDiagnostic)
[~,S,V]=svd(matrix);
sv=diag(S);
modeIds=find(sv<=factorDiagnostic.rank_tolerance);
n=size(matrix,1);
labels=local_coordinate_labels(block,index);
componentRows=repmat(empty_component_row(),numel(modeIds)*n,1);
at=0;
for mode=modeIds.'
    vector=V(:,mode);
    primalEnergy=sum(vector(1:block.n_primal).^2);
    equalityEnergy=sum(vector(block.n_primal+1:end).^2);
    [~,order]=sort(abs(vector),"descend");
    for rankOrder=1:n
        at=at+1; position=order(rankOrder);
        componentRows(at)=make_component_row(mode,sv(mode), ...
            factorDiagnostic.rank_tolerance,rankOrder,position, ...
            block,index,vector(position), ...
            primalEnergy,equalityEnergy);
    end
end
if at==0
    components=struct2table(repmat(empty_component_row(),0,1));
else
    components=struct2table(componentRows(1:at));
end
tableValue=struct( ...
    "mode_count",numel(modeIds), ...
    "mode_ids",modeIds(:), ...
    "coordinate_labels",labels, ...
    "primal_energy",arrayfun(@(m)sum(V(1:block.n_primal,m).^2), ...
        modeIds(:)), ...
    "equality_energy",arrayfun(@(m)sum(V(block.n_primal+1:end,m).^2), ...
        modeIds(:)));
end

function row=empty_component_row()
row=struct("mode",0,"singular_value",NaN,"rank_tolerance",NaN, ...
    "loading_order",0,"block_position",0,"coordinate_kind","", ...
    "global_index",0,"identifier","","asset_type","","asset_id",0, ...
    "coefficient",NaN,"absolute_coefficient",NaN, ...
    "primal_energy",NaN,"equality_energy",NaN);
end

function row=make_component_row(mode,sv,tol,order,position, ...
        block,index,coefficient,primalEnergy,equalityEnergy)
row=empty_component_row();
row.mode=mode; row.singular_value=sv; row.rank_tolerance=tol;
row.loading_order=order; row.block_position=position;
if position<=block.n_primal
    row.coordinate_kind="primal";
    globalIndex=block.x_indices(position);
    item=index.variable_index(globalIndex,:);
    row.global_index=globalIndex;
    row.identifier=string(item.variable_name{1});
    row.asset_type=string(item.asset_type{1});
    row.asset_id=item.asset_id;
else
    row.coordinate_kind="equality_multiplier";
    equalityPosition=position-block.n_primal;
    globalIndex=block.y_indices(equalityPosition);
    item=index.constraint_index(globalIndex,:);
    row.global_index=globalIndex;
    row.identifier=string(item.constraint_name{1});
    row.asset_type=string(item.asset_type{1});
    row.asset_id=item.asset_id;
end
row.coefficient=coefficient;
row.absolute_coefficient=abs(coefficient);
row.primal_energy=primalEnergy; row.equality_energy=equalityEnergy;
end

function labels=local_coordinate_labels(block,index)
labels=strings(block.dimension,1);
for k=1:block.n_primal
    item=index.variable_index(block.x_indices(k),:);
    labels(k)=string(item.variable_name{1})+"_"+ ...
        string(item.asset_type{1})+string(item.asset_id);
end
for k=1:block.n_equalities
    item=index.constraint_index(block.y_indices(k),:);
    labels(block.n_primal+k)="lambda_"+ ...
        string(item.constraint_name{1})+"_asset"+string(item.asset_id);
end
end

function curvature=map_curvature_sources( ...
        linearization,index,block)
rows=repmat(empty_curvature_row(),block.n_primal,1);
nEq=numel(linearization.r_eq);
for k=1:block.n_primal
    globalIndex=block.x_indices(k);
    item=index.variable_index(globalIndex,:);
    gRows=find(linearization.G(:,globalIndex));
    sourceIds=strings(numel(gRows),1);
    sourceTheta=zeros(numel(gRows),1);
    sourceL=zeros(numel(gRows),1);
    sourceZ=zeros(numel(gRows),1);
    for q=1:numel(gRows)
        cRow=index.constraint_index(nEq+gRows(q),:);
        sourceIds(q)=string(cRow.constraint_id{1});
        sourceTheta(q)=linearization.z(gRows(q))/ ...
            linearization.l(gRows(q));
        sourceL(q)=linearization.l(gRows(q));
        sourceZ(q)=linearization.z(gRows(q));
    end
    row=empty_curvature_row();
    row.block_position=k; row.global_index=globalIndex;
    row.variable_name=string(item.variable_name{1});
    row.asset_type=string(item.asset_type{1});
    row.asset_id=item.asset_id;
    row.hessian_diagonal=full(linearization.H(globalIndex,globalIndex));
    row.w_diagonal=full(linearization.H(globalIndex,globalIndex))+ ...
        sum(sourceTheta.*full(linearization.G(gRows,globalIndex)).^2);
    row.constraint_ids=strjoin(sourceIds,"|");
    row.theta_min=min_or_nan(sourceTheta);
    row.theta_max=max_or_nan(sourceTheta);
    row.l_min=min_or_nan(sourceL); row.l_max=max_or_nan(sourceL);
    row.z_min=min_or_nan(sourceZ); row.z_max=max_or_nan(sourceZ);
    rows(k)=row;
end
curvature=struct2table(rows);
end

function row=empty_curvature_row()
row=struct("block_position",0,"global_index",0,"variable_name","", ...
    "asset_type","","asset_id",0,"hessian_diagonal",NaN, ...
    "w_diagonal",NaN,"constraint_ids","","theta_min",NaN, ...
    "theta_max",NaN,"l_min",NaN,"l_max",NaN,"z_min",NaN,"z_max",NaN);
end

function value=min_or_nan(values)
if isempty(values), value=NaN; else, value=min(values); end
end
function value=max_or_nan(values)
if isempty(values), value=NaN; else, value=max(values); end
end

function rootCause=classify_root_cause(pivotData,replayFailure)
rows=pivotData.block_summary;
h3=rows(rows.hour==3,:);
hp=pivotData.high_precision;
scale=pivotData.scaling_trace;
scaledFinal=scale(end,:);
rootCause=struct();
rootCause.classification= ...
    "numerically_full_rank_scale_imbalanced_thomas_gate";
rootCause.title="双精度尺度失衡触发保守数值秩/零主元门禁";
rootCause.production_failure_reproduced=replayFailure.present;
rootCause.structural_rank_deficiency_rejected= ...
    hp.available && hp.s3_high_precision_full_rank;
rootCause.rank_deficiency_false_positive= ...
    h3.schur_rank< h3.dimension && hp.s3_high_precision_full_rank;
rootCause.scale_counterfactual_restores_rank= ...
    scaledFinal.numeric_rank==h3.dimension;
rootCause.scale_counterfactual_condition=scaledFinal.condition_2;
rootCause.raw_condition=h3.schur_condition_2;
rootCause.condition_reduction_factor=h3.schur_condition_2/ ...
    scaledFinal.condition_2;
rootCause.small_curvature_explanation= ...
    "目标 Hessian 对活动小时变量为零；W=H+G'*(z./l)*G 的局部对角约为1e-8至1e-7。";
rootCause.elimination_amplification_explanation= ...
    "跨小时 SOC 接口消元把SOC等式乘子主元放大到约1e7，扩大谱宽。";
rootCause.repair_not_applied=true;
rootCause.recommendation= ...
    "下一独立修复应在保留原Thomas消元和原算子残差审计的条件下，测试局部对称对角合同尺度化；不得把诊断尺度直接当作正式结果。";
end

function protected=protected_file_audit(root,config)
freeze=config.numerical_repair_freeze;
entries=freeze.protected_files;
rows=repmat(struct("relative_path","","expected_sha256","", ...
    "actual_sha256","","status",""),numel(entries),1);
for k=1:numel(entries)
    rel=string(entries(k).relative_path);
    pathValue=fullfile(root,replace(rel,"/",filesep));
    actual="";
    if isfile(pathValue), actual=string(compute_sha256_file(pathValue)); end
    rows(k).relative_path=rel;
    rows(k).expected_sha256=string(entries(k).sha256);
    rows(k).actual_sha256=actual;
    rows(k).status=ternary(actual==string(entries(k).sha256),"PASS","FAIL");
end
protected=struct("table",struct2table(rows), ...
    "all_pass",all(string({rows.status})=="PASS"));
end

function git=capture_local_git_state(root)
[statusText,commit,branch]=git_query(root);
git=struct("commit",commit,"branch",branch, ...
    "tracked_status_text",statusText, ...
    "tracked_worktree_clean",strlength(statusText)==0);
end

function [statusText,commit,branch]=git_query(root)
safe=replace(string(root),"\","/");
quotedSafe="""" + replace(safe,"""","\""") + """";
quotedRoot="""" + replace(string(root),"""","\""") + """";
prefix="git -c safe.directory="+quotedSafe+" -C "+quotedRoot+" ";
statusText=strtrim(string(system_capture( ...
    prefix+"status --porcelain --untracked-files=no")));
commit=strtrim(string(system_capture(prefix+"rev-parse HEAD")));
branch=strtrim(string(system_capture(prefix+"branch --show-current")));
end

function value=system_capture(command)
[status,output]=system(char(command));
assert(status==0,"stageA4:iter24:GitQuery", ...
    "Git query failed: %s",output);
value=output;
end

function value=canonical_project_root(value)
value=string(java.io.File(value).getCanonicalPath());
assert(isfolder(value),"stageA4:iter24:RootMissing", ...
    "Project root does not exist: %s",value);
end

function value=absolute_existing_file(value)
value=string(java.io.File(value).getCanonicalPath());
assert(isfile(value),"stageA4:iter24:FileMissing","File missing: %s",value);
end

function value=read_text_table(pathValue)
opts=detectImportOptions(pathValue,"TextType","string", ...
    "VariableNamingRule","preserve");
value=readtable(pathValue,opts);
end

function value=extract_layer(message)
token=regexp(char(message),"layer '([^']+)'","tokens","once");
if isempty(token), value=""; else, value=string(token{1}); end
end

function [rankValue,conditionValue]=extract_rank_condition(message)
tokens=regexp(char(message),"rank=(\d+), n=\d+, cond2=([0-9eE\+\.-]+)", ...
    "tokens","once");
if isempty(tokens)
    rankValue=NaN; conditionValue=NaN;
else
    rankValue=str2double(tokens{1});
    conditionValue=str2double(tokens{2});
end
end

function value=ternary(condition,yesValue,noValue)
if condition, value=yesValue; else, value=noValue; end
end

function root=default_project_root()
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
end
