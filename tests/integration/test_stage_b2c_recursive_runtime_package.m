function tests = test_stage_b2c_recursive_runtime_package
%TEST_STAGE_B2C_RECURSIVE_RUNTIME_PACKAGE Direct structural-route contract.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root,"src"));
settings = rkkt.config.build_stage_b2c_run_settings(root, ...
    DayStart=14,DayEnd=20,AuditMode="recursive_only", ...
    RunOutputMode="lightweight",ParallelEnabled=false,CacheEnabled=true);
[data,~] = rkkt.cache.load_or_build_project_data(root,Enabled=true);
config = rkkt.model.build_stage_b2c_runtime_configuration( ...
    root,settings,data);
[recursiveStructure,firstStructureInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        root,data,config,Enabled=true,ForceRebuild=false);
[recursiveStructureAgain,cacheInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        root,data,config,Enabled=true,ForceRebuild=false);
numericalPayload = ...
    rkkt.model.build_stage_b2c_recursive_numerical_payload( ...
        data,recursiveStructureAgain,config);
[index,~] = rkkt.cache.load_or_build_stage_b2c_index( ...
    root,data,config,Enabled=true);
[legacyTemplate,~] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_block_template( ...
        root,data,index,config,Enabled=true);
testCase.TestData.root = root;
testCase.TestData.data = data;
testCase.TestData.config = config;
testCase.TestData.index = index;
testCase.TestData.legacy_template = legacyTemplate;
testCase.TestData.recursive_structure = recursiveStructure;
testCase.TestData.numerical_payload = numericalPayload;
testCase.TestData.first_structure_info = firstStructureInfo;
testCase.TestData.cache_info = cacheInfo;
end

function testCacheHitBypassesCanonicalIndex(testCase)
info = testCase.TestData.cache_info;
verifyEqual(testCase,info.status,"HIT");
verifyTrue(testCase,info.hit);
verifyFalse(testCase,info.canonical_index_loaded);
verifyEqual(testCase,info.canonical_index_load_seconds,0,"AbsTol",0);
verifyFalse(testCase,info.canonical_index_built);
verifyEqual(testCase,info.canonical_index_build_seconds,0,"AbsTol",0);
verifyNotEmpty(testCase,info.topology_fingerprint);
end

function testPayloadIsCompactAndContainsNoCanonicalIndex(testCase)
info = testCase.TestData.cache_info;
verifyLessThan(testCase,info.bytes,100*1024^2);
loaded = load(char(info.path),"structure");
forbidden = ["index","stage_a_base_index","variable_index", ...
    "constraint_index","permutation_map","equality_offset", ...
    "base_G","water_bound","capacity_parameters", ...
    "objective_original_gradient"];
verifyFalse(testCase,has_forbidden(loaded.structure,forbidden));
verifyEqual(testCase,string(loaded.structure.version), ...
    "stage-B2C-recursive-structure-v1.0");
verifyEqual(testCase,string(testCase.TestData.numerical_payload.version), ...
    "stage-B2C-recursive-numerical-payload-v1.0");
verifyEqual(testCase, ...
    testCase.TestData.numerical_payload.topology_fingerprint, ...
    loaded.structure.topology_fingerprint);
end

function testInitialResidualDirectionAndCoreAreExactlyEqual(testCase)
data = testCase.TestData.data;
config = testCase.TestData.config;
index = testCase.TestData.index;
legacyTemplate = testCase.TestData.legacy_template;
runtimePackage = testCase.TestData.numerical_payload;
[legacyState,~] = rkkt.model.initialize_stage_b2c_state( ...
    data,index,config,RecursiveBlockTemplate=legacyTemplate);
runtimeState = rkkt.model.initialize_stage_b2c_runtime_state( ...
    data,runtimePackage,config);
for name = ["xi","y","l","z"]
    verifyEqual(testCase,runtimeState.(name),legacyState.(name), ...
        "AbsTol",0);
end
legacyLin = rkkt.model.update_stage_b2c_recursive_block_linearization( ...
    legacyState,legacyTemplate);
runtimeLin = rkkt.model.update_stage_b2c_recursive_block_linearization( ...
    runtimeState,runtimePackage.template);
for name = ["r_eq","r_ineq","r_dual","r_comp"]
    verifyEqual(testCase,runtimeLin.(name),legacyLin.(name),"AbsTol",0);
end
legacyDirection = solve_direction(legacyLin,config);
runtimeDirection = solve_direction(runtimeLin,config);
verifyEqual(testCase,runtimeDirection.direction, ...
    legacyDirection.direction,"AbsTol",0);
for name = ["matrix","rhs","solution","delta_q","delta_rho"]
    verifyEqual(testCase,runtimeDirection.core.(name), ...
        legacyDirection.core.(name),"AbsTol",0);
end
verifyEqual(testCase,size(runtimeDirection.core.matrix),[16,16]);
end

function testConvergedCapacityDispatchAndAuditAreExactlyEqual(testCase)
root = testCase.TestData.root;
data = testCase.TestData.data;
config = testCase.TestData.config;
index = testCase.TestData.index;
runtimePackage = testCase.TestData.numerical_payload;
legacyRoot = string(tempname);
runtimeRoot = string(tempname);
guard = onCleanup(@()remove_directories([legacyRoot,runtimeRoot]));
legacyContext = make_temporary_context(legacyRoot,root,"LEGACY_INDEX");
runtimeContext = make_temporary_context(runtimeRoot,root,"RUNTIME_PACKAGE");
signature = rkkt.artifacts.compute_package_code_signature(root);
legacy = rkkt.solver.run_stage_b2c_365day_serial_ipm( ...
    data,index,config,legacyContext,MaxIterations=100, ...
    SolverCodeSignature=signature,CheckpointEnabled=false, ...
    RecursiveBlockTemplate=testCase.TestData.legacy_template);
