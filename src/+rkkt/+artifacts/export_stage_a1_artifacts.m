function exported = export_stage_a1_artifacts(runContext,data,index,config, ...
        linearization,fullResult,recursiveResult,audit,options)
%EXPORT_STAGE_A1_ARTIFACTS Persist one Stage A1 direction-verification run.
% Every target is checked before the first byte is written.  Existing files
% are evidence and are never replaced.  Complete KKT and recursive-chain
% matrices remain sparse MAT variables; CSV is limited to indexes, audit
% summaries, and sparse triplets for the permitted small diagnostic blocks.

arguments
    runContext (1,1) struct
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    linearization (1,1) struct
    fullResult (1,1) struct
    recursiveResult (1,1) struct
    audit (1,1) struct
    options.Environment = struct()
    options.Tests = struct()
    options.CodeScan table = table()
end

validate_inputs(runContext,index,config,linearization,fullResult, ...
    recursiveResult,audit);
paths = artifact_paths(runContext);
targets = output_targets(paths,index,recursiveResult);
assert_targets_absent(targets);
ensure_directory(paths.diagnostics_dir);

linearizationPayload = struct("linearization",linearization);
fullPayload = struct("kkt",fullResult.kkt, ...
    "diagnostics",fullResult.diagnostics, ...
    "linearization_identity",fullResult.linearization_identity);
recursivePayload = struct("reduced",recursiveResult.reduced, ...
    "partition",recursiveResult.partition, ...
    "thomas",recursiveResult.thomas, ...
    "day_response",recursiveResult.day_response, ...
    "core",recursiveResult.core, ...
    "recovery",recursiveResult.recovery, ...
    "linearization_identity",recursiveResult.linearization_identity);
directionsPayload = struct( ...
    "full_direction",fullResult.direction, ...
    "recursive_direction",recursiveResult.direction, ...
    "full_components",fullResult.components, ...
    "recursive_components",recursiveResult.components, ...
    "fixed_zero",recursiveResult.fixed_zero);
fullResidual = fullResult.kkt.matrix*fullResult.direction-fullResult.kkt.rhs;
recursiveResidual = fullResult.kkt.matrix*recursiveResult.direction- ...
    fullResult.kkt.rhs;
residualPayload = struct("audit",audit, ...
    "full_kkt_residual",fullResidual, ...
    "recursive_full_kkt_residual",recursiveResidual, ...
    "recursive_reinsertion",recursiveResult.full_kkt_reinsertion, ...
    "chain_diagnostics",recursiveResult.thomas.diagnostics, ...
    "core_diagnostics",recursiveResult.core.diagnostics);
configurationPayload = struct("config",config, ...
    "data_metadata",data.meta,"input_hashes",data.hashes, ...
    "environment",options.Environment,"tests",options.Tests);

rkkt.artifacts.save_mat_artifact(paths.linearization_mat,linearizationPayload);
rkkt.artifacts.save_mat_artifact(paths.full_kkt_mat,fullPayload);
rkkt.artifacts.save_mat_artifact(paths.recursive_blocks_mat,recursivePayload);
rkkt.artifacts.save_mat_artifact(paths.directions_mat,directionsPayload);
rkkt.artifacts.save_mat_artifact(paths.residuals_mat,residualPayload);
rkkt.artifacts.save_mat_artifact(paths.index_mapping_mat,"index",index);
rkkt.artifacts.save_mat_artifact(paths.configuration_mat,configurationPayload);

rkkt.artifacts.write_table_csv_17g(paths.variable_index,index.variable_index);
rkkt.artifacts.write_table_csv_17g(paths.constraint_index,index.constraint_index);
rkkt.artifacts.write_table_csv_17g(paths.block_index,index.block_index);
rkkt.artifacts.write_table_csv_17g(paths.fixed_zero_map,index.fixed_zero_map);
rkkt.artifacts.write_table_csv_17g(paths.permutation_map,index.permutation_map);
rkkt.artifacts.write_table_csv_17g(paths.soc_link_map,index.soc_link_map);

