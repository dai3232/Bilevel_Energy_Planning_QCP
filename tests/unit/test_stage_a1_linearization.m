function tests = test_stage_a1_linearization
%TEST_STAGE_A1_LINEARIZATION Audit the sole A1 model evaluation object.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(projectRoot,"src")));
config = rkkt.model.load_stage_a1_configuration(projectRoot);
data = rkkt.data.load_project_data(projectRoot);
index = rkkt.indexing.build_stage_a1_index(data,"RunId","A1_LINEARIZATION_TEST");
state = rkkt.model.initialize_stage_a1_state(data,index,config);
linearization = rkkt.model.build_stage_a1_linearization(state,data,index,config);
testCase.TestData.projectRoot = projectRoot;
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.linearization = linearization;
end

function testCanonicalDimensionsAndSparseContract(testCase)
lin = testCase.TestData.linearization;
verifyEqual(testCase,lin.counts.primal,100);
verifyEqual(testCase,lin.counts.equalities,27);
verifyEqual(testCase,lin.counts.inequalities,172);
verifyEqual(testCase,lin.counts.full_kkt,471);
verifyEqual(testCase,[lin.layout.hour.kkt_dimension],[27 27 29]);
verifyTrue(testCase,issparse(lin.H));
verifyTrue(testCase,issparse(lin.A));
verifyTrue(testCase,issparse(lin.G));
verifyEqual(testCase,nnz(lin.H),0);
end

function testWindowSocBoundaryRowsAreExplicit(testCase)
lin = testCase.TestData.linearization;
config = testCase.TestData.config;
index = testCase.TestData.index;
links = index.soc_link_map;
startRows = links.hour == config.start_hour;
terminalRows = links.hour == config.terminal_hour;
verifyEqual(testCase,nnz(startRows),2);
verifyTrue(testCase,all(isnan(links.predecessor_hour(startRows))));
verifyEqual(testCase,links.predecessor_soc_global_index(startRows),zeros(2,1));
verifyEqual(testCase,string(links.boundary_source(startRows)), ...
    repmat("fixed_half_energy",2,1));
verifyEqual(testCase,nnz(terminalRows & links.terminal_equality),2);
verifyEqual(testCase,links.terminal_energy_fraction(terminalRows),0.5*ones(2,1));

eq = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "equality",:);
firstSoc = find(eq.hour == config.start_hour & ...
    string(eq.constraint_name) == "soc_dynamics");
terminal = find(eq.hour == config.terminal_hour & ...
    string(eq.constraint_name) == "terminal_soc");
verifyEqual(testCase,numel(firstSoc),2);
verifyEqual(testCase,numel(terminal),2);
verifyEqual(testCase,full(lin.A(firstSoc,lin.maps.q_day(13:14))), ...
    -0.5*eye(2),"AbsTol",0);
verifyEqual(testCase,full(lin.A(terminal,lin.maps.q_day(13:14))), ...
    -0.5*eye(2),"AbsTol",0);
end

function testPowerBalanceAndSocSigns(testCase)
lin = testCase.TestData.linearization;
index = testCase.TestData.index;
config = testCase.TestData.config;
variables = index.variable_index;
equalities = index.constraint_index( ...
    string(index.constraint_index.constraint_type) == "equality",:);
balance = find(equalities.hour == config.start_hour & ...
    string(equalities.constraint_name) == "hourly_power_balance");
pch = variable_index(variables,config.start_hour,"storage",1,"Pch");
pdis = variable_index(variables,config.start_hour,"storage",1,"Pdis");
verifyEqual(testCase,full(lin.A(balance,pch)),-1,"AbsTol",0);
verifyEqual(testCase,full(lin.A(balance,pdis)),1,"AbsTol",0);

soc9 = find(equalities.hour == 9 & ...
    string(equalities.constraint_name) == "soc_dynamics" & ...
    equalities.asset_id == 1);
soc8Variable = variable_index(variables,8,"storage",1,"SOC");
verifyEqual(testCase,full(lin.A(soc9,soc8Variable)),-1,"AbsTol",0);
end

function testStrictInteriorAndResidualIdentity(testCase)
lin = testCase.TestData.linearization;
verifyGreaterThan(testCase,min(lin.l),0);
verifyGreaterThan(testCase,min(lin.z),0);
verifyGreaterThan(testCase,lin.mu,0);
verifyEqual(testCase,lin.r_ineq,zeros(172,1),"AbsTol",0);
verifyEqual(testCase,lin.r_dual, ...
    lin.objective.gradient + lin.A.'*lin.state.y + lin.G.'*lin.z, ...
    "AbsTol",0);
verifyEqual(testCase,lin.r_eq,lin.A*lin.state.xi + ...
    lin.constraints.eq_offset,"AbsTol",0);
end