runtime = rkkt.solver.run_stage_b2c_365day_serial_ipm( ...
    data,runtimePackage,config,runtimeContext,MaxIterations=100, ...
    SolverCodeSignature=signature,CheckpointEnabled=false);
verifyTrue(testCase,legacy.convergence_achieved);
verifyTrue(testCase,runtime.convergence_achieved);
verifyEqual(testCase,runtime.accepted_iteration_count, ...
    legacy.accepted_iteration_count);
for name = ["xi","y","l","z"]
    verifyEqual(testCase,runtime.final_state.(name), ...
        legacy.final_state.(name),"AbsTol",0);
end
verifyEqual(testCase,runtime.final_metrics,legacy.final_metrics);

legacyPhysical = rkkt.model.recover_stage_a_physical_arrays( ...
    legacy.final_state.xi,zeros(size(legacy.final_state.xi)),index,data);
runtimePhysical = rkkt.model.recover_stage_b2c_runtime_physical_arrays( ...
    runtime.final_state.xi,zeros(size(runtime.final_state.xi)), ...
    runtimePackage,data);
[legacyCapacity,legacyHourly,legacyDaily] = ...
    rkkt.model.build_stage_b2c_physical_results( ...
        "LEGACY_INDEX",legacy,index,legacyPhysical);
[runtimeCapacity,runtimeHourly,runtimeDaily] = ...
    rkkt.model.build_stage_b2c_physical_results( ...
        "RUNTIME_PACKAGE",runtime,runtimePackage,runtimePhysical);
verifyEqual(testCase,without_run_id(runtimeCapacity), ...
    without_run_id(legacyCapacity));
verifyEqual(testCase,without_run_id(runtimeHourly), ...
    without_run_id(legacyHourly));
verifyEqual(testCase,without_run_id(runtimeDaily), ...
    without_run_id(legacyDaily));
legacyAudit = rkkt.diagnostics.evaluate_stage_b2c_physical_audit( ...
    legacy,index,data,config);
runtimeAudit = rkkt.diagnostics.evaluate_stage_b2c_physical_audit( ...
    runtime,runtimePackage,data,config);
verifyTrue(testCase,legacyAudit.passed);
verifyTrue(testCase,runtimeAudit.passed);
verifyEqual(testCase,runtimeAudit.maximum_water_violation, ...
    legacyAudit.maximum_water_violation,"AbsTol",0);
verifyEqual(testCase,without_run_id(runtimeAudit.water), ...
    without_run_id(legacyAudit.water));
clear guard
remove_directories([legacyRoot,runtimeRoot]);
end

function value = solve_direction(lin,config)
value = rkkt.solver.solve_stage_b2c_daily_joint_direction( ...
    lin,JointMicroborderEnabled=false, ...
    SymmetryTolerance=config.reduced_symmetry_tolerance, ...
    LocalResidualTolerance=config.local_linear_solve_residual_tolerance, ...
    ReconstructedKktResidualTolerance= ...
        config.recursive_full_kkt_residual_tolerance, ...
    RefinementPasses=config.recursive_refinement_max_passes, ...
    CoreConsistencyMaximumPasses=config.core_consistency_max_passes, ...
    CompensatedCoreAccumulation=config.compensated_core_accumulation);
end

function found = has_forbidden(value,forbidden)
found = false;
if ~isstruct(value), return; end
for item = reshape(value,1,[])
    names = string(fieldnames(item));
    if any(ismember(names,forbidden)), found=true; return; end
    for name = reshape(names,1,[])
        child = item.(name);
        if isstruct(child) && has_forbidden(child,forbidden)
            found=true; return
        end
    end
end
end

function value = without_run_id(value)
if ismember("run_id",string(value.Properties.VariableNames))
    value.run_id = [];
end
end

function context = make_temporary_context(pathValue,root,runId)
mkdir(pathValue);
diagnostics = fullfile(pathValue,"diagnostics");
checkpoints = fullfile(pathValue,"checkpoints");
mkdir(diagnostics); mkdir(checkpoints);
effectiveConfig = fullfile(pathValue,"effective_config.yaml");
copyfile(fullfile(root,"config","RUN_PROJECT.yaml"),effectiveConfig);
[hashes,passed] = rkkt.data.verify_input_hashes(root);
assert(passed);
base = hashes.fileName=="基础参数.xlsx";
series = hashes.fileName=="输入数据.xlsx";
manifest = struct("run_id",char(runId),"stage_id","stage_B", ...
    "status","RUNNING","git_commit","TEST_COMMIT", ...
    "input_hashes",struct( ...
        "base_parameters",char(hashes.actualSHA256(base)), ...
        "timeseries",char(hashes.actualSHA256(series))));
manifestPath = fullfile(pathValue,"run_manifest.json");
rkkt.artifacts.write_json_file(manifestPath,manifest);
context = struct("root",char(pathValue),"project_root",char(root), ...
    "run_id",char(runId),"stage_id","stage_B", ...
    "run_manifest_path",char(manifestPath), ...
    "effective_config_path",char(effectiveConfig), ...
    "checkpoints_dir",char(checkpoints), ...
    "checkpoint_manifest_path",char(fullfile(checkpoints, ...
        "checkpoint_manifest.csv")));
end

function remove_directories(paths)
for pathValue = reshape(paths,1,[])
    if isfolder(pathValue), rmdir(pathValue,"s"); end
end
end
