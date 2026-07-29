function tests = test_pkg1_package_contracts
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
sourceRoot = fullfile(repositoryRoot,"src");
addpath(sourceRoot);
testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.pathCleanup = onCleanup(@()rmpath(sourceRoot));
end

function testPackageSkeletonIsResolvable(testCase)
expected = [
    "src/+rkkt"
    "src/+rkkt/+contracts"
    "src/+rkkt/+data"
    "src/+rkkt/+data/+validation"
    "src/+rkkt/+indexing"
    "src/+rkkt/+indexing/+validation"
    "src/+rkkt/+model"
    "src/+rkkt/+model/+validation"
    "src/+rkkt/+solver"
    "src/+rkkt/+solver/+validation"
    "src/+rkkt/+ipm"
    "src/+rkkt/+ipm/+validation"
    "src/+rkkt/+artifacts"
    "src/+rkkt/+reporting"
    "src/+rkkt/+workflows"
    ];
for k = 1:numel(expected)
    verifyTrue(testCase,isfolder(fullfile(testCase.TestData.repositoryRoot, ...
        replace(expected(k),"/",filesep))), ...
        "Missing package folder: "+expected(k));
end
verifyNotEmpty(testCase,which("rkkt.info"));
verifyNotEmpty(testCase,which("rkkt.contracts.validateModuleResult"));
end

function testPackageInfoFreezesDependencyOrder(testCase)
value = rkkt.info();
verifyEqual(testCase,value.package_name,"rkkt");
verifyEqual(testCase,value.package_version,"0.8.0");
verifyEqual(testCase,value.contract_version,"1.0");
verifyEqual(testCase,value.pkg_stage,"PKG-8");
verifyEqual(testCase,value.dependency_order, ...
    ["contracts";"data";"indexing";"model";"solver";"ipm";"workflows"]);
verifyEqual(testCase,value.implemented_public_interfaces, ...
    ["rkkt.info";"rkkt.data.load";"rkkt.indexing.build"; ...
    "rkkt.model.initialize";"rkkt.model.linearize"; ...
    "rkkt.model.residualView";"rkkt.model.jacobianView"; ...
    "rkkt.model.hessianView";"rkkt.solver.assembleFullKKT"; ...
    "rkkt.solver.solveFullKKT"; ...
    "rkkt.solver.eliminateInequalities"; ...
    "rkkt.solver.partitionRecursiveSystem"; ...
    "rkkt.solver.solveDayChain"; ...
    "rkkt.solver.buildDayResponse"; ...
    "rkkt.solver.aggregateDayResponses"; ...
    "rkkt.solver.solveGlobalCore"; ...
    "rkkt.solver.recoverDirection"; ...
    "rkkt.solver.verifyEquivalence"; ...
    "rkkt.ipm.step";"rkkt.ipm.solve"; ...
    "rkkt.artifacts.export";"rkkt.reporting.generate"]);
verifyTrue(testCase,value.production_callers_migrated);
verifyFalse(testCase,value.production_algorithm_migrated);
verifyFalse(testCase,value.convergence_evaluated);
end

function testNamedContractsHaveStableOrderedFields(testCase)
verifyEqual(testCase,rkkt.contracts.requiredFields("moduleResult"), ...
    ["meta";"input";"output";"intermediate";"diagnostics"; ...
    "indexDescription";"tableFiles";"figureFiles"]);
verifyEqual(testCase,rkkt.contracts.requiredFields("moduleMetadata"), ...
    ["interface_name";"production_function";"input_artifact"; ...
    "input_sha256";"git_commit";"stage_id";"day";"hour"; ...
    "iteration";"revision";"matlab_version";"generated_at"; ...
    "contract_version"]);
verifyError(testCase,@()rkkt.contracts.requiredFields("unknown"), ...
    "rkkt:contracts:UnknownContract");
end

function testRequireFieldsIsReadOnlyAndAllowsDeclaredExtensions(testCase)
value = struct("alpha",1,"beta",2,"extension",3);
frozen = value;
rkkt.contracts.requireFields(value,["alpha","beta"],"fixture");
verifyEqual(testCase,value,frozen);
verifyError(testCase,@()rkkt.contracts.requireFields(value, ...
    ["alpha","beta"],"fixture","AllowAdditionalFields",false), ...
    "rkkt:contracts:UnexpectedField");
end

function testRequireFieldsRejectsMissingAndInvalidContracts(testCase)
value = struct("alpha",1);
verifyError(testCase,@()rkkt.contracts.requireFields(value, ...
    ["alpha","beta"],"fixture"),"rkkt:contracts:MissingField");
verifyError(testCase,@()rkkt.contracts.requireFields(value, ...
    ["alpha","alpha"],"fixture"), ...
    "rkkt:contracts:InvalidFieldContract");
verifyError(testCase,@()rkkt.contracts.requireStruct([value,value], ...
    "fixture"),"rkkt:contracts:ExpectedScalarStruct");
end

function testRequireTextScalarPreservesTextSemantics(testCase)
rkkt.contracts.requireTextScalar("rkkt.data.load","interface");
rkkt.contracts.requireTextScalar("","optional","AllowEmpty",true);
verifyError(testCase,@()rkkt.contracts.requireTextScalar("", ...
    "interface"),"rkkt:contracts:EmptyText");
verifyError(testCase,@()rkkt.contracts.requireTextScalar(["a","b"], ...
    "interface"),"rkkt:contracts:ExpectedTextScalar");
end

