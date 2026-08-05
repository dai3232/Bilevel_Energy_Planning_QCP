function tests = test_stage_b2b_direction_equivalence
%TEST_STAGE_B2B_DIRECTION_EQUIVALENCE Audit one extended-model direction.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));
config = rkkt.model.load_stage_b2b_configuration(root);
data = rkkt.data.load_project_data(root);
index = rkkt.indexing.build_stage_b2b_index(data,config,"RunId","B2B_EQUIVALENCE_TEST");
state = rkkt.model.initialize_stage_b2b_state(data,index,config);
lin = rkkt.model.build_stage_b2b_multiday_linearization(state,data,index,config);
reduced = rkkt.solver.eliminate_stage_b2b_inequality_directions(lin);
recursive = rkkt.solver.solve_stage_b2b_recursive_direction(lin, ...
    SymmetryTolerance=1e-12);
fullAudit = rkkt.solver.solve_stage_b2b_full_kkt_direction(lin);
audit = rkkt.solver.verify_stage_b2b_direction_equivalence( ...
    fullAudit,recursive,lin, ...
    DirectionRelative=1e-10,RecursiveResidual=1e-10, ...
    FullResidual=1e-10);
testCase.TestData.root = root;
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.state = state;
testCase.TestData.lin = lin;
testCase.TestData.reduced = reduced;
testCase.TestData.recursive = recursive;
testCase.TestData.full = fullAudit;
testCase.TestData.audit = audit;
end