blockDimensions = make_block_dimensions(recursiveResult,config);
comparison = make_direction_comparison(audit,recursiveResult,config, ...
    linearization,fullResult);
residualSummary = make_residual_summary(fullResult,recursiveResult,config);
socAudit = make_soc_boundary_audit(index,config);
fixedAudit = make_fixed_zero_audit(index,recursiveResult);
rkkt.artifacts.write_table_csv_17g(paths.block_dimensions,blockDimensions);
rkkt.artifacts.write_table_csv_17g(paths.direction_comparison,comparison);
rkkt.artifacts.write_table_csv_17g(paths.residual_summary,residualSummary);
rkkt.artifacts.write_table_csv_17g(paths.soc_boundary_audit,socAudit);
rkkt.artifacts.write_table_csv_17g(paths.fixed_zero_audit,fixedAudit);

if isempty(options.CodeScan)
    codeScan = scan_stage_a1_code(runContext.project_root,config);
else
    codeScan = options.CodeScan;
end
rkkt.artifacts.write_table_csv_17g(paths.code_scan,codeScan);
identityEvidence = make_identity_evidence(linearization,fullResult, ...
    recursiveResult,index,config);
rkkt.artifacts.write_json_file(paths.linearization_identity,identityEvidence);

smallMatrices = small_matrix_specifications(recursiveResult,paths);
for rowNumber = 1:height(smallMatrices)
    write_sparse_triplets(char(smallMatrices.path(rowNumber)), ...
        smallMatrices.value{rowNumber});
end

matrixManifest = make_matrix_manifest(paths,linearization,fullResult, ...
    recursiveResult);
rkkt.artifacts.write_table_csv_17g(paths.matrix_manifest,matrixManifest);

hashTargets = targets(targets ~= string(paths.artifact_hashes));
artifactHashes = make_artifact_hashes(runContext.root,hashTargets);
rkkt.artifacts.write_table_csv_17g(paths.artifact_hashes,artifactHashes);

exported = struct();
exported.paths = paths;
exported.matrix_manifest = matrixManifest;
exported.block_dimensions = blockDimensions;
exported.direction_comparison = comparison;
exported.residual_summary = residualSummary;
exported.soc_boundary_audit = socAudit;
exported.fixed_zero_audit = fixedAudit;
exported.code_scan = codeScan;
exported.artifact_hashes = artifactHashes;
exported.linearization_identity = identityEvidence;
end

function validate_inputs(context,index,config,lin,fullResult,recursive,audit)
requiredContext = ["root","run_id","stage_id","matrices_dir", ...
    "indices_dir","iterations_dir","project_root"];
assert(isfolder(context.root) && all(isfield(context,cellstr(requiredContext))), ...
    "stageA1:artifacts:InvalidRunContext", ...
    "runContext must identify an existing unique run and its artifact directories.");
assert(string(context.stage_id)=="stage_A1", ...
    "stageA1:artifacts:StageMismatch", ...
    "The Stage A1 exporter accepts only a stage_A1 run context.");
manifestPath = fullfile(context.root,"run_manifest.json");
assert(isfile(manifestPath),"stageA1:artifacts:ManifestMissing", ...
    "The unique run must have an initialized run_manifest.json.");
manifest = jsondecode(fileread(manifestPath));
assert(string(manifest.run_id)==string(context.run_id) && ...
    string(manifest.stage_id)=="stage_A1" && string(manifest.status)=="RUNNING", ...
    "stageA1:artifacts:ManifestIdentity", ...
    "The run manifest must match this context and remain RUNNING while exporting.");

requiredIndex = ["variable_index","constraint_index","block_index", ...
    "fixed_zero_map","permutation_map","soc_link_map"];
