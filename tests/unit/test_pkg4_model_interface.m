function tests = test_pkg4_model_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot,"src");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(sourceRoot);

stateResult = rkkt.model.validation.runState( ...
    Interactive=false,WriteArtifacts=true);
linearizationResult = rkkt.model.validation.runLinearization( ...
    Interactive=false,WriteArtifacts=true);
residualResult = rkkt.model.validation.runResidual( ...
    Interactive=false,WriteArtifacts=true);
jacobianResult = rkkt.model.validation.runJacobian( ...
    Interactive=false,WriteArtifacts=true);
hessianResult = rkkt.model.validation.runHessian( ...
    Interactive=false,WriteArtifacts=true);

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.stateResult = stateResult;
testCase.TestData.linearizationResult = linearizationResult;
testCase.TestData.residualResult = residualResult;
testCase.TestData.jacobianResult = jacobianResult;
testCase.TestData.hessianResult = hessianResult;
testCase.TestData.data = stateResult.input.projectData;
testCase.TestData.index = stateResult.input.index;
testCase.TestData.config = stateResult.input.config;
testCase.TestData.state = stateResult.output.state;
testCase.TestData.linearization = ...
    linearizationResult.output.linearization;
end

function testPackageInfoMarksPkg4InterfacesImplemented(testCase)
value = rkkt.info();
verifyEqual(testCase,string(value.package_version),"0.8.0");
verifyEqual(testCase,string(value.pkg_stage),"PKG-8");
required = [ ...
    "rkkt.model.initialize"
    "rkkt.model.linearize"
    "rkkt.model.residualView"
    "rkkt.model.jacobianView"
    "rkkt.model.hessianView"];
verifyTrue(testCase,all(ismember(required, ...
    string(value.implemented_public_interfaces))));
end

function testInitializeFacadeMatchesLegacyExactly(testCase)
result = testCase.TestData.stateResult;
verifyTrue(testCase,result.diagnostics.legacy_facade_exact_equal);
verifyTrue(testCase, ...
    result.diagnostics.objective_facts.legacy_facade_exact_equal);
verifyEqual(testCase,string(result.meta.production_function), ...
    "initialize_stage_a4_state");
end

function testStateDimensionsPositivityAndInitialCounters(testCase)
state = testCase.TestData.state;
verifySize(testCase,state.xi,[3722,1]);
verifySize(testCase,state.y,[618,1]);
verifySize(testCase,state.l,[7248,1]);
verifySize(testCase,state.z,[7248,1]);
verifyTrue(testCase,all(isfinite( ...
    [state.xi;state.y;state.l;state.z])));
verifyTrue(testCase,all(state.l > 0));
verifyTrue(testCase,all(state.z > 0));
verifyEqual(testCase,state.iteration_index,0);
verifyEqual(testCase,state.state_revision,0);
verifyEqual(testCase,state.newton_direction_number,0);
verifyEqual(testCase,state.completed_newton_direction_count,0);
end

function testStateFixedZeroAndDailySocSemanticsRemainExact(testCase)
state = testCase.TestData.state;
index = testCase.TestData.index;
verifySize(testCase,state.fixed_zero_values,[422,1]);
verifyEqual(testCase,state.fixed_zero_values,zeros(422,1));
verifyEqual(testCase,state.fixed_zero_directions,zeros(422,1));
verifyEqual(testCase,state.fixed_zero_values, ...
    index.fixed_zero_map.fixed_value);
verifyEqual(testCase,state.fixed_zero_directions, ...
    index.fixed_zero_map.fixed_direction_value);

variables = index.variable_index;
pch = variables(variables.hour > 0 & ...
    string(variables.variable_name) == "Pch",:);
pdis = variables(variables.hour > 0 & ...
    string(variables.variable_name) == "Pdis",:);
verifyEqual(testCase,height(pch),336);
verifyEqual(testCase,height(pdis),336);
verifyEmpty(testCase,intersect( ...
    pch.global_index_start,pdis.global_index_start));

links = index.soc_link_map;
for k = 1:height(links)
    row = links(k,:);
    if row.hour == 1
        verifyTrue(testCase,isnan(row.predecessor_hour));
        verifyEqual(testCase,row.predecessor_soc_global_index,0);
        verifyEqual(testCase,row.initial_energy_fraction,0.5);
    else
        predecessor = variables(row.predecessor_soc_global_index,:);
        verifyEqual(testCase,predecessor.day,row.day);
        verifyEqual(testCase,predecessor.hour,row.hour-1);
    end
    if row.hour == 24
        verifyTrue(testCase,row.terminal_equality);
        verifyEqual(testCase,row.terminal_energy_fraction,0.5);
    end
end
end

function testLinearizeFacadeMatchesLegacyAndConsumesExplicitState(testCase)
result = testCase.TestData.linearizationResult;
linearization = testCase.TestData.linearization;
state = testCase.TestData.state;
verifyTrue(testCase,result.diagnostics.legacy_facade_exact_equal);
verifyTrue(testCase,result.diagnostics.explicit_state_exact_equal);
verifyTrue(testCase,isequaln(linearization.state,state));

