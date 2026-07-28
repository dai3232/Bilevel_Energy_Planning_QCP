function tests = test_pkg6_solver_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot,"src");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(sourceRoot);

modules = struct();
modules.partition = rkkt.solver.validation.runPartition( ...
    Interactive=false,WriteArtifacts=true);
modules.dayChain = rkkt.solver.validation.runDayChain( ...
    Interactive=false,WriteArtifacts=true);
modules.dayResponse = rkkt.solver.validation.runDayResponse( ...
    Interactive=false,WriteArtifacts=true);
modules.aggregation = rkkt.solver.validation.runDayAggregation( ...
    Interactive=false,WriteArtifacts=true);
modules.core = rkkt.solver.validation.runGlobalCore( ...
    Interactive=false,WriteArtifacts=true);
modules.recovery = rkkt.solver.validation.runRecovery( ...
    Interactive=false,WriteArtifacts=true);
modules.equivalence = rkkt.solver.validation.runEquivalence( ...
    Interactive=false,WriteArtifacts=true);

support = rkkt.solver.validation.ValidationSupport;
linearizationArtifact = support.modelArtifact( ...
    "统一线性化模块输出.mat");
reducedArtifact = support.solverArtifact("既约KKT模块输出.mat");
loadedLinearization = load(linearizationArtifact,"moduleResult");
loadedReduced = load(reducedArtifact,"moduleResult");

objects = struct( ...
    "linearization", ...
        loadedLinearization.moduleResult.output.linearization, ...
    "reduced",loadedReduced.moduleResult.output.reduced, ...
    "partition",modules.partition.output.partition, ...
    "dailyThomas",modules.dayChain.output.dailyThomas, ...
    "dailyResponses",modules.dayResponse.output.dailyResponses, ...
    "aggregation",modules.aggregation.output.aggregation, ...
    "core",modules.core.output.core, ...
    "recovery",modules.recovery.output.recovery, ...
    "audit",modules.equivalence.output.audit);

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.modules = modules;
testCase.TestData.objects = objects;
testCase.TestData.config = loadedLinearization.moduleResult.input.config;
end

function testSevenFacadesMatchLegacyExactly(testCase)
modules = testCase.TestData.modules;
exact = [ ...
    modules.partition.diagnostics.legacy_facade_exact_equal
    modules.dayChain.diagnostics.legacy_facade_all_exact_equal
    modules.dayResponse.diagnostics.legacy_facade_all_exact_equal
    modules.aggregation.diagnostics. ...
        forward_legacy_facade_exact_equal
    modules.aggregation.diagnostics. ...
        shuffled_legacy_facade_exact_equal
    modules.core.diagnostics.legacy_facade_exact_equal
    modules.recovery.diagnostics.legacy_facade_exact_equal
    modules.equivalence.diagnostics.legacy_facade_exact_equal];
verifyTrue(testCase,all(exact));
verifyTrue(testCase,all( ...
    modules.dayChain.diagnostics.legacy_facade_exact_equal_by_day));
verifyTrue(testCase,all( ...
    modules.dayResponse.diagnostics.legacy_facade_exact_equal_by_day));

interfaces = [ ...
    string(modules.partition.meta.interface_name)
    string(modules.dayChain.meta.interface_name)
    string(modules.dayResponse.meta.interface_name)
    string(modules.aggregation.meta.interface_name)
    string(modules.core.meta.interface_name)
    string(modules.recovery.meta.interface_name)
    string(modules.equivalence.meta.interface_name)];
verifyEqual(testCase,interfaces,[ ...
    "rkkt.solver.partitionRecursiveSystem"
    "rkkt.solver.solveDayChain"
    "rkkt.solver.buildDayResponse"
    "rkkt.solver.aggregateDayResponses"
    "rkkt.solver.solveGlobalCore"
    "rkkt.solver.recoverDirection"
    "rkkt.solver.verifyEquivalence"]);
end

