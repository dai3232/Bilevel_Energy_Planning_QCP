function tests = test_stage_a3_test_inventory_contract
%TEST_STAGE_A3_TEST_INVENTORY_CONTRACT Lock the complete formal A3 test set.
tests = functiontests(localfunctions);
end

function setupOnce(~)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
end

function testExactControlledInventoryAccepted(testCase)
[root,actual] = fixture(testCase);
audit = validate_stage_a3_test_inventory_contract(actual,root);
verifyTrue(testCase,audit.matches_expected);
verifyEqual(testCase,audit.actual_count,2);
verifyEqual(testCase,audit.expected_count,2);
verifyTrue(testCase,audit.test_names_unique);
end

function testMissingControlledTestRejected(testCase)
[root,actual] = fixture(testCase);
actual = actual(1,:);
actual.test_order = 1;
verifyError(testCase,@()validate_stage_a3_test_inventory_contract( ...
    actual,root),"stageA3:tests:ExpectedInventoryMismatch");
end

function testDuplicateDiscoveredTestNameRejected(testCase)
[root,actual] = fixture(testCase);
actual.test_name(2) = actual.test_name(1);
verifyError(testCase,@()validate_stage_a3_test_inventory_contract( ...
    actual,root),"stageA3:tests:ActualInventoryInvalid");
end

function testUnregisteredTestRejected(testCase)
[root,actual] = fixture(testCase);
actual.test_name(2) = "test_stage_a3_beta/testUnexpected";
verifyError(testCase,@()validate_stage_a3_test_inventory_contract( ...
    actual,root),"stageA3:tests:ExpectedInventoryMismatch");
end

function testRegisteredSourceFileMismatchRejected(testCase)
[root,actual] = fixture(testCase);
actual.source_file(2) = "tests/unit/test_stage_a3_wrong_source.m";
verifyError(testCase,@()validate_stage_a3_test_inventory_contract( ...
    actual,root),"stageA3:tests:ExpectedInventoryMismatch");
end

function [root,actual] = fixture(testCase)
root = string(tempname(tempdir));
mkdir(fullfile(root,"tests"));
testCase.addTeardown(@()remove_tree(root));
actual = table((1:2).',[ ...
    "test_stage_a3_alpha/testFirst"; ...
    "test_stage_a3_beta/testSecond"],[ ...
    "tests/unit/test_stage_a3_alpha.m"; ...
    "tests/unit/test_stage_a3_beta.m"], ...
    'VariableNames',{'test_order','test_name','source_file'});
write_table_csv_17g(fullfile(root,"tests", ...
    "stage_A3_expected_test_inventory.csv"),actual);
end

function remove_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