assert(all(isfield(index,cellstr(requiredIndex))) && ...
    all(structfun(@istable,rmfield(index,setdiff(fieldnames(index), ...
    cellstr(requiredIndex))))),"stageA1:artifacts:IndexContract", ...
    "All six Stage A1 canonical index tables are required.");
assert(lin.counts.full_kkt==471 && fullResult.kkt.dimension==471 && ...
    isequal(size(fullResult.kkt.matrix),[471,471]) && ...
    issparse(fullResult.kkt.matrix),"stageA1:artifacts:FullKktDimension", ...
    "The persisted complete KKT must be sparse and exactly 471-by-471.");
actualBlocks = [recursive.partition.hour.dimension];
assert(isequal(actualBlocks,[27 27 29]) && ...
    isequal(actualBlocks,config.expected_hourly_kkt_block_dimensions), ...
    "stageA1:artifacts:HourBlockDimension", ...
    "The persisted hourly blocks must be 27, 27, and 29.");
assert(isequal(size(recursive.core.matrix),[16,16]) && ...
    config.expected_global_core_dimension==16, ...
    "stageA1:artifacts:CoreDimension", ...
    "The persisted global core must be exactly 16-by-16.");
identities = string([lin.identity,fullResult.linearization_identity, ...
    recursive.linearization_identity,audit.linearization_identity]);
assert(isscalar(unique(identities)), ...
    "stageA1:artifacts:LinearizationIdentity", ...
    "Full, recursive, and audit results must share the sole linearization identity.");
assert(recursive.no_full_direction_fallback, ...
    "stageA1:artifacts:RecursiveFallback", ...
    "A recursive result that permits full-KKT fallback cannot be exported.");
end

function paths = artifact_paths(context)
paths = struct();
paths.diagnostics_dir = fullfile(context.root,"diagnostics");
paths.linearization_mat = fullfile(context.matrices_dir,"linearization.mat");
paths.full_kkt_mat = fullfile(context.matrices_dir,"full_kkt.mat");
paths.recursive_blocks_mat = fullfile(context.matrices_dir,"recursive_blocks.mat");
paths.directions_mat = fullfile(context.matrices_dir,"directions.mat");
paths.residuals_mat = fullfile(context.matrices_dir,"residuals.mat");
paths.index_mapping_mat = fullfile(context.matrices_dir,"index_mapping.mat");
paths.configuration_mat = fullfile(context.matrices_dir,"configuration.mat");
paths.matrix_manifest = fullfile(context.matrices_dir,"matrix_manifest.csv");
paths.block_dimensions = fullfile(context.matrices_dir,"block_dimensions.csv");
paths.direction_comparison = fullfile(context.iterations_dir,"direction_comparison.csv");
paths.residual_summary = fullfile(context.iterations_dir,"residual_summary.csv");
paths.variable_index = fullfile(context.indices_dir,"variable_index.csv");
paths.constraint_index = fullfile(context.indices_dir,"constraint_index.csv");
paths.block_index = fullfile(context.indices_dir,"block_index.csv");
paths.fixed_zero_map = fullfile(context.indices_dir,"fixed_zero_map.csv");
paths.permutation_map = fullfile(context.indices_dir,"permutation_map.csv");
paths.soc_link_map = fullfile(context.indices_dir,"soc_link_map.csv");
paths.soc_boundary_audit = fullfile(context.indices_dir,"soc_boundary_audit.csv");
paths.fixed_zero_audit = fullfile(context.indices_dir,"fixed_zero_audit.csv");
paths.code_scan = fullfile(paths.diagnostics_dir,"code_scan.csv");
paths.linearization_identity = fullfile(paths.diagnostics_dir, ...
    "linearization_identity.json");
paths.core_triplets = fullfile(context.matrices_dir,"global_core_triplets.csv");
paths.day_response_triplets = fullfile(context.matrices_dir, ...
    "day_response_S_triplets.csv");
for hour = [8 9 10]
    paths.(sprintf("hour_%02d_D_triplets",hour)) = fullfile( ...
        context.matrices_dir,sprintf("hour_%02d_D_triplets.csv",hour));
