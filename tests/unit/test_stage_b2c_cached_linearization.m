function tests = test_stage_b2c_cached_linearization
%TEST_STAGE_B2C_CACHED_LINEARIZATION Prove cached updates match full rebuilds.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = rkkt.projectRoot();
config = rkkt.model.load_stage_b2c_configuration(root, ...
    CurrentStageExceptionToken= ...
        "B-2C-UNIFIED-RUNNER-REFACTOR-AUTHORIZED");
data = rkkt.data.load_project_data(root);
index = rkkt.indexing.build_stage_b2c_index( ...
    data,config,"RunId","B2C-CACHED-LINEARIZATION-TEST");
state = rkkt.model.initialize_stage_b2c_state(data,index,config);
reference = rkkt.model.build_stage_b2c_scaled_objective_linearization( ...
    state,data,index,config,"B-2C-FORMAL-IPM");
template = rkkt.model.build_stage_b2c_linearization_template( ...
    reference,data,index,config);
testCase.TestData.config = config;
testCase.TestData.data = data;
testCase.TestData.index = index;
testCase.TestData.state = state;
testCase.TestData.reference = reference;
testCase.TestData.template = template;
end

function testInitialCachedLinearizationMatchesFullAssembly(testCase)
full = testCase.TestData.reference;
cached = rkkt.model.update_stage_b2c_scaled_objective_linearization( ...
    testCase.TestData.state,testCase.TestData.template);
verify_linearizations_equal(testCase,cached,full);
end

function testAcceptedStepMatchesFullRebuildRoute(testCase)
args = {testCase.TestData.state,testCase.TestData.data, ...
    testCase.TestData.index,testCase.TestData.config, ...
    "PrecomputedLinearization",testCase.TestData.reference, ...
    "FullKktAuditEnabled",false};
cached = rkkt.diagnostics.execute_stage_b2c_iteration(args{:}, ...
    "LinearizationTemplate",testCase.TestData.template, ...
    "LinearizationUpdateMode","cached_numeric");
full = rkkt.diagnostics.execute_stage_b2c_iteration(args{:}, ...
    "LinearizationUpdateMode","full_rebuild");
verifyEqual(testCase,cached.recursive.direction,full.recursive.direction, ...
    "AbsTol",0);
verifyEqual(testCase,cached.state_after,full.state_after);
verify_linearizations_equal(testCase,cached.linearization_after, ...
    full.linearization_after);
metricNames = string(fieldnames(cached.metrics_after));
for name = metricNames.'
    actual = cached.metrics_after.(name);
    expected = full.metrics_after.(name);
    if isnumeric(actual)
        verifyEqual(testCase,actual,expected, ...
            "AbsTol",32*eps(max([1,abs(actual),abs(expected)])));
    else
        verifyEqual(testCase,actual,expected);
    end
end
verifyTrue(testCase,cached.fixed_linearization_structure_reused);
verifyFalse(testCase,full.fixed_linearization_structure_reused);
end

function verify_linearizations_equal(testCase,actual,expected)
for name = ["H","A","G","r_eq","r_ineq","r_dual","r_comp", ...
        "l","z","mu"]
    verifyEqual(testCase,actual.(name),expected.(name),"AbsTol",0);
end
verifyEqual(testCase,actual.identity,expected.identity);
verifyEqual(testCase,actual.objective,expected.objective);
verifyEqual(testCase,actual.constraints.eq,expected.constraints.eq, ...
    "AbsTol",0);
verifyEqual(testCase,actual.constraints.ineq,expected.constraints.ineq, ...
    "AbsTol",0);
verifyEqual(testCase,actual.constraints.eq_offset, ...
    expected.constraints.eq_offset,"AbsTol",0);
verifyEqual(testCase,actual.constraints.ineq_offset, ...
    expected.constraints.ineq_offset,"AbsTol",0);
verifyEqual(testCase,actual.constraints.water.constraint_value, ...
    expected.constraints.water.constraint_value,"AbsTol",0);
verifyEqual(testCase,actual.constraints.water.G, ...
    expected.constraints.water.G,"AbsTol",0);
verifyEqual(testCase,actual.state,expected.state);
end
