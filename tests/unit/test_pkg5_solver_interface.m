function tests = test_pkg5_solver_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot,"src");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(sourceRoot);

fullModule = rkkt.solver.validation.runFullKKT( ...
    Interactive=false,WriteArtifacts=true);
reducedModule = rkkt.solver.validation.runReducedKKT( ...
    Interactive=false,WriteArtifacts=true);
linearizationArtifact = string( ...
    fullModule.input.linearizationArtifact);
loaded = load(linearizationArtifact,"moduleResult");
linearizationModule = loaded.moduleResult;

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.linearizationModule = linearizationModule;
testCase.TestData.linearization = ...
    linearizationModule.output.linearization;
testCase.TestData.config = linearizationModule.input.config;
testCase.TestData.fullModule = fullModule;
testCase.TestData.reducedModule = reducedModule;
testCase.TestData.fullResult = fullModule.output.fullResult;
testCase.TestData.reduced = reducedModule.output.reduced;
end

function testAssembleFullKktFacadeMatchesLegacyExactly(testCase)
value = testCase.TestData.fullModule;
verifyTrue(testCase, ...
    value.diagnostics.assembly_legacy_facade_exact_equal);
verifyTrue(testCase, ...
    value.diagnostics.objective_facts. ...
        assembly_legacy_facade_exact_equal);
verifyTrue(testCase, ...
    value.diagnostics.assembly_inside_result_exact_equal);
verifyEqual(testCase,string(value.meta.assembly_interface), ...
    "rkkt.solver.assembleFullKKT");
verifyEqual(testCase, ...
    string(value.meta.assembly_production_function), ...
    "assemble_stage_a_multiday_full_kkt");
end

function testSolveFullKktFacadeMatchesLegacyExactly(testCase)
value = testCase.TestData.fullModule;
verifyTrue(testCase, ...
    value.diagnostics.solve_legacy_facade_exact_equal);
verifyTrue(testCase, ...
    value.diagnostics.objective_facts. ...
        solve_legacy_facade_exact_equal);
verifyEqual(testCase,string(value.meta.interface_name), ...
    "rkkt.solver.solveFullKKT");
verifyEqual(testCase,string(value.meta.production_function), ...
    "solve_stage_a_multiday_full_kkt_direction");
end

function testEliminateInequalitiesFacadeMatchesLegacyExactly(testCase)
value = testCase.TestData.reducedModule;
verifyTrue(testCase,value.diagnostics.legacy_facade_exact_equal);
verifyTrue(testCase, ...
    value.diagnostics.objective_facts.legacy_facade_exact_equal);
verifyEqual(testCase,string(value.meta.interface_name), ...
    "rkkt.solver.eliminateInequalities");
verifyEqual(testCase,string(value.meta.production_function), ...
    "eliminate_stage_a_multiday_inequality_directions");
end

function testAllSolverObjectsShareOneLinearizationIdentity(testCase)
linearization = testCase.TestData.linearization;
fullResult = testCase.TestData.fullResult;
reduced = testCase.TestData.reduced;
identities = [ ...
    string(linearization.identity)
    string(fullResult.linearization_identity)
    string(fullResult.kkt.linearization_identity)
    string(reduced.linearization_identity)
    string(testCase.TestData.fullModule. ...
        diagnostics.linearization_identity)
    string(testCase.TestData.reducedModule. ...
        diagnostics.linearization_identity)];
verifyEqual(testCase,numel(unique(identities)),1);
verifyEqual(testCase,identities, ...
    repmat(string(linearization.identity),numel(identities),1));
end

function testFullKktDimensionsSlicesAndSparsity(testCase)
fullResult = testCase.TestData.fullResult;
kkt = fullResult.kkt;
verifyEqual(testCase,kkt.dimension,18836);
verifySize(testCase,kkt.matrix,[18836,18836]);
verifySize(testCase,kkt.rhs,[18836,1]);
verifySize(testCase,fullResult.direction,[18836,1]);
verifyTrue(testCase,issparse(kkt.matrix));
verifyEqual(testCase,kkt.nnz,51136);
verifyEqual(testCase,nnz(kkt.matrix),51136);