function testIdentityIsDeterministicAndUsesControlledHashes(testCase)
config = testCase.TestData.config;
data = testCase.TestData.data;
index = testCase.TestData.index;
state = rkkt.model.initialize_stage_a1_state(data,index,config);
second = rkkt.model.build_stage_a1_linearization(state,data,index,config);
verifyEqual(testCase,second.identity,testCase.TestData.linearization.identity);
for k = 1:height(data.hashes)
    verifyTrue(testCase,contains(second.identity, ...
        lower(string(data.hashes.actualSHA256(k)))));
end
end

function testExecutionRestrictionsAreFrozen(testCase)
config = testCase.TestData.config;
verifyEqual(testCase,config.newton_direction_count,1);
verifyFalse(testCase,config.run_full_ipm);
verifyEqual(testCase,config.parallel_mode,"off");
verifyFalse(testCase,config.physical_dispatch_interpretation);
verifyFalse(testCase,config.linear_algebra.automatic_regularization);
verifyFalse(testCase,config.linear_algebra.automatic_symmetrization);
verifyFalse(testCase,config.linear_algebra.recursive_fallback_to_full_kkt);
verifyEqual(testCase,config.tolerances.direction_relative_2norm,1e-10);
verifyEqual(testCase,config.tolerances.recursive_full_kkt_relative_residual,1e-10);
end

function testAcceptanceInventoryIsCompleteAndStrict(testCase)
acceptance = rkkt.diagnostics.initialize_stage_a1_acceptance(testCase.TestData.projectRoot);
verifyEqual(testCase,height(acceptance),15);
verifyEqual(testCase,numel(unique(acceptance.test_id)),15);
verifyTrue(testCase,all(acceptance.blocking));
verifyError(testCase,@() rkkt.diagnostics.aggregate_stage_a1_status(acceptance), ...
    "stageA1:acceptance:Incomplete");
for k = 1:height(acceptance)
    acceptance = rkkt.diagnostics.set_stage_a1_acceptance_result(acceptance, ...
        acceptance.test_id(k),"PASS","test","test","tests");
end
verifyEqual(testCase,rkkt.diagnostics.aggregate_stage_a1_status(acceptance),"PASS");
end

function testParallelCallScannerRejectsInjectedA1Source(testCase)
temporaryRoot = string(tempname(tempdir));
mkdir(fullfile(temporaryRoot,"src","+rkkt","+diagnostics"));
cleanup = onCleanup(@() remove_temporary_root(temporaryRoot)); %#ok<NASGU>
pathValue = fullfile(temporaryRoot,"src","+rkkt","+diagnostics", ...
    "injected_stage_a1_parallel.m");
fileId = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0);
closeGuard = onCleanup(@() close_test_file(fileId));
fwrite(fileId,unicode2native("function injected_stage_a1_parallel; parpool(); end"+ ...
    newline,"UTF-8"),"uint8");
fclose(fileId);
clear closeGuard;
audit = rkkt.diagnostics.scan_stage_a1_forbidden_code(temporaryRoot,testCase.TestData.config);
row = audit.rule_id=="NO_PARALLEL_CALL";
verifyEqual(testCase,nnz(row),1);
verifyEqual(testCase,audit.status(row),"FAIL");
verifyEqual(testCase,audit.match_count(row),1);
end

function testRequiredA1DimensionCannotFallBackToDefault(testCase)
temporaryRoot = string(tempname(tempdir));
mkdir(fullfile(temporaryRoot,"config"));
cleanup = onCleanup(@() remove_temporary_root(temporaryRoot)); %#ok<NASGU>
copyfile(fullfile(testCase.TestData.projectRoot,"config","solver.yaml"), ...
    fullfile(temporaryRoot,"config","solver.yaml"));
source = string(fileread(fullfile(testCase.TestData.projectRoot, ...
    "config","stage_A1.yaml")));
source = regexprep(source, ...
    "(?m)^expected_global_core_dimension:\s*16\s*\r?\n","", ...
    "once");
write_test_text(fullfile(temporaryRoot,"config","stage_A1.yaml"),source);
verifyError(testCase,@() rkkt.model.load_stage_a1_configuration(temporaryRoot), ...
    "stageA1:config:MissingKey");
end

function write_test_text(pathValue,value)
fileId = fopen(pathValue,"wb","n","UTF-8");
assert(fileId>=0);
cleanup = onCleanup(@() close_test_file(fileId));
fwrite(fileId,unicode2native(char(value),"UTF-8"),"uint8");
fclose(fileId);
clear cleanup;
end

function close_test_file(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end

function remove_temporary_root(pathValue)
if isfolder(pathValue)
    rmdir(pathValue,"s");
end
end

function indexValue = variable_index(variables,hour,assetType,assetId,name)
mask = variables.day == 1 & variables.hour == hour & ...
    string(variables.asset_type) == assetType & variables.asset_id == assetId & ...
    string(variables.variable_name) == name;
assert(nnz(mask) == 1);
indexValue = variables.global_index_start(mask);
end
