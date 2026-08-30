function tests = test_stage_b2c_recursive_structure_cache
%TEST_STAGE_B2C_RECURSIVE_STRUCTURE_CACHE Structural/numerical separation.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root,"src"));
[data,~] = rkkt.cache.load_or_build_project_data(root,Enabled=true);
testCase.TestData.root = root;
testCase.TestData.data = data;
end

function testSevenDayBuildThenHitWithoutCanonical(testCase)
[config,data] = make_config(testCase,14,20);
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[first,firstInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
[second,secondInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
verifyEqual(testCase,firstInfo.status,"BUILT");
verifyEqual(testCase,secondInfo.status,"HIT");
verifyEqual(testCase,first.topology_fingerprint, ...
    second.topology_fingerprint);
verifyFalse(testCase,firstInfo.canonical_index_loaded);
verifyFalse(testCase,firstInfo.canonical_index_built);
verifyFalse(testCase,secondInfo.canonical_index_loaded);
verifyFalse(testCase,secondInfo.canonical_index_built);
clear guard
remove_temporary_directory(cacheDirectory);
end

function testLoadChangeReusesStructureAndRefreshesNumerics(testCase)
[config,data] = make_config(testCase,14,20);
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[structure,firstInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
firstPayload = rkkt.model.build_stage_b2c_recursive_numerical_payload( ...
    data,structure,config);
changed = data;
changed.timeseries.planMW(14,1) = changed.timeseries.planMW(14,1)+100;
[sameStructure,secondInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        testCase.TestData.root,changed,config,CacheDirectory=cacheDirectory);
secondPayload = rkkt.model.build_stage_b2c_recursive_numerical_payload( ...
    changed,sameStructure,config);
verifyEqual(testCase,firstInfo.key,secondInfo.key);
verifyEqual(testCase,secondInfo.status,"HIT");
verifyEqual(testCase, ...
    secondPayload.template.day(1).equality_offset(15), ...
    firstPayload.template.day(1).equality_offset(15)-100,"AbsTol",0);
clear guard
remove_temporary_directory(cacheDirectory);
end

function testNonzeroCapacityFactorChangeReusesStructure(testCase)
[config,data] = make_config(testCase,14,20);
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[structure,firstInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
firstPayload = rkkt.model.build_stage_b2c_recursive_numerical_payload( ...
    data,structure,config);
changed = data;
[day,hour,asset,dayPosition] = first_active_wind(changed,config.days);
changed.timeseries.windAvailability(day,hour,asset) = ...
    changed.timeseries.windAvailability(day,hour,asset)*0.9;
[sameStructure,secondInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        testCase.TestData.root,changed,config,CacheDirectory=cacheDirectory);
secondPayload = rkkt.model.build_stage_b2c_recursive_numerical_payload( ...
    changed,sameStructure,config);
verifyEqual(testCase,firstInfo.key,secondInfo.key);
verifyEqual(testCase,secondInfo.status,"HIT");
verifyNotEqual(testCase,secondPayload.template.day(dayPosition).base_G, ...
    firstPayload.template.day(dayPosition).base_G);
clear guard
remove_temporary_directory(cacheDirectory);
end

function testZeroToPositiveCapacityFactorChangesTopology(testCase)
[config,data] = make_config(testCase,14,20);
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[~,firstInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
changed = data;
[day,hour,asset] = first_zero_wind(changed,config.days);
changed.timeseries.windAvailability(day,hour,asset) = 0.01;
changedConfig = rebuild_config(testCase,changed,14,20);
[changedStructure,secondInfo] = ...
    rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
        testCase.TestData.root,changed,changedConfig, ...
        CacheDirectory=cacheDirectory);
verifyNotEqual(testCase,firstInfo.key,secondInfo.key);
verifyEqual(testCase,secondInfo.status,"BUILT");
verifyEqual(testCase,changedStructure.counts.variables, ...
    config.expected_stage_a_primal_dimension+1);
verifyEqual(testCase,changedStructure.counts.fixed_zero, ...
    config.expected_stage_a_fixed_zero_count-1);
clear guard
remove_temporary_directory(cacheDirectory);
end

function test180DayBuildThenHit(testCase)
[fullConfig,data] = make_config(testCase,1,365);
[config,~] = make_config(testCase,1,180);
cacheDirectory = new_temporary_directory();
guard = onCleanup(@()remove_temporary_directory(cacheDirectory));
[~,fullInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,fullConfig,CacheDirectory=cacheDirectory);
[~,firstInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
[~,secondInfo] = rkkt.cache.load_or_build_stage_b2c_recursive_structure( ...
    testCase.TestData.root,data,config,CacheDirectory=cacheDirectory);
verifyEqual(testCase,firstInfo.status,"BUILT");
verifyEqual(testCase,secondInfo.status,"HIT");
verifyNotEqual(testCase,fullInfo.key,firstInfo.key);
verifyFalse(testCase,firstInfo.canonical_index_loaded);
verifyFalse(testCase,firstInfo.canonical_index_built);
verifyGreaterThan(testCase,firstInfo.build_seconds,0);
verifyGreaterThan(testCase,secondInfo.load_seconds,0);
clear guard
remove_temporary_directory(cacheDirectory);
end

function [config,data] = make_config(testCase,dayStart,dayEnd)
data = testCase.TestData.data;
config = rebuild_config(testCase,data,dayStart,dayEnd);
end

function config = rebuild_config(testCase,data,dayStart,dayEnd)
settings = rkkt.config.build_stage_b2c_run_settings( ...
    testCase.TestData.root,DayStart=dayStart,DayEnd=dayEnd, ...
    AuditMode="recursive_only",RunOutputMode="lightweight", ...
    ParallelEnabled=false,CacheEnabled=true);
config = rkkt.model.build_stage_b2c_runtime_configuration( ...
    testCase.TestData.root,settings,data);
end

function [day,hour,asset,dayPosition] = first_active_wind(data,days)
mask = data.timeseries.windAvailability(days,:,:)~=0;
[dayPosition,hour,asset] = ind2sub(size(mask),find(mask,1));
day = days(dayPosition);
end

function [day,hour,asset] = first_zero_wind(data,days)
mask = data.timeseries.windAvailability(days,:,:)==0;
[dayPosition,hour,asset] = ind2sub(size(mask),find(mask,1));
day = days(dayPosition);
end

function value = new_temporary_directory()
value = string(tempname);
mkdir(value);
end

function remove_temporary_directory(pathValue)
if isfolder(pathValue), rmdir(pathValue,"s"); end
end