verifySize(testCase,fullResult.components.xi,[3722,1]);
verifySize(testCase,fullResult.components.y,[618,1]);
verifySize(testCase,fullResult.components.l,[7248,1]);
verifySize(testCase,fullResult.components.z,[7248,1]);
verifyEqual(testCase,kkt.slices.xi,(1:3722).');
verifyEqual(testCase,kkt.slices.y,(3723:4340).');
verifyEqual(testCase,kkt.slices.l,(4341:11588).');
verifyEqual(testCase,kkt.slices.z,(11589:18836).');
verifyEqual(testCase,kkt.slices.stationarity_rows,(1:3722).');
verifyEqual(testCase,kkt.slices.equality_rows,(3723:4340).');
verifyEqual(testCase,kkt.slices.slack_rows,(4341:11588).');
verifyEqual(testCase,kkt.slices.complementarity_rows, ...
    (11589:18836).');
verifyTrue(testCase,isequaln(fullResult.components.xi, ...
    fullResult.direction(kkt.slices.xi)));
verifyTrue(testCase,isequaln(fullResult.components.y, ...
    fullResult.direction(kkt.slices.y)));
verifyTrue(testCase,isequaln(fullResult.components.l, ...
    fullResult.direction(kkt.slices.l)));
verifyTrue(testCase,isequaln(fullResult.components.z, ...
    fullResult.direction(kkt.slices.z)));
end

function testFullKktDirectionResidualAndWarnings(testCase)
fullResult = testCase.TestData.fullResult;
config = testCase.TestData.config;
residual = fullResult.kkt.matrix*fullResult.direction- ...
    fullResult.kkt.rhs;
relativeResidual = norm(residual,2)/ ...
    max(1,norm(fullResult.kkt.rhs,2));
verifyLessThanOrEqual(testCase,relativeResidual, ...
    config.tolerances.direct_maximum);
verifyEqual(testCase,relativeResidual, ...
    fullResult.diagnostics.relative_residual, ...
    "AbsTol",10*eps(max(1,relativeResidual)));
verifyEqual(testCase,norm(residual,inf), ...
    fullResult.diagnostics.max_absolute_residual, ...
    "AbsTol",10*eps(max(1,norm(residual,inf))));
verifyFalse(testCase,fullResult.diagnostics.warning_present);
verifyEqual(testCase,strlength( ...
    string(fullResult.diagnostics.warning_id)),0);
verifyEqual(testCase,strlength( ...
    string(fullResult.diagnostics.warning_message)),0);
verifyEqual(testCase,string(fullResult.method), ...
    "sparse_backslash_audit");
end

function testReducedKktDimensionsSparsityThetaAndSymmetry(testCase)
reduced = testCase.TestData.reduced;
linearization = testCase.TestData.linearization;
config = testCase.TestData.config;
verifySize(testCase,reduced.W,[3722,3722]);
verifySize(testCase,reduced.A,[618,3722]);
verifySize(testCase,reduced.saddle,[4340,4340]);
verifyTrue(testCase,issparse(reduced.W));
verifyTrue(testCase,issparse(reduced.A));
verifyTrue(testCase,issparse(reduced.saddle));
verifyEqual(testCase,nnz(reduced.W),8254);
verifyEqual(testCase,nnz(reduced.A),4846);
verifyEqual(testCase,nnz(reduced.saddle),17946);
verifyEqual(testCase,reduced.nnz_W,nnz(reduced.W));
verifyTrue(testCase,isequaln(reduced.A,linearization.A));
verifyTrue(testCase,isequaln(reduced.rhs, ...
    [reduced.b_xi;-linearization.r_eq]));
verifyTrue(testCase,isequaln( ...
    reduced.theta,linearization.z./linearization.l));
verifyTrue(testCase,all(isfinite(reduced.theta)));
verifyTrue(testCase,all(reduced.theta > 0));
symmetryRelative = norm(reduced.W-reduced.W',"fro")/ ...
    max(1,norm(reduced.W,"fro"));
verifyLessThanOrEqual(testCase,symmetryRelative, ...
    config.tolerances.symmetry_relative);
verifyEqual(testCase,symmetryRelative, ...
    reduced.symmetry_relative);
end

function testFullDirectionSatisfiesReducedEquationAndRecovery(testCase)
linearization = testCase.TestData.linearization;
fullResult = testCase.TestData.fullResult;
reduced = testCase.TestData.reduced;
config = testCase.TestData.config;
reducedDirection = [fullResult.components.xi; ...
    fullResult.components.y];
equationResidual = reduced.saddle*reducedDirection-reduced.rhs;
equationRelative = norm(equationResidual,2)/ ...
    max(1,norm(reduced.rhs,2));
verifyLessThanOrEqual(testCase,equationRelative, ...
    config.tolerances.recursive_full_kkt_relative_residual);

dlRecovered = -linearization.r_ineq- ...
    linearization.G*fullResult.components.xi;
dzRecovered = (-linearization.r_comp+ ...
    linearization.z.*linearization.r_ineq+ ...
    linearization.z.*( ...
        linearization.G*fullResult.components.xi))./ ...
    linearization.l;
dlRelative = norm(dlRecovered-fullResult.components.l,2)/ ...
    max(1,norm(fullResult.components.l,2));
dzRelative = norm(dzRecovered-fullResult.components.z,2)/ ...
    max(1,norm(fullResult.components.z,2));
verifyLessThanOrEqual(testCase,dlRelative, ...
    config.tolerances.direction_relative_2norm);
verifyLessThanOrEqual(testCase,dzRelative, ...
    config.tolerances.direction_relative_2norm);
verifyEqual(testCase,string(reduced.recovery_contract), ...
    "dl=-r_ineq-G*dxi; dz=(-r_comp+z.*r_ineq+z.*(G*dxi))./l");
end

function testValidationEntriesWriteFixedArtifactsWithoutDuplication( ...
        testCase)
fullModule = testCase.TestData.fullModule;
reducedModule = testCase.TestData.reducedModule;
rkkt.contracts.validateModuleResult(fullModule);
rkkt.contracts.validateModuleResult(reducedModule);

verifyEqual(testCase,string(reducedModule.meta.input_artifact), ...
    string(fullModule.meta.input_artifact));
verifyEqual(testCase, ...
    string(reducedModule.meta.full_kkt_input_artifact), ...
    string(fullModule.meta.output_file));
verifyEqual(testCase, ...
    string(fullModule.input.linearizationArtifact), ...
    string(fullModule.meta.input_artifact));
verifyEqual(testCase, ...
    string(reducedModule.input.linearizationArtifact), ...
    string(fullModule.meta.input_artifact));
verifyEqual(testCase,string(reducedModule.input.fullKktArtifact), ...
    string(fullModule.meta.output_file));

matFiles = [string(fullModule.meta.output_file); ...
    string(reducedModule.meta.output_file)];
tableFiles = [fullModule.tableFiles;reducedModule.tableFiles];
figureFiles = [fullModule.figureFiles;reducedModule.figureFiles];
verifyTrue(testCase,all(isfile(matFiles)));
verifyTrue(testCase,all(isfile(tableFiles)));
verifyTrue(testCase,all(isfile(figureFiles)));
verifyEqual(testCase,artifact_names(matFiles),[ ...
    "完整KKT模块输出.mat"
    "既约KKT模块输出.mat"]);
verifyEqual(testCase,artifact_names(tableFiles),[ ...
    "完整KKT维数与稀疏性.csv"
    "完整KKT方向残差.csv"
    "完整KKT分块范围.csv"
    "既约KKT维数与稀疏性.csv"
    "不等式消元系数摘要.csv"
    "既约方程与回代一致性.csv"]);
verifyEqual(testCase,artifact_names(figureFiles),[ ...
    "完整KKT稀疏结构.fig"
    "完整KKT稀疏结构.png"
    "既约KKT稀疏结构.fig"
    "既约KKT稀疏结构.png"]);

verifyEqual(testCase,string(fieldnames(fullModule.output)), ...
    "fullResult");
verifyEqual(testCase,string(fieldnames(reducedModule.output)), ...
    "reduced");
verifyFalse(testCase,isfield(fullModule.input,"linearization"));
verifyFalse(testCase,isfield(fullModule.input,"assembly"));
verifyFalse(testCase,isfield(fullModule.input,"fullResult"));
verifyFalse(testCase,isfield(reducedModule.input,"linearization"));
verifyFalse(testCase,isfield(reducedModule.input,"fullResult"));
verifyFalse(testCase,isfield(reducedModule.input,"reduced"));
for k = 1:numel(matFiles)
    verifyEqual(testCase,string(who("-file",matFiles(k))), ...
        "moduleResult");
end
verifyEqual(testCase,count_sparse_size( ...
    fullModule,[18836,18836]),1);
verifyEqual(testCase,count_sparse_size( ...
    reducedModule,[3722,3722]),1);
verifyEqual(testCase,count_sparse_size( ...
    reducedModule,[618,3722]),1);
verifyEqual(testCase,count_sparse_size( ...
    reducedModule,[4340,4340]),1);
end

function testPkg5SourcesUseOnlyAuthorizedSolverCalls(testCase)
sourceRoot = testCase.TestData.sourceRoot;
facadeFiles = [ ...
    fullfile(sourceRoot,"+rkkt","+solver","assembleFullKKT.m")
    fullfile(sourceRoot,"+rkkt","+solver","solveFullKKT.m")
    fullfile(sourceRoot,"+rkkt","+solver", ...
        "eliminateInequalities.m")];
validationFiles = [ ...
    fullfile(sourceRoot,"+rkkt","+solver","+validation", ...
        "runFullKKT.m")
    fullfile(sourceRoot,"+rkkt","+solver","+validation", ...
        "runReducedKKT.m")];
productionCalls = [ ...
    "assemble_stage_a_multiday_full_kkt"
    "solve_stage_a_multiday_full_kkt_direction"
    "eliminate_stage_a_multiday_inequality_directions"];
for k = 1:numel(facadeFiles)
    text = fileread(facadeFiles(k));
    for p = 1:numel(productionCalls)
        matches = regexp(text, ...
            productionCalls(p)+"\s*\(","match");
        if p == k
            verifyEqual(testCase,numel(matches),1);
        else
            verifyEmpty(testCase,matches);
        end
    end
end

files = [facadeFiles;validationFiles];
forbiddenCalls = { ...
    'build_stage_a4_linearization\s*\(', ...
    'build_stage_a_multiday_linearization\s*\(', ...
    'rkkt\.model\.linearize\s*\(', ...
    'rkkt\.model\.initialize\s*\(', ...
    'initialize_stage_a4_state\s*\(', ...
    'partition_(?:stage_a_multiday_)?recursive_system\s*\(', ...
    'form_(?:stage_a_multiday_)?day_response\s*\(', ...
    'aggregate_(?:stage_a_multiday_)?day_responses\s*\(', ...
    'solve_(?:stage_a_multiday_)?core16_ldl\s*\(', ...
    'recover_(?:stage_a_multiday_)?recursive_direction\s*\(', ...
    'solve_(?:stage_a_multiday_)?recursive_direction\s*\(', ...
    'run_stage_a4_full_ipm\s*\(', ...
    'update_primal_dual_state\s*\(', ...
    'compute_fraction_to_boundary_step\s*\(', ...
    '(?<![A-Za-z0-9_])inv\s*\(', ...
    '(?<![A-Za-z0-9_])pinv\s*\(', ...
    '(?<![A-Za-z0-9_])lsqminnorm\s*\(', ...
    '(?<![A-Za-z0-9_])full\s*\(', ...
    'mldivide\s*\(', ...
    'linsolve\s*\(', ...
    '(?<![A-Za-z0-9_])ldl\s*\(', ...
    '(?<![A-Za-z0-9_])decomposition\s*\('};
for k = 1:numel(files)
    text = fileread(files(k));
    for p = 1:numel(forbiddenCalls)
        verifyEmpty(testCase,regexp(text, ...
            forbiddenCalls{p},"once"));
    end
end

reducedValidationText = fileread(validationFiles(2));
verifyEmpty(testCase,regexp(reducedValidationText, ...
    '\s+\\\s+',"once"));
reducedFacadeText = fileread(facadeFiles(3));
verifyEmpty(testCase,regexp(reducedFacadeText, ...
    '\s+\\\s+',"once"));
end

function value = artifact_names(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    [~,name,extension] = fileparts(paths(k));
    value(k) = string(name)+string(extension);
end
end

function count = count_sparse_size(value,targetSize)
count = 0;
if isnumeric(value) || islogical(value)
    if issparse(value) && isequal(size(value),targetSize)
        count = 1;
    end
    return
end
if isstruct(value)
    names = fieldnames(value);
    for element = 1:numel(value)
        for k = 1:numel(names)
            count = count+count_sparse_size( ...
                value(element).(names{k}),targetSize);
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        count = count+count_sparse_size(value{k},targetSize);
    end
end
end