end
paths.artifact_hashes = fullfile(context.matrices_dir, ...
    "numerical_artifact_hashes.csv");
end

function targets = output_targets(paths,~,~)
names = fieldnames(paths);
names(strcmp(names,"diagnostics_dir")) = [];
targets = strings(numel(names),1);
for k = 1:numel(names)
    targets(k) = string(paths.(names{k}));
end
assert(numel(unique(lower(targets)))==numel(targets), ...
    "stageA1:artifacts:DuplicateTarget","Artifact targets are not unique.");
end

function assert_targets_absent(targets)
for target = reshape(targets,1,[])
    if isfile(target) || isfolder(target)
        error("stageA1:artifacts:TargetExists", ...
            "Stage A1 artifact target already exists and will not be overwritten: %s", ...
            target);
    end
end
end

function ensure_directory(pathValue)
if isfolder(pathValue), return; end
if exist(pathValue,"file")
    error("stageA1:artifacts:PathConflict", ...
        "A file exists where a directory is required: %s",pathValue);
end
[created,message] = mkdir(pathValue);
if ~created
    error("stageA1:artifacts:CreateDirectory", ...
        "Could not create artifact directory %s: %s",pathValue,message);
end
end

function output = make_block_dimensions(recursive,config)
blocks = recursive.partition.hour;
n = numel(blocks);
hour = reshape([blocks.hour],[],1);
n_primal = reshape([blocks.n_primal],[],1);
n_equalities = reshape([blocks.n_equalities],[],1);
kkt_dimension = reshape([blocks.dimension],[],1);
expected_dimension = reshape(config.expected_hourly_kkt_block_dimensions,[],1);
status = repmat("PASS",n,1);
status(kkt_dimension~=expected_dimension) = "FAIL";
output = table(hour,n_primal,n_equalities,kkt_dimension, ...
    expected_dimension,status);
end

function output = make_direction_comparison(audit,recursive,config,lin,fullResult)
identityMismatch = double(~(string(lin.identity)== ...
    string(fullResult.linearization_identity) && string(lin.identity)== ...
    string(recursive.linearization_identity)));
fixedValues = recursive.fixed_zero.value(:);
fixedDirections = recursive.fixed_zero.direction(:);
fixedValueMax = max([0;abs(fixedValues)]);
fixedDirectionMax = max([0;abs(fixedDirections)]);
metric_id = ["overall_direction_relative_2norm"; ...
    "xi_direction_relative_2norm";"y_direction_relative_2norm"; ...
    "l_direction_relative_2norm";"z_direction_relative_2norm"; ...
    "fixed_zero_maximum_absolute_value"; ...
    "fixed_zero_maximum_absolute_direction"; ...
    "linearization_identity_mismatch"; ...
    "recursive_full_direction_fallback_used"; ...
    "reduced_assembly_relative_error"; ...
    "hour_chain_relative_residual";"global_core_relative_residual"];
actual_value = [audit.direction_relative_error; ...
    audit.component_relative_errors.xi;audit.component_relative_errors.y; ...
    audit.component_relative_errors.l;audit.component_relative_errors.z; ...
    fixedValueMax;fixedDirectionMax;identityMismatch; ...
    double(~recursive.no_full_direction_fallback); ...
    recursive.partition.assembly_audit.matrix_relative_error; ...
    recursive.thomas.diagnostics.chain_relative_residual; ...
    recursive.core.diagnostics.relative_residual];
threshold = [repmat(config.tolerances.direction_relative_2norm,5,1); ...
    0;0;0;0;config.tolerances.symmetry_relative; ...
    config.tolerances.recursive_full_kkt_relative_residual; ...
    config.tolerances.recursive_full_kkt_relative_residual];
status = repmat("PASS",numel(actual_value),1);
status(~isfinite(actual_value) | actual_value>threshold) = "FAIL";
output = table(metric_id,actual_value,threshold,status);
end

