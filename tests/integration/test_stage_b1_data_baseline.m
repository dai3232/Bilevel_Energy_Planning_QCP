function tests = test_stage_b1_data_baseline
%TEST_STAGE_B1_DATA_BASELINE Audit the controlled seven-day water inputs.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
data = load_project_data(root);
audit = build_stage_b1_water_input_audit(data,"B1_TEST");
testCase.TestData.root = root;
testCase.TestData.data = data;
testCase.TestData.audit = audit;
end

function testStageBConfigurationAndCurrentStageGate(testCase)
root = testCase.TestData.root;
current = string(fileread(fullfile(root,"CURRENT_STAGE.md")));
verifyEqual(testCase,markdown_value(current,"stage_id"),"stage_B");
verifyEqual(testCase,markdown_value(current,"status"),"READY");
verifyEqual(testCase,markdown_value(current,"next_stage_when_passed"), ...
    "stage_C1");

configuration = string(fileread(fullfile(root,"config","stage_B.yaml")));
verifyEqual(testCase,yaml_scalar(configuration,"stage_id"),"stage_B");
verifyEqual(testCase,yaml_scalar(configuration,"status"),"READY");
verifyEqual(testCase,yaml_number_list(configuration,"days"),14:20);
verifyEqual(testCase,yaml_number_list(configuration,"hours"),1:24);
verifyEqual(testCase,yaml_scalar(configuration, ...
    "water_constraints_enabled"),"true");
verifyEqual(testCase,yaml_scalar(configuration, ...
    "thermal_second_pass_enabled"),"false");
verifyEqual(testCase,yaml_scalar(configuration, ...
    "annual_scope_enabled"),"false");
verifyEqual(testCase,yaml_scalar(configuration,"parallel_mode"),"off");
end

function testRawHydroWaterDataAre365By4AndFinite(testCase)
data = testCase.TestData.data;
verifySize(testCase,data.timeseries.hydroWaterMin,[365,4]);
verifySize(testCase,data.timeseries.hydroWaterMax,[365,4]);
verifyEqual(testCase,data.timeseries.days,(1:365).');
verifyEqual(testCase,data.meta.nHydro,4);
coefficients = [data.base.hydro.waterA,data.base.hydro.waterB, ...
    data.base.hydro.waterC,data.base.hydro.maxOutputMW];
verifySize(testCase,coefficients,[4,4]);
verifyTrue(testCase,all(isfinite(coefficients),"all"));
verifyTrue(testCase,all(isfinite(data.timeseries.hydroWaterMin),"all"));
verifyTrue(testCase,all(isfinite(data.timeseries.hydroWaterMax),"all"));
end

function testStageBWindowHasSevenByFourAndTwentyEightRows(testCase)
audit = testCase.TestData.audit;
required = ["run_id","stage_id","day","hydro_id","water_a", ...
    "water_b","water_c","water_min_m3","water_max_m3", ...
    "min_not_above_max","all_finite","source_field","status"];
verifyEqual(testCase,height(audit),28);
verifyTrue(testCase,all(ismember(required, ...
    string(audit.Properties.VariableNames))));
verifyEqual(testCase,numel(unique(audit.day)),7);
verifyEqual(testCase,numel(unique(audit.hydro_id)),4);
verifyEqual(testCase,string(audit.run_id),repmat("B1_TEST",28,1));
verifyEqual(testCase,string(audit.stage_id),repmat("stage_B",28,1));
verifyTrue(testCase,all(audit.min_not_above_max));
verifyTrue(testCase,all(audit.all_finite));
verifyEqual(testCase,string(audit.status),repmat("PASS",28,1));
end

function testDayAndHydroOrderingIsCanonical(testCase)
audit = testCase.TestData.audit;
expectedDays = repelem((14:20).',4,1);
expectedHydro = repmat((1:4).',7,1);
verifyEqual(testCase,audit.day,expectedDays);
verifyEqual(testCase,audit.hydro_id,expectedHydro);
end

function testWaterMinimumAndMaximumDirectionIsNotSwapped(testCase)
data = testCase.TestData.data;
audit = testCase.TestData.audit;
linear = sub2ind([365,4],audit.day,audit.hydro_id);
expectedMinimum = data.timeseries.hydroWaterMin(linear);
expectedMaximum = data.timeseries.hydroWaterMax(linear);
verifyEqual(testCase,audit.water_min_m3,expectedMinimum,"AbsTol",0);
verifyEqual(testCase,audit.water_max_m3,expectedMaximum,"AbsTol",0);
verifyGreaterThanOrEqual(testCase,audit.water_min_m3,zeros(28,1));
verifyGreaterThanOrEqual(testCase,audit.water_max_m3, ...
    audit.water_min_m3);
verifyTrue(testCase,any(audit.water_max_m3>audit.water_min_m3), ...
    "The bound-orientation audit must be non-vacuous.");
end

function value = markdown_value(textValue,key)
expression = "(?m)^\s*-\s*`"+key+"`\s*:\s*`([^`]+)`";
token = regexp(textValue,expression,"tokens","once");
assert(~isempty(token),"stageB:tests:MarkdownField", ...
    "Missing Markdown state field: %s",key);
value = strip(string(token{1}));
end

function value = yaml_scalar(textValue,key)
expression = "(?m)^\s*"+key+"\s*:\s*([^#\r\n]+)";
token = regexp(textValue,expression,"tokens","once");
assert(~isempty(token),"stageB:tests:YamlField", ...
    "Missing YAML field: %s",key);
value = strip(string(token{1}));
if strlength(value)>=2 && ((startsWith(value,'"') && endsWith(value,'"')) || ...
        (startsWith(value,"'") && endsWith(value,"'")))
    value = extractBetween(value,2,strlength(value)-1);
end
end

function values = yaml_number_list(textValue,key)
raw = yaml_scalar(textValue,key);
assert(startsWith(raw,"[") && endsWith(raw,"]"), ...
    "stageB:tests:YamlList","YAML field %s is not an inline list.",key);
body = extractBetween(raw,2,strlength(raw)-1);
parts = split(body,",");
values = reshape(str2double(strip(parts)),1,[]);
assert(all(isfinite(values)),"stageB:tests:YamlList", ...
    "YAML field %s contains a nonnumeric list item.",key);
end