function testEliminationFormulaMatchesResidualContract(testCase)
lin = testCase.TestData.lin;
reduced = testCase.TestData.reduced;
D = spdiags(lin.z./lin.l,0,numel(lin.l),numel(lin.l));
expectedW = sparse(lin.H)+sparse(lin.G.')*D*sparse(lin.G);
expectedRhs = -lin.r_dual-sparse(lin.G.')*(D*lin.r_ineq)+ ...
    sparse(lin.G.')*(lin.r_comp./lin.l);
verifyEqual(testCase,reduced.W,expectedW,"AbsTol",0);
rhsRelative=norm(reduced.b_xi-expectedRhs,2)/max(1,norm(expectedRhs,2));
verifyLessThanOrEqual(testCase,rhsRelative,2048*eps);
verifyEqual(testCase,reduced.theta,lin.z./lin.l,"AbsTol",0);
verifyEqual(testCase,string(reduced.linearization_identity), ...
    string(lin.identity));
end

function testReducedSaddleIsSymmetricWithoutModification(testCase)
reduced = testCase.TestData.reduced;
relative = norm(reduced.saddle-reduced.saddle.',"fro")/ ...
    max(1,norm(reduced.saddle,"fro"));
verifyLessThanOrEqual(testCase,relative,1e-12);
verifyTrue(testCase,issparse(reduced.W));
verifyTrue(testCase,issparse(reduced.saddle));
if isfield(reduced,"automatic_symmetrization_used")
    verifyFalse(testCase,reduced.automatic_symmetrization_used);
end
end

function testBackSubstitutionClosesAllFourRawKktRows(testCase)
lin = testCase.TestData.lin;
c = testCase.TestData.recursive.components;
stationarity = lin.H*c.xi+lin.A.'*c.y+lin.G.'*c.z+lin.r_dual;
equality = lin.A*c.xi+lin.r_eq;
inequality = lin.G*c.xi+c.l+lin.r_ineq;
complementarity = lin.z.*c.l+lin.l.*c.z+lin.r_comp;
verifyScaledResidual(testCase,stationarity,lin.r_dual,1e-10);
verifyScaledResidual(testCase,equality,lin.r_eq,1e-10);
verifyScaledResidual(testCase,inequality,lin.r_ineq,1e-10);
verifyScaledResidual(testCase,complementarity,lin.r_comp,1e-10);
verifyEqual(testCase,c.l,-lin.r_ineq-lin.G*c.xi,"AbsTol",0);
verifyEqual(testCase,c.z,(-lin.r_comp-lin.z.*c.l)./lin.l, ...
    "AbsTol",0);
end

function testDailyWaterBordersHaveEightTraceableRows(testCase)
lin = testCase.TestData.lin;
partition = testCase.TestData.recursive.partition;
waterIndex = testCase.TestData.index.water_constraint_index;
variables = testCase.TestData.index.variable_index;
verifyEqual(testCase,numel(partition.day),7);
for d = 1:7
    day = partition.day(d);
    rows = waterIndex.day==day.day_id;
    positions = waterIndex.inequality_position(rows);
    verifyEqual(testCase,nnz(rows),8);
    verifyEqual(testCase,borderDimension(day.water),8);
    if isfield(day.water,"inequality_indices")
        verifyEqual(testCase,sort(day.water.inequality_indices(:)), ...
            sort(positions(:)));
    end
    for position = positions(:).'
        localRow = lin.G(position,:);
        columns = find(localRow).';
        metadata = variables(columns,:);
        expected = waterIndex(waterIndex.inequality_position==position,:);
        verifyEqual(testCase,numel(columns),24);
        verifyEqual(testCase,unique(metadata.day),expected.day);
        verifyEqual(testCase,unique(metadata.asset_id),expected.hydro_id);
        verifyEqual(testCase,unique(string(metadata.variable_name)),"PH");
        verifyEqual(testCase,sort(metadata.hour),(1:24).');
    end
end
end

function testWaterCurvatureStaysOutsidePureHourlyThomasBlocks(testCase)
recursive = testCase.TestData.recursive;
expected = [589;590;589;590;590;590;590];
actual = reshape(arrayfun(@(day)size(day.M,1), ...
    recursive.partition.day),[],1);
verifyEqual(testCase,actual,expected);
for d = 1:7
    day = recursive.partition.day(d);
    verifyEqual(testCase,numel(day.hour),24);
    verifyEqual(testCase,borderDimension(day.water),8);
    verifyEqual(testCase,augmentedDimension(day),expected(d)+8);
    verifyEqual(testCase,size(day.water.G,1),8);
    verifyEqual(testCase,size(day.water.G,2),expected(d));
    for t = 1:24
        verifyEqual(testCase,size(day.hour(t).D,1),day.hour(t).dimension);
    end
end
end

function testDayResponsesAndGlobalCoreHaveContractDimensions(testCase)
recursive = testCase.TestData.recursive;
verifyEqual(testCase,numel(recursive.daily_responses),7);
verifyEqual(testCase,[recursive.daily_responses.day_id],14:20);
for d = 1:7
    response = recursive.daily_responses(d);
    verifyEqual(testCase,size(response.S),[14,14]);
    verifyEqual(testCase,size(response.c),[14,1]);
    verifyEqual(testCase,size(response.beta),[14,1]);
    verifyEqual(testCase,size(response.gamma),[14,1]);
    if isfield(response,"water_border_dimension")
        verifyEqual(testCase,response.water_border_dimension,8);
    end
end
verifyEqual(testCase,size(recursive.core.matrix),[16,16]);
verifyEqual(testCase,size(recursive.core.rhs),[16,1]);
end

function testStationarityFiniteDifferenceMatchesLagrangianHessian(testCase)
lin = testCase.TestData.lin;
state = testCase.TestData.state;
variables = testCase.TestData.index.variable_index;
hydro = string(variables.asset_type)=="hydro" & variables.hour>0;
direction = zeros(size(state.xi));
direction(hydro) = sin((1:nnz(hydro)).')/max(1,sqrt(nnz(hydro)));
step = 1e-4;
plus = state; plus.xi = state.xi+step*direction;
minus = state; minus.xi = state.xi-step*direction;
linPlus = rkkt.model.build_stage_b2b_multiday_linearization(plus, ...
    testCase.TestData.data,testCase.TestData.index,testCase.TestData.config);
linMinus = rkkt.model.build_stage_b2b_multiday_linearization(minus, ...
    testCase.TestData.data,testCase.TestData.index,testCase.TestData.config);
finiteDifference = (linPlus.r_dual-linMinus.r_dual)/(2*step);
analytic = lin.H*direction;
relative = norm(finiteDifference-analytic,2)/max(1,norm(analytic,2));
verifyLessThanOrEqual(testCase,relative,1e-7);
end

function testWaterHessianRebuildConsumesCurrentStateMultipliers(testCase)
state = testCase.TestData.state;
lin = testCase.TestData.lin;
row = testCase.TestData.index.water_constraint_index.inequality_position(1);
record = lin.constraints.water.constraint_hessians(1);
changed = state;
increment = max(0.125,0.25*state.z(row));
changed.z(row) = changed.z(row)+increment;
rebuilt = rkkt.model.build_stage_b2b_multiday_linearization(changed, ...
    testCase.TestData.data,testCase.TestData.index,testCase.TestData.config);
verifyEqual(testCase,rebuilt.H-lin.H, ...
    increment*record.global_hessian,"AbsTol",0);
changedSlack = state;
changedSlack.l(row) = 1.5*changedSlack.l(row);
rebuiltSlack = rkkt.model.build_stage_b2b_multiday_linearization(changedSlack, ...
    testCase.TestData.data,testCase.TestData.index,testCase.TestData.config);
verifyEqual(testCase,rebuiltSlack.H,lin.H,"AbsTol",0);
end

function testFullAndRecursiveDirectionsAreStrictlyEquivalent(testCase)
audit = testCase.TestData.audit;
verifyLessThanOrEqual(testCase,audit.direction_relative_error,1e-10);
for name = ["xi","y","l","z"]
    verifyLessThanOrEqual(testCase, ...
        audit.component_relative_errors.(name),1e-10);
end
verifyTrue(testCase,audit.passed.direction);
end

function testRecursiveDirectionReinsertsIntoIndependentFullKkt(testCase)
audit = testCase.TestData.audit;
fullAudit = testCase.TestData.full;
verifyLessThanOrEqual(testCase,audit.recursive_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase,audit.full_kkt_relative_residual,1e-10);
verifyLessThanOrEqual(testCase,fullAudit.diagnostics.relative_residual,1e-10);
verifyTrue(testCase,audit.passed.recursive_residual);
verifyTrue(testCase,audit.passed.full_residual_hard);
end

function testFixedZeroValuesAndDirectionsRemainExact(testCase)
recursive = testCase.TestData.recursive;
verifyEqual(testCase,recursive.fixed_zero.count,422);
verifyTrue(testCase,recursive.fixed_zero.all_exact_zero);
verifyEqual(testCase,recursive.fixed_zero.value,zeros(422,1));
verifyEqual(testCase,recursive.fixed_zero.direction,zeros(422,1));
end

function testExecutionFlagsProveAuditOnlyAndNoFallback(testCase)
recursive = testCase.TestData.recursive;
fullAudit = testCase.TestData.full;
verifyTrue(testCase,recursive.no_full_direction_fallback);
verifyFalse(testCase,recursive.full_direction_consumed);
verifyFalse(testCase,recursive.parallel_executed);
verifyEqual(testCase,string(recursive.linearization_identity), ...
    string(testCase.TestData.lin.identity));
verifyEqual(testCase,string(fullAudit.linearization_identity), ...
    string(testCase.TestData.lin.identity));
if isfield(fullAudit,"execution")
    verifyTrue(testCase,fullAudit.execution.audit_only);
end
verifyFalse(testCase,testCase.TestData.lin.execution.full_ipm_executed);
verifyFalse(testCase,testCase.TestData.lin.execution.optimization_executed);
verifyFalse(testCase,testCase.TestData.lin.execution.parallel_executed);
verifyFalse(testCase,testCase.TestData.lin.execution.stage_c1_entered);
end

function verifyScaledResidual(testCase,value,reference,tolerance)
relative = norm(value,2)/max(1,norm(reference,2));
verifyLessThanOrEqual(testCase,relative,tolerance);
end

function value = borderDimension(water)
value = scalarField(water,["border_dimension","dimension","row_count"]);
end

function value = augmentedDimension(day)
if isfield(day,"augmented_dimension")
    value = day.augmented_dimension;
elseif isfield(day,"water") && isfield(day.water,"augmented_dimension")
    value = day.water.augmented_dimension;
else
    value = size(day.M,1)+borderDimension(day.water);
end
end

function value = scalarField(object,names)
value = [];
for name = names
    if isfield(object,name)
        value = object.(name);
        break
    end
end
assert(~isempty(value) && isscalar(value), ...
    "stageB2B:tests:MissingDiagnosticField", ...
    "No scalar diagnostic field exists among %s.",strjoin(names,","));
end