function output = make_residual_summary(fullResult,recursive,config)
K = fullResult.kkt.matrix;
b = fullResult.kkt.rhs;
fullResidual = K*fullResult.direction-b;
recursiveResidual = K*recursive.direction-b;
chainRhs = [recursive.partition.r_v,recursive.partition.B];
chainResidual = recursive.partition.M*recursive.thomas.stacked_solution-chainRhs;
coreResidual = recursive.core.matrix*recursive.core.solution-recursive.core.rhs;
route = ["full_kkt_direct_preferred";"full_kkt_direct_hard_limit"; ...
    "recursive_direction_reinserted_in_full_kkt"; ...
    "recursive_hour_chain_15_rhs";"global_core_16"];
absolute_residual_2norm = [norm(fullResidual,2);norm(fullResidual,2); ...
    norm(recursiveResidual,2);norm(chainResidual,"fro");norm(coreResidual,2)];
rhs_2norm = [norm(b,2);norm(b,2);norm(b,2);norm(chainRhs,"fro"); ...
    norm(recursive.core.rhs,2)];
relative_residual_2norm = absolute_residual_2norm ./ max(1,rhs_2norm);
threshold = [config.tolerances.direct_preferred; ...
    config.tolerances.direct_maximum; ...
    config.tolerances.recursive_full_kkt_relative_residual; ...
    config.tolerances.recursive_full_kkt_relative_residual; ...
    config.tolerances.recursive_full_kkt_relative_residual];
status = repmat("PASS",numel(route),1);
status(~isfinite(relative_residual_2norm) | ...
    relative_residual_2norm>threshold) = "FAIL";
output = table(route,absolute_residual_2norm,rhs_2norm, ...
    relative_residual_2norm,threshold,status);
end

function output = make_soc_boundary_audit(index,config)
links = index.soc_link_map;
constraints = index.constraint_index;
equalities = constraints(string(constraints.constraint_type)=="equality",:);
check_id = strings(0,1); hour = zeros(0,1); storage = zeros(0,1);
equation_id = strings(0,1); expected = strings(0,1);
actual = strings(0,1); status = strings(0,1);
for h = config.hours
    for s = 1:2
        link = links(links.hour==h & links.storage_id==s,:);
        equation = equalities(equalities.hour==h & equalities.asset_id==s & ...
            string(equalities.constraint_name)=="soc_dynamics",:);
        passed = height(link)==1 && height(equation)==1;
        if h==config.start_hour
            passed = passed && isnan(link.predecessor_hour) && ...
                link.predecessor_soc_global_index==0 && ...
                link.initial_energy_fraction==0.5 && ...
                string(link.boundary_source)=="fixed_half_energy";
            expectedText = "SOC=0.5E; no hour 7 predecessor";
            actualText = sprintf("fraction=%.17g; predecessor=%s; index=%d", ...
                link.initial_energy_fraction,number_or_na(link.predecessor_hour), ...
                link.predecessor_soc_global_index);
        else
            passed = passed && link.predecessor_hour==h-1 && ...
                link.predecessor_soc_global_index>0 && ...
                string(link.boundary_source)=="previous_window_hour";
            expectedText = sprintf("predecessor hour %d inside window",h-1);
            actualText = sprintf("predecessor=%s; index=%d", ...
                number_or_na(link.predecessor_hour),link.predecessor_soc_global_index);
        end
        [check_id,hour,storage,equation_id,expected,actual,status] = append_audit( ...
            check_id,hour,storage,equation_id,expected,actual,status, ...
            sprintf("SOC-DYN-H%02d-S%02d",h,s),h,s, ...
            first_text(equation,"constraint_id"),expectedText,actualText,passed);
    end
