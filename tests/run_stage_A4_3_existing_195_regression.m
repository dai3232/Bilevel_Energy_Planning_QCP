function evidence = run_stage_A4_3_existing_195_regression(options)
%RUN_STAGE_A4_3_EXISTING_195_REGRESSION Run the frozen regression once.
%
% The numerical terminal-state argument is an execution gate, not report
% metadata: a nonconverged run cannot accidentally start this expensive
% suite.

arguments
    options.NumericalTerminalState (1,1) string
    options.EvidenceDirectory (1,1) string = ""
    options.CommandText (1,1) string = ...
        "run_stage_A4_3_existing_195_regression(" + ...
        "NumericalTerminalState=""CONVERGED"")"
end
assert(upper(strip(options.NumericalTerminalState))=="CONVERGED", ...
    "stageA4:a43:tests:Regression195NotAuthorized", ...
    "The frozen 195-test regression is authorized only after CONVERGED.");
root = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
addpath(fullfile(root,"tests"));
addpath(genpath(fullfile(root,"src")));
[files,inventory,components] = ...
    rkkt.testing.build_stage_a4_3_regression_195_inventory(root);
directory = strip(options.EvidenceDirectory);
temporaryExpected = strlength(directory)==0;
if temporaryExpected
    expectedPath = string(tempname)+".csv";
    cleanup = onCleanup(@()delete_if_present(expectedPath));
else
    assert(~isfolder(directory) && ~isfile(directory), ...
        "stageA4:a43:tests:Regression195EvidenceExists", ...
        "Regression evidence directory already exists: %s",directory);
    [created,message] = mkdir(directory);
    assert(created,"stageA4:a43:tests:Regression195Directory", ...
        "%s",message);
    expectedPath = fullfile(directory, ...
        "frozen_expected_inventory.csv");
end
rkkt.artifacts.write_table_csv_17g(expectedPath,inventory(:, ...
    {'test_order','test_name','source_file'}));
if strlength(directory)>0
    rkkt.artifacts.write_table_csv_17g(fullfile(directory, ...
        "regression_components.csv"),components);
end
evidence = rkkt.testing.run_fixed_test_inventory_with_evidence( ...
    root,files,expectedPath, ...
    "EvidenceDirectory",directory, ...
    "CommandText",options.CommandText, ...
    "SuiteLabel","stage_A4_regression_195");
assert(evidence.summary.test_total==195 && evidence.all_pass, ...
    "stageA4:a43:tests:Regression195Failed", ...
    "The frozen existing regression must pass exactly 195 tests.");
if strlength(directory)>0
    contractNames = [ ...
        "frozen_expected_inventory.csv"
        "regression_components.csv"];
    contractPaths = fullfile(directory,contractNames);
    sha256 = arrayfun(@compute_sha256_file,contractPaths);
    status = repmat("PASS",numel(contractNames),1);
    rkkt.artifacts.write_table_csv_17g(fullfile(directory, ...
        "regression_contract_sha256.csv"), ...
        table(contractNames,sha256,status, ...
        'VariableNames',{'names','sha256','status'}));
end
if temporaryExpected
    clear cleanup
end
end

function delete_if_present(pathValue)
if isfile(pathValue)
    delete(pathValue);
end
end