function testPipelineSharesOneLinearizationIdentity(testCase)
objects = testCase.TestData.objects;
identities = [ ...
    string(objects.linearization.identity)
    string(objects.reduced.linearization_identity)
    string(objects.partition.linearization_identity)
    reshape(string([objects.dailyThomas.linearization_identity]),[],1)
    reshape(string([objects.dailyResponses.linearization_identity]),[],1)
    string(objects.aggregation.linearization_identity)
    string(objects.core.linearization_identity)
    string(objects.recovery.linearization_identity)
    string(objects.audit.linearization_identity)];
verifyEqual(testCase,numel(unique(identities)),1);
verifyEqual(testCase,identities, ...
    repmat(string(objects.linearization.identity),numel(identities),1));
end

function testPartitionDimensionsSocPermutationAndReconstruction(testCase)
partition = testCase.TestData.objects.partition;
reduced = testCase.TestData.objects.reduced;
permutation = partition.permutation;
dayDimensions = reshape( ...
    [partition.day.hourly_chain_dimension],[],1);
verifyEqual(testCase,partition.days,14:20);
verifyEqual(testCase,partition.hours,1:24);
verifyEqual(testCase,dayDimensions,[589;590;589;590;590;590;590]);
verifyEqual(testCase,sum(dayDimensions),4128);
verifyEqual(testCase, ...
    permutation.assembly_map.dimension, ...
    [16;617;618;617;618;618;618;618]);