end
for s = 1:2
    link = links(links.hour==config.terminal_hour & links.storage_id==s,:);
    equation = equalities(equalities.hour==config.terminal_hour & ...
        equalities.asset_id==s & string(equalities.constraint_name)== ...
        "terminal_soc",:);
    passed = height(link)==1 && height(equation)==1 && ...
        link.terminal_equality && link.terminal_energy_fraction==0.5;
    [check_id,hour,storage,equation_id,expected,actual,status] = append_audit( ...
        check_id,hour,storage,equation_id,expected,actual,status, ...
        sprintf("SOC-END-H10-S%02d",s),config.terminal_hour,s, ...
        first_text(equation,"constraint_id"),"terminal SOC=0.5E equality", ...
        sprintf("terminal=%s; fraction=%.17g", ...
        string(link.terminal_equality),link.terminal_energy_fraction),passed);
end
output = table(check_id,hour,storage,equation_id,expected,actual,status);
end

function [ids,hours,stores,equations,expectedValues,actualValues,statuses] = ...
        append_audit(ids,hours,stores,equations,expectedValues,actualValues, ...
        statuses,id,hour,storage,equation,expected,actual,passed)
ids(end+1,1) = string(id); hours(end+1,1) = hour;
stores(end+1,1) = storage; equations(end+1,1) = string(equation);
expectedValues(end+1,1) = string(expected); actualValues(end+1,1) = string(actual);
statuses(end+1,1) = pass_text(passed);
end

function textValue = first_text(value,field)
if height(value)==1
    textValue = string(value.(field)(1));
else
    textValue = "MISSING_OR_DUPLICATE";
end
end

function value = number_or_na(number)
if isfinite(number), value = sprintf("%d",number); else, value = "NA"; end
end

function output = make_fixed_zero_audit(index,recursive)
count = height(index.fixed_zero_map);
assert(count==recursive.fixed_zero.count, ...
    "stageA1:artifacts:FixedZeroCount", ...
    "Canonical and recursive fixed-zero counts differ.");
maximum_absolute_value = max([0;abs(recursive.fixed_zero.value(:))]);
maximum_absolute_direction = max([0;abs(recursive.fixed_zero.direction(:))]);
values_exact_zero = all(recursive.fixed_zero.value(:)==0);
directions_exact_zero = all(recursive.fixed_zero.direction(:)==0);
vacuous = count==0;
passed = values_exact_zero && directions_exact_zero && ...
    recursive.fixed_zero.all_exact_zero;
check_id = "A1-FIXED-ZERO-EXACT";
if vacuous
    variable_id = "VACUOUS_NO_FIXED_ZERO_IN_WINDOW";
else
    variable_id = "ALL_FIXED_ZERO_VARIABLES";
end
fixed_value = maximum_absolute_value;
full_direction = maximum_absolute_direction;
recursive_direction = maximum_absolute_direction;
status = pass_text(passed);
if vacuous
    details = "No fixed-zero variables occur in real day 1 hours 8-10; exact-zero check is vacuously satisfied.";
else
    details = "All removed variables and recovered directions were checked against exact numeric zero.";
end
output = table(check_id,variable_id,fixed_value,full_direction, ...
    recursive_direction,status,count,maximum_absolute_value, ...
    maximum_absolute_direction,values_exact_zero,directions_exact_zero, ...
    vacuous,details);
end

function output = scan_stage_a1_code(projectRoot,config)
solverRoot = fullfile(projectRoot,"src","+rkkt","+solver");
files = dir(fullfile(solverRoot,"**","*.m"));
texts = strings(numel(files),1);
relativeNames = strings(numel(files),1);
for k = 1:numel(files)
    pathValue = fullfile(files(k).folder,files(k).name);
    texts(k) = string(fileread(pathValue));
    relativeNames(k) = relative_path(projectRoot,pathValue);
end
check_id = ["FORBIDDEN-INV";"FORBIDDEN-PINV"; ...
    "FORBIDDEN-LSQMINNORM";"FORBIDDEN-RANDOM"; ...
    "RECURSIVE-FULL-DIRECTION-FALLBACK";"FULL-KKT-OR-CHAIN-DENSE-CONVERSION"; ...
    "AUTOMATIC-REGULARIZATION";"AUTOMATIC-SYMMETRIZATION"];
