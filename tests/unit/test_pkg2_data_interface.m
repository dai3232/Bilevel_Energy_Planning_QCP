function tests = test_pkg2_data_interface
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repositoryRoot = string(fileparts(fileparts( ...
    fileparts(mfilename("fullpath")))));
sourceRoot = fullfile(repositoryRoot, "src");
legacyDataRoot = fullfile(sourceRoot, "data");
originalPath = path;
testCase.TestData.pathCleanup = onCleanup(@() path(originalPath));
addpath(sourceRoot);
addpath(legacyDataRoot);

legacyData = load_project_data(repositoryRoot);
pathBeforeFacade = path;
facadeData = rkkt.data.load(repositoryRoot);
pathAfterFacade = path;
manualResult = rkkt.data.validation.run( ...
    repositoryRoot, Interactive=false, WriteArtifacts=false);

testCase.TestData.repositoryRoot = repositoryRoot;
testCase.TestData.sourceRoot = sourceRoot;
testCase.TestData.legacyDataRoot = legacyDataRoot;
testCase.TestData.legacyData = legacyData;
testCase.TestData.facadeData = facadeData;
testCase.TestData.pathBeforeFacade = pathBeforeFacade;
testCase.TestData.pathAfterFacade = pathAfterFacade;
testCase.TestData.manualResult = manualResult;
end

function testPackageInfoMarksOnlyDataFacadeImplemented(testCase)
value = rkkt.info();
verifyEqual(testCase, value.package_version, "0.2.0");
verifyEqual(testCase, value.pkg_stage, "PKG-2");
verifyEqual(testCase, value.implemented_public_interfaces, ...
    ["rkkt.info"; "rkkt.data.load"]);
verifyFalse(testCase, value.production_algorithm_migrated);
end

function testFacadeMatchesLegacyObjectExactly(testCase)
legacyData = testCase.TestData.legacyData;
facadeData = testCase.TestData.facadeData;
verifyEqual(testCase, class(facadeData), class(legacyData));
verifyEqual(testCase, size(facadeData), size(legacyData));
verifyEqual(testCase, fieldnames(facadeData), fieldnames(legacyData));
verifyTrue(testCase, isequaln(facadeData, legacyData));
end

function testFacadePreservesFrozenAnnualContract(testCase)
data = testCase.TestData.facadeData;
verifyEqual(testCase, [data.meta.nDays, data.meta.nHours, ...
    data.meta.stepMinutes, data.meta.dtHours], [365, 24, 60, 1]);
