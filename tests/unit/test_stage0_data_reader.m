function tests = test_stage0_data_reader
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repoRoot,'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testControlledHashesMatchManifest(testCase)
[hashes,allMatch] = verify_input_hashes(testCase.TestData.repoRoot);
verifyTrue(testCase,allMatch);
verifyEqual(testCase,string(hashes.status),repmat("PASS",2,1));
verifyEqual(testCase,string(hashes.actualSHA256),[
    "aebb35fa80e6ba2fb8d4534b09a141feaedcb2b9d027e9924e7a0091943c4277";
    "10baac1dc5d0b07dbbb9d2fe8f9aac82f071e43d4fb9901ff7ba0b467d05c186"]);
end

function testLabelDrivenReaderNormalizesRealInputs(testCase)
data = load_project_data(testCase.TestData.repoRoot);
verifyEqual(testCase,[data.meta.nThermal,data.meta.nHydro,data.meta.nWind, ...
    data.meta.nSolar,data.meta.nStorage],[4,4,5,5,2]);
verifyEqual(testCase,[data.meta.nDays,data.meta.nHours,data.meta.stepMinutes, ...
    data.meta.dtHours],[365,24,60,1]);
verifySize(testCase,data.timeseries.hydroWaterMin,[365,4]);
verifySize(testCase,data.timeseries.hydroWaterMax,[365,4]);
verifySize(testCase,data.timeseries.windAvailability,[365,24,5]);
verifySize(testCase,data.timeseries.solarAvailability,[365,24,5]);
verifySize(testCase,data.timeseries.planMW,[365,24]);
verifyEqual(testCase,min(data.timeseries.planMW(:)),2070,'AbsTol',1e-12);
verifyEqual(testCase,max(data.timeseries.planMW(:)),9860,'AbsTol',1e-12);
verifyEqual(testCase,nnz(data.timeseries.windAvailability==0),24);
verifyEqual(testCase,nnz(data.timeseries.solarAvailability==0),21909);
verifyEqual(testCase,data.base.general.legacyDays,30);
verifyEqual(testCase,data.meta.nDays,365);
verifyFalse(testCase,data.auditPolicy.fixedRowsUsedForLocation);
verifyTrue(testCase,all(string(data.audit.status)=="PASS"));
end

function testLocatorRequiresUniqueLabelAndCompleteHeader(testCase)
baseFile = fullfile(testCase.TestData.repoRoot,'inputs','raw','基础参数.xlsx');
raw = readcell(baseFile,'Sheet','基础参数');
location = locate_labeled_table(raw,"基础参数","基本参数", ...
    ["火电数量","水电数量","风电数量","光伏数量","储能数量"], ...
    "within-section");
verifyEqual(testCase,location.locator, ...
    "sheet+unique section label+complete contiguous header");
verifyEqual(testCase,location.headerRow,3); % audit-only regression, not locator input

duplicate = {"区段","字段";"区段","字段"};
verifyError(testCase,@() locate_labeled_table(duplicate,"Sheet1","区段", ...
    "字段","same-row"),"stage0:DuplicateSectionLabel");
end