patterns = ["(?<![A-Za-z0-9_])inv\s*\("; ...
    "(?<![A-Za-z0-9_])pinv\s*\(";"lsqminnorm\s*\("; ...
    "(?<![A-Za-z0-9_])randn?\s*\(";"solve_full_kkt_direction\s*\("; ...
    "full\s*\(\s*(?:assembly\.matrix|fullAssembly\.matrix|partition\.M)"; ...
    "";""];
match_count = zeros(numel(check_id),1);
details = strings(numel(check_id),1);
for row = 1:6
    matchedFiles = strings(0,1);
    for k = 1:numel(files)
        source = texts(k);
        if row==5 && ~strcmp(files(k).name,"solve_recursive_direction.m")
            continue
        end
        matches = regexp(char(source),char(patterns(row)),"match");
        match_count(row) = match_count(row)+numel(matches);
        if ~isempty(matches), matchedFiles(end+1,1)=relativeNames(k); end %#ok<AGROW>
    end
    if isempty(matchedFiles), details(row)="No forbidden match.";
    else, details(row)=strjoin(unique(matchedFiles),"; "); end
end
match_count(7) = double(config.linear_algebra.automatic_regularization);
match_count(8) = double(config.linear_algebra.automatic_symmetrization);
details(7) = "Configuration flag must be false.";
details(8) = "Configuration flag must be false.";
files_scanned = repmat(numel(files),numel(check_id),1);
status = repmat("PASS",numel(check_id),1);
status(match_count~=0) = "FAIL";
requirement = ["No inv call";"No pinv call";"No lsqminnorm call"; ...
    "No random-number call";"No recursive fallback to a full-KKT direction"; ...
    "No dense conversion of the complete KKT or 83-dimensional chain"; ...
    "Automatic regularization disabled";"Automatic symmetrization disabled"];
actual = match_count;
evidence = details;
output = table(check_id,requirement,actual,status,evidence, ...
    files_scanned,match_count,details);
end

function value = make_identity_evidence(lin,fullResult,recursive,index,config)
value = struct();
value.linearization_identity = char(string(lin.identity));
value.linearization_version = char(string(lin.version));
value.full_kkt_identity = char(string(fullResult.linearization_identity));
value.recursive_identity = char(string(recursive.linearization_identity));
value.all_identities_equal = string(lin.identity)== ...
    string(fullResult.linearization_identity) && string(lin.identity)== ...
    string(recursive.linearization_identity);
value.shared_linearization_object_count = 1;
value.hessian_nnz = nnz(lin.H);
value.full_kkt_dimension = fullResult.kkt.dimension;
value.hourly_block_dimensions = [recursive.partition.hour.dimension];
value.global_core_dimension = size(recursive.core.matrix,1);
value.index_version = char(string(index.version));
value.window_type = char(string(config.window_type));
value.start_hour = config.start_hour;
value.terminal_hour = config.terminal_hour;
value.soc_boundary_mode = char(string(config.soc_boundary_mode));
value.no_automatic_regularization = ...
    ~config.linear_algebra.automatic_regularization;
value.no_automatic_symmetrization = ...
    ~config.linear_algebra.automatic_symmetrization;
value.no_full_kkt_direction_fallback = recursive.no_full_direction_fallback;
end

function specs = small_matrix_specifications(recursive,paths)
matrix_name = ["global_core_16";"day_response_S"; ...
    "hour_08_D";"hour_09_D";"hour_10_D"];
value = {recursive.core.matrix;recursive.day_response.S; ...
    recursive.partition.hour(1).D;recursive.partition.hour(2).D; ...
    recursive.partition.hour(3).D};