verifySize(testCase, data.timeseries.windAvailability, [365, 24, 5]);
verifySize(testCase, data.timeseries.solarAvailability, [365, 24, 5]);
verifySize(testCase, data.timeseries.planMW, [365, 24]);
verifyEqual(testCase, data.timeseries.days, (1:365).');
verifyEqual(testCase, data.timeseries.hours, 1:24);
end

function testFacadePreservesControlledHashesAndPlanScaling(testCase)
data = testCase.TestData.facadeData;
verifyEqual(testCase, string(data.hashes.status), ...
    repmat("PASS", 2, 1));
verifyEqual(testCase, lower(string(data.hashes.actualSHA256)), [
    "aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277"
    "10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186"]);
verifyEqual(testCase, data.timeseries.planMW, ...
    data.timeseries.planPerUnit .* 10000);
end

function testFacadeRestoresCallerPath(testCase)
verifyEqual(testCase, testCase.TestData.pathAfterFacade, ...
    testCase.TestData.pathBeforeFacade);
end

function testFacadeWorksWhenLegacyDirectoryIsNotPreloaded(testCase)
pathBefore = path;
cleanup = onCleanup(@() path(pathBefore));
legacyDataRoot = testCase.TestData.legacyDataRoot;
pathEntries = string(split(path, pathsep));
if any(same_path(pathEntries, legacyDataRoot))
    rmpath(legacyDataRoot);
end
pathWithoutLegacy = path;
data = rkkt.data.load(testCase.TestData.repositoryRoot);
verifyEqual(testCase, data.meta.nDays, 365);
verifyEqual(testCase, path, pathWithoutLegacy);
clear cleanup
end

function testManualValidationReturnsCanonicalEnvelope(testCase)
value = testCase.TestData.manualResult;
rkkt.contracts.validateModuleResult(value);
verifyEqual(testCase, string(fieldnames(value)), ...
    rkkt.contracts.requiredFields("moduleResult"));
verifyEqual(testCase, value.meta.interface_name, "rkkt.data.load");
verifyEqual(testCase, value.meta.production_function, ...
    "load_project_data");
verifyEqual(testCase, value.meta.day, 14:20);
verifyEqual(testCase, value.meta.hour, 1:24);
end

function testManualValidationSeparatesAnnualSourceAndSevenDayView(testCase)
value = testCase.TestData.manualResult;
verifyEqual(testCase, value.output.projectData.meta.nDays, 365);
verifyEqual(testCase, value.output.projectData.meta.nHours, 24);
observation = value.output.sevenDayObservation;
verifyEqual(testCase, observation.days, (14:20).');
verifyEqual(testCase, observation.hours, 1:24);
verifySize(testCase, observation.planMW, [7, 24]);
verifySize(testCase, observation.windAvailability, [7, 24, 5]);
verifySize(testCase, observation.solarAvailability, [7, 24, 5]);
verifyEqual(testCase, observation.nHours, 168);
end

function testManualComparisonCoversExactLegacyEquivalence(testCase)
comparison = testCase.TestData.manualResult.diagnostics. ...
    legacy_facade_comparison;
verifyTrue(testCase, comparison.root_class_equal);
verifyTrue(testCase, comparison.root_size_equal);
verifyTrue(testCase, comparison.top_level_field_order_equal);
verifyTrue(testCase, comparison.hash_table_exact_equal);
verifyEqual(testCase, comparison.class_mismatch_count, 0);
verifyEqual(testCase, comparison.size_mismatch_count, 0);
verifyEqual(testCase, comparison.field_order_mismatch_count, 0);
verifyGreaterThan(testCase, comparison.numeric_leaf_count, 0);
verifyEqual(testCase, ...
    comparison.numeric_maximum_absolute_difference, 0);
verifyEqual(testCase, comparison.nonnumeric_mismatch_count, 0);
verifyTrue(testCase, comparison.full_object_exact_equal);
end

function testNoArtifactModeWritesNoArtifactReferences(testCase)
value = testCase.TestData.manualResult;
verifyFalse(testCase, value.diagnostics.artifacts_written);
verifyEqual(testCase, value.tableFiles, strings(0, 1));
verifyEqual(testCase, value.figureFiles, strings(0, 1));
verifyEqual(testCase, value.meta.output_file, "");
end

function testFacadeDelegatesWithoutExcelReaderDuplication(testCase)
sourcePath = fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt", "+data", "load.m");
source = string(fileread(sourcePath));
verifyEqual(testCase, count(lower(source), "load_project_data("), 1);
verifyFalse(testCase, contains(lower(source), "readcell("));
verifyFalse(testCase, contains(lower(source), "readtable("));
verifyFalse(testCase, contains(lower(source), "sheetnames("));
end

function testValidationEntryHasNoDownstreamDependency(testCase)
sourcePath = fullfile(testCase.TestData.sourceRoot, ...
    "+rkkt", "+data", "+validation", "run.m");
source = lower(string(fileread(sourcePath)));
for forbidden = [ ...
        "rkkt.indexing."
        "rkkt.model."
        "rkkt.solver."
        "rkkt.ipm."
        "load_stage_a4_configuration"]
    verifyFalse(testCase, contains(source, forbidden));
end
end

function testNoPkg3FacadeWasIntroduced(testCase)
verifyEmpty(testCase, which("rkkt.indexing.build"));
verifyEmpty(testCase, which("rkkt.indexing.validation.run"));
verifyEmpty(testCase, which("rkkt.model.initialize"));
verifyEmpty(testCase, which("rkkt.solver.assembleFullKKT"));
verifyEmpty(testCase, which("rkkt.ipm.step"));
end

function result = same_path(left, right)
left = replace(string(left), "/", "\");
right = replace(string(right), "/", "\");
if ispc
    result = strcmpi(left, right);
else
    result = strcmp(left, right);
end
end