modifiedState = state;
modifiedState.y(1) = modifiedState.y(1)+0.125;
modifiedState.state_revision = 1;
modified = rkkt.model.linearize(modifiedState, ...
    testCase.TestData.data,testCase.TestData.index, ...
    testCase.TestData.config);
verifyTrue(testCase,isequaln(modified.state,modifiedState));
verifyTrue(testCase,contains(string(modified.identity),"revision1"));
verifyFalse(testCase,isequaln( ...
    modified.r_dual,linearization.r_dual));
end

function testLinearizationRequiredFieldsMatricesAndResidualDimensions( ...
        testCase)
value = testCase.TestData.linearization;
required = [ ...
    "identity"
    "state"
    "jacobian"
    "hessian"
    "H"
    "A"
    "G"
    "r_dual"
    "r_eq"
    "r_ineq"
    "r_comp"
    "l"
    "z"
    "mu"];
verifyTrue(testCase,all(ismember(required,string(fieldnames(value)))));
verifySize(testCase,value.H,[3722,3722]);
verifySize(testCase,value.A,[618,3722]);
verifySize(testCase,value.G,[7248,3722]);
verifyTrue(testCase,issparse(value.H));
verifyTrue(testCase,issparse(value.A));
verifyTrue(testCase,issparse(value.G));
verifyEqual(testCase,nnz(value.H),0);
verifySize(testCase,value.r_dual,[3722,1]);
verifySize(testCase,value.r_eq,[618,1]);
verifySize(testCase,value.r_ineq,[7248,1]);
verifySize(testCase,value.r_comp,[7248,1]);
verifyTrue(testCase,isequaln(value.jacobian.A,value.A));
verifyTrue(testCase,isequaln(value.jacobian.G,value.G));
verifyTrue(testCase,isequaln(value.hessian.H,value.H));
end

function testResidualJacobianHessianViewsShareIdentityAndExactPayloads( ...
        testCase)
linearization = testCase.TestData.linearization;
residual = testCase.TestData.residualResult.output.residualView;
jacobian = testCase.TestData.jacobianResult.output.jacobianView;
hessian = testCase.TestData.hessianResult.output.hessianView;
identities = [string(linearization.identity); ...
    string(residual.identity);string(jacobian.identity); ...
    string(hessian.identity)];
verifyEqual(testCase,numel(unique(identities)),1);
verifyTrue(testCase,isequaln(residual.r_dual,linearization.r_dual));
verifyTrue(testCase,isequaln(residual.r_eq,linearization.r_eq));
verifyTrue(testCase,isequaln(residual.r_ineq,linearization.r_ineq));
verifyTrue(testCase,isequaln(residual.r_comp,linearization.r_comp));
verifyTrue(testCase,isequaln(residual.l,linearization.l));
verifyTrue(testCase,isequaln(residual.z,linearization.z));
verifyTrue(testCase,isequaln(residual.mu,linearization.mu));
verifyTrue(testCase,isequaln(jacobian.A,linearization.A));
verifyTrue(testCase,isequaln(jacobian.G,linearization.G));
verifyTrue(testCase,isequaln(hessian.H,linearization.H));

sentinel = synthetic_linearization();
verifyEqual(testCase,rkkt.model.residualView(sentinel).identity, ...
    sentinel.identity);
verifyEqual(testCase,rkkt.model.jacobianView(sentinel).identity, ...
    sentinel.identity);
verifyEqual(testCase,rkkt.model.hessianView(sentinel).identity, ...
    sentinel.identity);
end

function testObservationSourcesNeverInitializeOrLinearize(testCase)
sourceRoot = testCase.TestData.sourceRoot;
files = [ ...
    fullfile(sourceRoot,"+rkkt","+model","residualView.m")
    fullfile(sourceRoot,"+rkkt","+model","jacobianView.m")
    fullfile(sourceRoot,"+rkkt","+model","hessianView.m")
    fullfile(sourceRoot,"+rkkt","+model","+validation","runResidual.m")
    fullfile(sourceRoot,"+rkkt","+model","+validation","runJacobian.m")
    fullfile(sourceRoot,"+rkkt","+model","+validation","runHessian.m")];
for k = 1:numel(files)
    text = fileread(files(k));
    forbiddenCalls = { ...
        'initialize_stage_a4_state\s*\(', ...
        'build_stage_a4_linearization\s*\(', ...
        'build_stage_a_multiday_linearization\s*\(', ...
        'rkkt\.model\.initialize\s*\(', ...
        'rkkt\.model\.linearize\s*\('};
    for p = 1:numel(forbiddenCalls)
        verifyEmpty(testCase,regexp(text, ...
            forbiddenCalls{p},"once"));
    end
end

initializeText = fileread(fullfile( ...
    sourceRoot,"+rkkt","+model","initialize.m"));
linearizeText = fileread(fullfile( ...
    sourceRoot,"+rkkt","+model","linearize.m"));