function testRequireNumericArrayChecksShapeFiniteAndStorage(testCase)
value = sparse([1,0;0,2]);
frozen = value;
rkkt.contracts.requireNumericArray(value,"K", ...
    "ExpectedSize",[2,2],"SparseMode","sparse");
verifyEqual(testCase,value,frozen);
verifyError(testCase,@()rkkt.contracts.requireNumericArray(value,"K", ...
    "ExpectedSize",[2,3]),"rkkt:contracts:UnexpectedSize");
verifyError(testCase,@()rkkt.contracts.requireNumericArray(full(value), ...
    "K","SparseMode","sparse"),"rkkt:contracts:ExpectedSparse");
verifyError(testCase,@()rkkt.contracts.requireNumericArray([1,NaN], ...
    "rhs"),"rkkt:contracts:ExpectedFinite");
end

function testModuleResultTemplateHasFrozenTopLevelSchema(testCase)
metadata = validMetadata();
frozen = metadata;
value = rkkt.contracts.moduleResultTemplate(metadata);
verifyEqual(testCase,metadata,frozen);
verifyEqual(testCase,string(fieldnames(value)), ...
    rkkt.contracts.requiredFields("moduleResult"));
verifyEqual(testCase,value.meta,metadata);
verifyEqual(testCase,value.tableFiles,strings(0,1));
verifyEqual(testCase,value.figureFiles,strings(0,1));
rkkt.contracts.validateModuleResult(value);
end

function testModuleResultAllowsUnmodifiedProductionPayloads(testCase)
value = rkkt.contracts.moduleResultTemplate(validMetadata());
payload = struct("matrix",sparse([1,0;0,3]), ...
    "vector",[1;2],"identity","fixture-identity");
value.input = struct("source","fixture.mat");
value.output = payload;
value.intermediate = struct("factor_count",1);
value.diagnostics = struct("relative_residual",1.2e-12, ...
    "fixed_zero_exact",true);
value.indexDescription = struct("canonical_order","xi_y_l_z");
value.tableFiles = ["tables/维数表.csv";"tables/残差表.csv"];
value.figureFiles = "figures/结构图.png";
frozen = value;
rkkt.contracts.validateModuleResult(value);
verifyEqual(testCase,value,frozen);
end

function testModuleResultRejectsMissingOrAdditionalTopLevelFields(testCase)
value = rkkt.contracts.moduleResultTemplate(validMetadata());
missing = rmfield(value,"output");
verifyError(testCase,@()rkkt.contracts.validateModuleResult(missing), ...
    "rkkt:contracts:MissingField");
value.extra = true;
verifyError(testCase,@()rkkt.contracts.validateModuleResult(value), ...
    "rkkt:contracts:UnexpectedField");
end

function testModuleMetadataRejectsInvalidIdentityAndVersion(testCase)
metadata = validMetadata();
metadata.input_sha256 = "ABC";
verifyError(testCase,@()rkkt.contracts.validateModuleMetadata(metadata), ...
    "rkkt:contracts:InvalidSha256");
metadata = validMetadata();
metadata.contract_version = "2.0";
verifyError(testCase,@()rkkt.contracts.validateModuleMetadata(metadata), ...
    "rkkt:contracts:ContractVersionMismatch");
metadata = validMetadata();
metadata.interface_name = "load_project_data";
verifyError(testCase,@()rkkt.contracts.validateModuleMetadata(metadata), ...
    "rkkt:contracts:InvalidInterfaceName");
metadata = validMetadata();
metadata.day = [14,14.5];
verifyError(testCase,@()rkkt.contracts.validateModuleMetadata(metadata), ...
    "rkkt:contracts:InvalidContextIndex");
end

function testManualDiagnosticsCannotContainPassFailVerdicts(testCase)
value = rkkt.contracts.moduleResultTemplate(validMetadata());
value.diagnostics = struct("relative_residual",1e-12, ...
    "nested",struct("status","PASS"));
verifyError(testCase,@()rkkt.contracts.validateModuleResult(value), ...
    "rkkt:contracts:ManualVerdictForbidden");
value = rkkt.contracts.moduleResultTemplate(validMetadata());
value.diagnostics = table("FAIL_RETRYABLE", ...
    'VariableNames',"conclusion");
verifyError(testCase,@()rkkt.contracts.validateModuleResult(value), ...
    "rkkt:contracts:ManualVerdictForbidden");
end

function testModuleFileListsAreStringColumns(testCase)
value = rkkt.contracts.moduleResultTemplate(validMetadata());
value.tableFiles = ["a.csv","b.csv"];
verifyError(testCase,@()rkkt.contracts.validateModuleResult(value), ...
    "rkkt:contracts:InvalidFileList");
value = rkkt.contracts.moduleResultTemplate(validMetadata());
value.figureFiles = {'a.png'};
verifyError(testCase,@()rkkt.contracts.validateModuleResult(value), ...
    "rkkt:contracts:InvalidFileList");
end

function value = validMetadata()
value = struct( ...
    "interface_name","rkkt.data.load", ...
    "production_function","load_project_data", ...
    "input_artifact","inputs/raw/input_manifest.csv", ...
    "input_sha256",string(repmat('a',1,64)), ...
    "git_commit",string(repmat('b',1,40)), ...
    "stage_id","stage_A4", ...
    "day",14:20, ...
    "hour",1:24, ...
    "iteration",[], ...
    "revision",0, ...
    "matlab_version","24.1.0", ...
    "generated_at","2026-07-28T12:00:00+08:00", ...
    "contract_version",rkkt.contracts.version());
end
