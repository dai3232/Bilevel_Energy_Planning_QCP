function tests = test_stage_b2c_legacy_isolation
%TEST_STAGE_B2C_LEGACY_ISOLATION Keep production independent from audit tools.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root,"src"));
legacyTools = fullfile(root,"tools","Stage-B2C","legacy");
addpath(legacyTools);
addTeardown(testCase,@()rmpath(legacyTools));
[data,~] = rkkt.cache.load_or_build_project_data(root,Enabled=true);
settings = rkkt.config.build_stage_b2c_run_settings(root, ...
    DayStart=14,DayEnd=20,AuditMode="recursive_only", ...
    RunOutputMode="lightweight",ParallelEnabled=false,CacheEnabled=true);
config = rkkt.model.build_stage_b2c_runtime_configuration( ...
    root,settings,data);
testCase.TestData.root = root;
testCase.TestData.data = data;
testCase.TestData.config = config;
end

function testProductionRouteDoesNotReferenceLegacyTools(testCase)
root = testCase.TestData.root;
files = [ ...
    fullfile(root,"src","+rkkt","+workflows","stageB2CConfigured.m")
    fullfile(root,"src","+rkkt","+cache", ...
        "load_or_build_stage_b2c_recursive_structure.m")
    fullfile(root,"src","+rkkt","+model", ...
        "build_stage_b2c_recursive_numerical_payload.m")
    fullfile(root,"src","+rkkt","+solver", ...
        "run_stage_b2c_365day_serial_ipm.m")];
for pathValue = reshape(files,1,[])
    source = string(fileread(pathValue));
    verifyFalse(testCase,contains(source,"legacy_runtime_audit"));
    verifyFalse(testCase,contains(source,"tools/Stage-B2C/legacy"));
    verifyFalse(testCase,contains(source, ...
        "load_or_build_stage_b2c_recursive_runtime_package"));
end
end

function testProductionStructuralMissNeverTouchesCanonicalIndex(testCase)
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[~,info] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,testCase.TestData.data, ...
    testCase.TestData.config,ForceRebuild=true, ...
    CacheDirectory=cacheDirectory);
verifyEqual(testCase,info.status,"BUILT");
verifyFalse(testCase,info.canonical_index_loaded);
verifyFalse(testCase,info.canonical_index_built);
verifyEqual(testCase,info.canonical_index_load_seconds,0,"AbsTol",0);
verifyEqual(testCase,info.canonical_index_build_seconds,0,"AbsTol",0);
clear guard
remove_temporary_directory(cacheDirectory);
end

function testLegacyCanonicalBootstrapRequiresExplicitOptIn(testCase)
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
caught = MException.empty;
try
    load_or_build_stage_b2c_legacy_runtime_audit_baseline( ...
        testCase.TestData.root,testCase.TestData.data, ...
        testCase.TestData.config,ForceRebuild=true, ...
        CacheDirectory=cacheDirectory);
catch exception
    caught = exception;
end
verifyNotEmpty(testCase,caught);
verifyEqual(testCase,string(caught.identifier), ...
    "stageB2C:legacyRuntimeAudit:ExplicitOptInRequired");
verifyEqual(testCase,string(caught.message), ...
    "Legacy canonical bootstrap requires explicit opt-in.");

[baseline,info] = ...
    load_or_build_stage_b2c_legacy_runtime_audit_baseline( ...
        testCase.TestData.root,testCase.TestData.data, ...
        testCase.TestData.config,ForceRebuild=true, ...
        BootstrapCanonicalIndexAllowed=true, ...
        CacheDirectory=cacheDirectory);
verifyEqual(testCase,info.status,"BUILT");
verifyTrue(testCase,info.canonical_index_loaded);
verifyEqual(testCase,info.bootstrap_mode, ...
    "LEGACY_AUDIT_EXPLICIT_OPT_IN");
verifyEqual(testCase,string(baseline.version), ...
    "stage-B2C-legacy-runtime-audit-baseline-v1.0");
clear guard
remove_temporary_directory(cacheDirectory);
end

function value = new_temporary_directory()
value = string(tempname);
mkdir(value);
end

function remove_temporary_directory(pathValue)
if isfolder(pathValue), rmdir(pathValue,"s"); end
end