initializeCalls = regexp(initializeText, ...
    '(?m)^\s*state\s*=\s*initialize_stage_a4_state\s*\(',"match");
linearizeCalls = regexp(linearizeText, ...
    ['(?m)^\s*linearization\s*=\s*' ...
    'build_stage_a4_linearization\s*\('],"match");
verifyEqual(testCase,numel(initializeCalls),1);
verifyEqual(testCase,numel(linearizeCalls),1);
verifyEmpty(testCase,regexp(initializeText, ...
    'initialize_stage_a_multiday_state\s*\(',"once"));
verifyEmpty(testCase,regexp(linearizeText, ...
    'build_stage_a_multiday_linearization\s*\(',"once"));
verifyEmpty(testCase,regexp(linearizeText, ...
    'rkkt\.model\.initialize\s*\(',"once"));
end

function testFiveValidationEntriesFollowTheUpstreamMatChain(testCase)
sourceRoot = testCase.TestData.sourceRoot;
stateResult = testCase.TestData.stateResult;
linearizationResult = testCase.TestData.linearizationResult;
residualResult = testCase.TestData.residualResult;
jacobianResult = testCase.TestData.jacobianResult;
hessianResult = testCase.TestData.hessianResult;
indexArtifact = fullfile(sourceRoot,"+rkkt","+indexing", ...
    "+validation","索引模块输出.mat");
verifyEqual(testCase,string(stateResult.meta.input_artifact), ...
    string(indexArtifact));
verifyEqual(testCase,string(linearizationResult.meta.input_artifact), ...
    string(stateResult.meta.output_file));
for result = {residualResult,jacobianResult,hessianResult}
    verifyEqual(testCase,string(result{1}.meta.input_artifact), ...
        string(linearizationResult.meta.output_file));
    verifyEqual(testCase,string( ...
        result{1}.input.upstreamMetadata.interface_name), ...
        "rkkt.model.linearize");
end
verifyEqual(testCase,string( ...
    linearizationResult.input.upstreamMetadata.interface_name), ...
    "rkkt.model.initialize");
verifyEqual(testCase,string( ...
    stateResult.input.upstreamMetadata.interface_name), ...
    "rkkt.indexing.build");
end

function testFiveValidationEntriesWriteFixedMatCsvAndFigures(testCase)
results = { ...
    testCase.TestData.stateResult
    testCase.TestData.linearizationResult
    testCase.TestData.residualResult
    testCase.TestData.jacobianResult
    testCase.TestData.hessianResult};
matFiles = strings(5,1);
tableFiles = strings(0,1);
figureFiles = strings(0,1);
for k = 1:numel(results)
    rkkt.contracts.validateModuleResult(results{k});
    matFiles(k) = string(results{k}.meta.output_file);
    tableFiles = [tableFiles;results{k}.tableFiles]; %#ok<AGROW>
    figureFiles = [figureFiles;results{k}.figureFiles]; %#ok<AGROW>
end
verifyTrue(testCase,all(isfile(matFiles)));
verifyTrue(testCase,all(isfile(tableFiles)));
verifyTrue(testCase,all(isfile(figureFiles)));
verifyEqual(testCase,artifact_names(matFiles),[ ...
    "状态模块输出.mat"
    "统一线性化模块输出.mat"
    "残差观察输出.mat"
    "Jacobian观察输出.mat"
    "Hessian观察输出.mat"]);
verifyEqual(testCase,artifact_names(tableFiles),[ ...
    "状态向量维数与范围.csv"
    "线性化字段维数.csv"
    "初始残差范数.csv"
    "残差分量摘要.csv"
    "Jacobian维数与非零元.csv"
    "Hessian维数与非零元.csv"]);
verifyEqual(testCase,artifact_names(figureFiles),[ ...
    "初始状态摘要.fig"
    "初始状态摘要.png"
    "H_A_G稀疏结构.fig"
    "H_A_G稀疏结构.png"
    "残差范数.fig"
    "残差范数.png"
    "Jacobian稀疏结构.fig"
    "Jacobian稀疏结构.png"
    "Hessian稀疏结构.fig"
    "Hessian稀疏结构.png"]);
end

function value = synthetic_linearization()
value = struct( ...
    "identity","PKG4-SENTINEL-IDENTITY", ...
    "r_dual",[1;-2], ...
    "r_eq",3, ...
    "r_ineq",[0;4], ...
    "r_comp",[5;6], ...
    "l",[7;8], ...
    "z",[9;10], ...
    "mu",0.25, ...
    "jacobian",struct("A",sparse([1,0]), ...
        "G",sparse([0,1;1,0])), ...
    "hessian",struct("H",sparse(2,2)), ...
    "A",sparse([1,0]), ...
    "G",sparse([0,1;1,0]), ...
    "H",sparse(2,2));
end

function value = artifact_names(paths)
value = strings(numel(paths),1);
for k = 1:numel(paths)
    [~,name,extension] = fileparts(paths(k));
    value(k) = string(name)+string(extension);
end
end