path = strings(5,1);
path(1)=string(paths.core_triplets);
path(2)=string(paths.day_response_triplets);
path(3)=string(paths.hour_08_D_triplets);
path(4)=string(paths.hour_09_D_triplets);
path(5)=string(paths.hour_10_D_triplets);
specs = table(matrix_name,value,path);
end

function write_sparse_triplets(pathValue,matrix)
[row,column,value] = find(sparse(matrix));
rkkt.artifacts.write_table_csv_17g(pathValue,table(row,column,value));
end

function output = make_matrix_manifest(paths,lin,fullResult,recursive)
matrix_name = ["linearization_H";"linearization_A";"linearization_G"; ...
    "full_kkt";"reduced_W";"reduced_saddle";"hour_08_D"; ...
    "hour_08_E";"hour_08_B";"hour_09_D";"hour_09_E"; ...
    "hour_09_B";"hour_10_D";"hour_10_E";"hour_10_B"; ...
    "hour_chain_M";"day_response_S";"global_core"];
values = {lin.H;lin.A;lin.G;fullResult.kkt.matrix;recursive.reduced.W; ...
    recursive.reduced.saddle;recursive.partition.hour(1).D; ...
    recursive.partition.hour(1).E;recursive.partition.hour(1).B; ...
    recursive.partition.hour(2).D;recursive.partition.hour(2).E; ...
    recursive.partition.hour(2).B;recursive.partition.hour(3).D; ...
    recursive.partition.hour(3).E;recursive.partition.hour(3).B; ...
    recursive.partition.M;recursive.day_response.S;recursive.core.matrix};
artifactPaths = [repmat(string(paths.linearization_mat),3,1); ...
    string(paths.full_kkt_mat);repmat(string(paths.recursive_blocks_mat),14,1)];
n = numel(values);
rows = zeros(n,1); columns = zeros(n,1); nonzero = zeros(n,1);
is_sparse = false(n,1); sha256 = strings(n,1); path = strings(n,1);
for k = 1:n
    [rows(k),columns(k)] = size(values{k});
    nonzero(k) = nnz(values{k}); is_sparse(k) = issparse(values{k});
    sha256(k) = rkkt.data.compute_sha256_file(artifactPaths(k));
    path(k) = relative_path(fileparts(fileparts(paths.linearization_mat)), ...
        artifactPaths(k));
end
output = table(matrix_name,rows,columns,nonzero,is_sparse,sha256,path, ...
    'VariableNames',{'matrix_name','rows','columns','nnz','is_sparse', ...
    'sha256','path'});
end

function output = make_artifact_hashes(runRoot,targets)
n = numel(targets);
relative_path_value = strings(n,1); sha256 = strings(n,1);
bytes = zeros(n,1); artifact_type = strings(n,1);
for k = 1:n
    assert(isfile(targets(k)),"stageA1:artifacts:MissingWrittenTarget", ...
        "Expected artifact was not written: %s",targets(k));
    relative_path_value(k) = relative_path(runRoot,targets(k));
    sha256(k) = rkkt.data.compute_sha256_file(targets(k));
    info = dir(targets(k)); bytes(k) = info.bytes;
    [~,~,extension] = fileparts(targets(k));
    artifact_type(k) = erase(lower(string(extension)),".");
end
scope = repmat("numerical_export",n,1);
status = repmat("PASS",n,1);
output = table(relative_path_value,sha256,bytes,artifact_type,scope,status, ...
    'VariableNames',{'relative_path','sha256','bytes','artifact_type','scope', ...
    'status'});
end

function value = relative_path(root,pathValue)
root = string(char(java.io.File(char(root)).getCanonicalPath()));
pathValue = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
prefix = root+filesep;
assert(startsWith(lower(pathValue),lower(prefix)), ...
    "stageA1:artifacts:PathOutsideRun", ...
    "Artifact path is outside its declared root: %s",pathValue);
value = replace(extractAfter(pathValue,strlength(prefix)),string(filesep),"/");
end

function value = pass_text(condition)
if condition, value="PASS"; else, value="FAIL"; end
end