verifyEqual(testCase,permutation.dimension,4340);
verifyTrue(testCase,permutation.is_bijection);
verifyTrue(testCase,permutation.is_nonidentity);
verifyTrue(testCase,permutation.forward_inverse_composition_exact);
verifyTrue(testCase,permutation.inverse_forward_composition_exact);
verifyEqual(testCase, ...
    sort(permutation.forward_recursive_to_canonical),(1:4340).');
verifyEqual(testCase, ...
    permutation.inverse_canonical_to_recursive( ...
        permutation.forward_recursive_to_canonical),(1:4340).');
verifyEqual(testCase, ...
    partition.assembly_audit.cross_day_hourly_equality_nnz,0);
verifyTrue(testCase, ...
    partition.assembly_audit.no_cross_day_soc_coupling);
audit = partition.assembly_audit;
verifyEqual(testCase,audit.matrix_difference_nnz,0);
verifyEqual(testCase,audit.rhs_relative_error,0);
verifyTrue(testCase,isequaln(audit.permuted_rhs,audit.expected_rhs));
verifyEqual(testCase,audit.canonical_matrix_difference_nnz,0);
verifyEqual(testCase,audit.canonical_rhs_difference_nnz,0);
verifyTrue(testCase,isequaln( ...
    audit.reconstructed_canonical_matrix,reduced.saddle));
verifyTrue(testCase,isequaln( ...
    audit.reconstructed_canonical_rhs,reduced.rhs));
end

function testSevenByTwentyFourHourBlocksHaveNaturalDimensions(testCase)
partition = testCase.TestData.objects.partition;
allDimensions = zeros(168,1);
position = 0;
for d = 1:7
    day = partition.day(d);
    verifyEqual(testCase,numel(day.hour),24);
    verifyEqual(testCase,reshape([day.hour.hour],1,[]),1:24);
    verifyEqual(testCase,reshape([day.hour.day_id],1,[]), ...
        repmat(day.day_id,1,24));
    verifyTrue(testCase,isempty(day.hour(1).E));
    verifyEqual(testCase, ...
        reshape(arrayfun(@(item)nnz(item.E),day.hour(2:24)),[],1), ...
        repmat(2,23,1));
    verifyEqual(testCase,day.hour(24).n_equalities,5);
    dimensions = reshape([day.hour.dimension],[],1);
    verifyEqual(testCase,dimensions, ...
        reshape([day.hour.n_primal],[],1)+ ...
        reshape([day.hour.n_equalities],[],1));
    verifyEqual(testCase,sum(dimensions), ...
        day.hourly_chain_dimension);
    allDimensions(position+(1:24)) = dimensions;
    position = position+24;
end
verifyEqual(testCase,position,168);
verifyGreaterThan(testCase,numel(unique(allDimensions)),1);
verifyEqual(testCase,sum(allDimensions),4128);
end

function testThomasUsesTwentyFourFactorsAndFifteenRhs(testCase)
objects = testCase.TestData.objects;
dayIds = testCase.TestData.modules.dayChain.input.dayIds;
verifyEqual(testCase,dayIds,(14:20).');
for d = 1:7
    thomas = objects.dailyThomas(d);
    day = objects.partition.day(d);
    verifyEqual(testCase,numel(thomas.factors),24);
    verifyEqual(testCase,numel(thomas.diagnostics.hour_block),24);
    verifyEqual(testCase,thomas.rhs_count,15);
    verifyEqual(testCase, ...
        reshape([thomas.diagnostics.hour_block.rhs_count],[],1), ...
        repmat(15,24,1));
    verifySize(testCase,thomas.stacked_solution, ...
        [day.hourly_chain_dimension,15]);
    verifyEqual(testCase,numel(thomas.X_by_hour),24);
    verifyTrue(testCase,all(~cellfun(@isempty,thomas.factors)));
    verifyEqual(testCase, ...
        [thomas.diagnostics.hour_block.schur_inertia_zero], ...
        zeros(1,24));
    verifyLessThanOrEqual(testCase, ...
        thomas.diagnostics.chain_relative_residual,1e-10);
    residual = day.M*thomas.stacked_solution-[day.r_v,day.B];
    relativeResidual = norm(residual,"fro")/ ...
        max(1,norm([day.r_v,day.B],"fro"));
    verifyLessThanOrEqual(testCase,relativeResidual,1e-10);
    refinement = thomas.diagnostics.residual_refinement;
    verifyFalse(testCase,refinement.enabled);
    verifyEqual(testCase,refinement.maximum_passes,0);
    verifyEqual(testCase,refinement.additional_factorization_count,0);
    verifyFalse(testCase,refinement.direct_chain_backslash_used);
end
end

function testDayResponsesPreserveFormulaSymmetryAndNoSideEffects(testCase)
objects = testCase.TestData.objects;
for d = 1:7
    day = objects.partition.day(d);
    response = objects.dailyResponses(d);
    verifyEqual(testCase,response.day_id,day.day_id);
    verifySize(testCase,response.S,[14,14]);
    verifySize(testCase,response.c,[14,1]);
    verifySize(testCase,response.beta,[14,1]);
    verifySize(testCase,response.gamma,[14,1]);
    verifyLessThanOrEqual(testCase, ...
        relative_norm(day.M*response.a-day.r_v,day.r_v),1e-10);
    verifyLessThanOrEqual(testCase, ...
        relative_frobenius(day.M*response.U-day.B,day.B),1e-10);
    verifyLessThanOrEqual(testCase,relative_frobenius( ...
        response.S-(day.C-day.B.'*response.U),response.S),1e-14);
    verifyLessThanOrEqual(testCase,relative_norm( ...
        response.c-(day.r_q_day-day.B.'*response.a), ...
        response.c),1e-14);
    verifyLessThanOrEqual(testCase,relative_norm( ...
        response.gamma-(response.c-response.S*response.beta), ...
        response.gamma),1e-14);
    verifyTrue(testCase,isequaln(response.beta,-day.r_binding));
    verifyLessThanOrEqual(testCase, ...
        response.diagnostics.symmetry_relative,1e-12);
    verifyTrue(testCase,response.diagnostics.side_effect_free);
    verifyTrue(testCase,response.diagnostics.c_gamma_distinct_formula);
end
productionFile = fullfile(testCase.TestData.repositoryRoot, ...
    "src","solver","form_stage_a_multiday_day_response.m");
source = fileread(productionFile);
verifyEmpty(testCase,regexp(source, ...
    '(?m)^\s*(?:global|persistent)\b',"once"));
for token = {'assignin\s*\(','evalin\s*\(','save\s*\(', ...
        'writetable\s*\(','fopen\s*\('}
    verifyEmpty(testCase,regexp(source,token{1},"once"));
end
end

function testAggregationIsStrictlyOrderInvariant(testCase)
module = testCase.TestData.modules.aggregation;
aggregation = testCase.TestData.objects.aggregation;
verifyEqual(testCase,aggregation.day_ids_sorted,14:20);
verifyEqual(testCase,aggregation.input_order,14:20);
verifySize(testCase,aggregation.S_sum,[14,14]);
verifySize(testCase,aggregation.gamma_sum,[14,1]);
verifyTrue(testCase,aggregation.order_invariant_passed);
verifyEqual(testCase, ...
    aggregation.order_invariant_S_relative_error,0);
verifyEqual(testCase, ...
    aggregation.order_invariant_gamma_relative_error,0);
verifyTrue(testCase, ...
    module.diagnostics.forward_shuffled_S_sum_exact_equal);
verifyTrue(testCase, ...
    module.diagnostics.forward_shuffled_gamma_sum_exact_equal);
verifyEqual(testCase, ...
    module.diagnostics.shuffled_order_invariant_S_relative_error,0);
verifyEqual(testCase, ...
    module.diagnostics.shuffled_order_invariant_gamma_relative_error,0);
verifyEqual(testCase,module.indexDescription.accumulation_order,14:20);
end

function testGlobalCoreFormulaLdlAndResidual(testCase)
objects = testCase.TestData.objects;
core = objects.core;
expectedMatrix = [ ...
    objects.partition.global.Q+objects.aggregation.S_sum, ...
    objects.partition.global.R.'; ...
    objects.partition.global.R,sparse(2,2)];
expectedRhs = [ ...
    objects.partition.global.b_q+objects.aggregation.gamma_sum; ...
    -objects.partition.global.r_duration];
verifyTrue(testCase,isequaln(core.matrix,expectedMatrix));
verifyTrue(testCase,isequaln(core.rhs,expectedRhs));
verifyTrue(testCase,issparse(core.matrix));
verifySize(testCase,core.matrix,[16,16]);
verifyEqual(testCase,nnz(core.matrix),204);
verifySize(testCase,core.rhs,[16,1]);
verifySize(testCase,core.solution,[16,1]);
verifySize(testCase,core.delta_q,[14,1]);
verifySize(testCase,core.delta_rho,[2,1]);
verifyTrue(testCase,isequaln(core.delta_q,core.solution(1:14)));
verifyTrue(testCase,isequaln(core.delta_rho,core.solution(15:16)));
verifyLessThanOrEqual(testCase, ...
    core.diagnostics.relative_residual,1e-10);
verifyEqual(testCase,core.diagnostics.factor.inertia_zero,0);
verifyEqual(testCase, ...
    core.diagnostics.residual_refinement.maximum_passes,0);
verifyEqual(testCase, ...
    core.diagnostics.residual_refinement. ...
        additional_factorization_count,0);
end

function testRecoveryIsStrictCompleteAndRestoresFixedZeros(testCase)
objects = testCase.TestData.objects;
linearization = objects.linearization;
recovery = objects.recovery;
components = recovery.components;
verifySize(testCase,recovery.direction,[18836,1]);
verifySize(testCase,components.xi,[3722,1]);
verifySize(testCase,components.y,[618,1]);
verifySize(testCase,components.l,[7248,1]);
verifySize(testCase,components.z,[7248,1]);
verifyTrue(testCase,isequaln(recovery.direction, ...
    [components.xi;components.y;components.l;components.z]));
verifySize(testCase,components.q,[14,1]);
verifySize(testCase,components.rho,[2,1]);
verifySize(testCase,components.q_day_matrix,[14,7]);
verifySize(testCase,components.pi_matrix,[14,7]);
verifySize(testCase,components.v_by_day_hour,[7,24]);
verifyTrue(testCase,all(cellfun( ...
    @(value)~isempty(value),components.v_by_day_hour),"all"));
verifyTrue(testCase,recovery.diagnostics.strict_reverse_recovery);
verifyEqual(testCase,recovery.diagnostics.reverse_day_order,20:-1:14);
verifyEqual(testCase,recovery.diagnostics.reverse_hour_order,24:-1:1);

gDirection = sparse(linearization.G)*components.xi;
deltaLResidual = components.l+linearization.r_ineq+gDirection;
deltaZResidual = linearization.l.*components.z+ ...
    linearization.r_comp-linearization.z.*linearization.r_ineq- ...
    linearization.z.*gDirection;
verifyLessThanOrEqual(testCase,norm(deltaLResidual,2)/max([ ...
    1,norm(components.l,2),norm(linearization.r_ineq,2), ...
    norm(gDirection,2)]),1e-10);
verifyLessThanOrEqual(testCase,norm(deltaZResidual,2)/max([ ...
    1,norm(linearization.l.*components.z,2), ...
    norm(linearization.r_comp,2), ...
    norm(linearization.z.*linearization.r_ineq,2), ...
    norm(linearization.z.*gDirection,2)]),1e-10);
verifyEqual(testCase,recovery.fixed_zero.count,422);
verifyTrue(testCase,recovery.fixed_zero.all_exact_zero);
verifyEqual(testCase,recovery.fixed_zero.value,zeros(422,1));
verifyEqual(testCase,recovery.fixed_zero.direction,zeros(422,1));
verifyTrue(testCase,all(isfinite(recovery.direction)));
end

function testStagedPipelineMatchesAuthorityExactly(testCase)
module = testCase.TestData.modules.equivalence;
comparisons = module.diagnostics.staged_authority_exact;
verifyEqual(testCase,sort(string(fieldnames(comparisons))),sort([ ...
    "reduced"
    "partition"
    "daily_thomas"
    "daily_responses"
    "aggregation"
    "core"
    "recovery_direction"
    "recovery_components"
    "fixed_zero"
    "recovery_diagnostics"]));
verifyTrue(testCase,all(structfun(@(value)logical(value),comparisons)));
verifyTrue(testCase,module.diagnostics.staged_authority_all_exact);
verifyEqual(testCase,string(fieldnames(module.output)),"audit");
verifyFalse(testCase,isfield(module.output,"recursiveResult"));
end

function testDirectionAuditPassesWithoutFallbackOrConsumption(testCase)
module = testCase.TestData.modules.equivalence;
audit = testCase.TestData.objects.audit;
errors = audit.component_relative_errors;
componentErrors = [errors.xi;errors.y;errors.l;errors.z];
verifyLessThanOrEqual(testCase,audit.direction_relative_error, ...
    audit.thresholds.DirectionRelative);
verifyLessThanOrEqual(testCase,componentErrors, ...
    repmat(audit.thresholds.DirectionRelative,4,1));
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual, ...
    audit.thresholds.RecursiveResidual);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual, ...
    audit.thresholds.FullResidualPreferred);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual, ...
    audit.thresholds.FullResidualMaximum);
verifyTrue(testCase,audit.passed.direction);
verifyTrue(testCase,audit.passed.recursive_residual);
verifyTrue(testCase,audit.passed.full_residual_preferred);
verifyTrue(testCase,audit.passed.full_residual_hard);
verifyTrue(testCase,audit.passed.fixed_zero_exact);
verifyTrue(testCase,audit.passed.day_sort_invariant);
verifyTrue(testCase,audit.passed.no_full_direction_fallback);
verifyTrue(testCase,audit.all_blocking_pass);
verifyTrue(testCase,module.diagnostics.no_full_direction_fallback);
verifyFalse(testCase,module.diagnostics.full_direction_consumed);
verifyFalse(testCase,module.diagnostics.parallel_executed);
verifyEqual(testCase, ...
    module.diagnostics.residual_refinement_maximum_passes,0);
end

function testSevenValidationEntriesWriteFixedArtifactsWithoutDuplication( ...
        testCase)
modules = testCase.TestData.modules;
moduleValues = { ...
    modules.partition;modules.dayChain;modules.dayResponse; ...
    modules.aggregation;modules.core;modules.recovery; ...
    modules.equivalence};
expectedOutputs = [ ...
    "partition";"dailyThomas";"dailyResponses";"aggregation"; ...
    "core";"recovery";"audit"];
for k = 1:numel(moduleValues)
    value = moduleValues{k};
    rkkt.contracts.validateModuleResult(value);
    verifyEqual(testCase,string(fieldnames(value.output)), ...
        expectedOutputs(k));
    verifyFalse(testCase,contains_forbidden_input(value.input));
end

matFiles = strings(7,1);
tableFiles = strings(0,1);
figureFiles = strings(0,1);
for k = 1:numel(moduleValues)
    matFiles(k) = string(moduleValues{k}.meta.output_file);
    tableFiles = [tableFiles;moduleValues{k}.tableFiles]; %#ok<AGROW>
    figureFiles = [figureFiles;moduleValues{k}.figureFiles]; %#ok<AGROW>
end
verifyTrue(testCase,all(isfile(matFiles)));
verifyTrue(testCase,all(isfile(tableFiles)));
verifyTrue(testCase,all(isfile(figureFiles)));
verifyEqual(testCase,artifact_names(matFiles),[ ...
    "递推分区模块输出.mat"
    "小时链求解模块输出.mat"
    "日响应模块输出.mat"
    "七日响应汇总输出.mat"
    "16维全局核心模块输出.mat"
    "局部回代模块输出.mat"
    "方向等价性模块输出.mat"]);
verifyEqual(testCase,artifact_names(tableFiles),[ ...
    "七日日链维数.csv"
    "小时块维数.csv"
    "递推排列摘要.csv"
    "Thomas逐日残差.csv"
    "小时LDL诊断.csv"
    "七日日响应摘要.csv"
    "日响应汇总顺序.csv"
    "S_sum与gamma_sum.csv"
    "16维核心矩阵.csv"
    "16维核心RHS与解.csv"
    "回代方向分量摘要.csv"
    "固定零恢复摘要.csv"
    "方向等价误差.csv"
    "完整KKT回插残差.csv"]);
verifyEqual(testCase,artifact_names(figureFiles),[ ...
    "七日日链维数.fig"
    "七日日链维数.png"
    "Thomas残差.fig"
    "Thomas残差.png"
    "日响应对称误差.fig"
    "日响应对称误差.png"
    "七日响应汇总.fig"
    "七日响应汇总.png"
    "16维全局核心.fig"
    "16维全局核心.png"
    "回代方向摘要.fig"
    "回代方向摘要.png"
    "方向等价性.fig"
    "方向等价性.png"]);
for k = 1:numel(matFiles)
    verifyEqual(testCase,string(who("-file",matFiles(k))), ...
        "moduleResult");
end
end

function testPkg6SourcesAreThinAndContainOnlyAuthorizedCalls(testCase)
sourceRoot = testCase.TestData.sourceRoot;
facadeNames = [ ...
    "partitionRecursiveSystem";"solveDayChain";"buildDayResponse"; ...
    "aggregateDayResponses";"solveGlobalCore";"recoverDirection"; ...
    "verifyEquivalence"];
productionNames = [ ...
    "partition_stage_a_multiday_recursive_system"
    "solve_block_thomas_ldl"
    "form_stage_a_multiday_day_response"
    "aggregate_stage_a_multiday_day_responses"
    "solve_stage_a_multiday_core16_ldl"
    "recover_stage_a_multiday_recursive_direction"
    "verify_stage_a_multiday_direction_equivalence"];
facadeFiles = fullfile(sourceRoot,"+rkkt","+solver",facadeNames+".m");
for k = 1:numel(facadeFiles)
    source = fileread(facadeFiles(k));
    verifyLessThanOrEqual(testCase,source_line_count(source),70);
    for p = 1:numel(productionNames)
        matches = regexp(source,productionNames(p)+"\s*\(","match");
        if p == k
            verifyEqual(testCase,numel(matches),1);
        else
            verifyEmpty(testCase,matches);
        end
    end
end

validationNames = [ ...
    "runPartition";"runDayChain";"runDayResponse"; ...
    "runDayAggregation";"runGlobalCore";"runRecovery"; ...
    "runEquivalence"];
validationFiles = fullfile(sourceRoot,"+rkkt","+solver", ...
    "+validation",validationNames+".m");
allFiles = [facadeFiles;validationFiles; ...
    fullfile(sourceRoot,"+rkkt","+solver","+validation", ...
        "ValidationSupport.m")];
validationSources = strings(numel(validationFiles),1);
for k = 1:numel(validationFiles)
    validationSources(k) = string(fileread(validationFiles(k)));
end
authorityName = "solve_stage_a_multiday_recursive_direction";
verifyEqual(testCase,count(join(validationSources,newline), ...
    authorityName),1);
verifyFalse(testCase,any(contains(validationSources(1:6), ...
    authorityName)));
verifyTrue(testCase,contains(validationSources(7),authorityName));
verifyFalse(testCase,any(contains(validationSources(1:6), ...
    "fullResult")));
verifyNotEmpty(testCase,regexp(validationSources(7), ...
    'modules\.fullKKT\s*=\s*support\.loadResult\s*\(',"once"));
verifyNotEmpty(testCase,regexp(validationSources(7), ...
    'modules\.fullKKT\.output\.fullResult',"once"));

forbiddenCalls = { ...
    'build_stage_a4_linearization\s*\(', ...
    'build_stage_a_multiday_linearization\s*\(', ...
    'rkkt\.model\.linearize\s*\(', ...
    'rkkt\.model\.initialize\s*\(', ...
    'initialize_stage_a4_state\s*\(', ...
    'load_project_data\s*\(', ...
    'read_project_data\s*\(', ...
    'readtable\s*\(', ...
    'readmatrix\s*\(', ...
    'xlsread\s*\(', ...
    'spreadsheetDatastore\s*\(', ...
    'rkkt\.solver\.solveFullKKT\s*\(', ...
    'solve_stage_a_multiday_full_kkt_direction\s*\(', ...
    'run_stage_a4_full_ipm\s*\(', ...
    'run_stage_a_multiday_ipm\s*\(', ...
    'update_primal_dual_state\s*\(', ...
    'compute_fraction_to_boundary_step\s*\(', ...
    '(?m)^\s*parfor\b', ...
    'parpool\s*\(', ...
    'parfeval\s*\(', ...
    '(?<![A-Za-z0-9_])inv\s*\(', ...
    '(?<![A-Za-z0-9_])pinv\s*\(', ...
    '(?<![A-Za-z0-9_])lsqminnorm\s*\(', ...
    '(?<![A-Za-z0-9_])full\s*\(', ...
    'mldivide\s*\(', ...
    'linsolve\s*\(', ...
    '(?<![A-Za-z0-9_])ldl\s*\(', ...
    '(?<![A-Za-z0-9_])decomposition\s*\('};
for k = 1:numel(allFiles)
    source = fileread(allFiles(k));
    for p = 1:numel(forbiddenCalls)
        verifyEmpty(testCase,regexp(source, ...
            forbiddenCalls{p},"once"));
    end
end
end

function value = relative_norm(residual,reference)
value = norm(residual,2)/max(1,norm(reference,2));
end

function value = relative_frobenius(residual,reference)
value = norm(residual,"fro")/max(1,norm(reference,"fro"));
end

function value = artifact_names(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    [~,name,extension] = fileparts(paths(k));
    value(k) = string(name)+string(extension);
end
end

function value = contains_forbidden_input(input)
forbidden = [ ...
    "linearization";"reduced";"partition";"dailyThomas"; ...
    "dailyResponses";"aggregation";"core";"recovery"; ...
    "fullResult";"recursiveResult";"audit"];
value = contains_forbidden_field(input,forbidden);
end

function found = contains_forbidden_field(value,forbidden)
found = false;
if isstruct(value)
    names = string(fieldnames(value));
    if any(ismember(names,forbidden))
        found = true;
        return
    end
    for element = 1:numel(value)
        for k = 1:numel(names)
            if contains_forbidden_field( ...
                    value(element).(names(k)),forbidden)
                found = true;
                return
            end
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        if contains_forbidden_field(value{k},forbidden)
            found = true;
            return
        end
    end
end
end

function value = source_line_count(source)
value = numel(regexp(strtrim(source),'\r\n|\n|\r','split'));
end
