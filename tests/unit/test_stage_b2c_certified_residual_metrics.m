function tests = test_stage_b2c_certified_residual_metrics
%TEST_STAGE_B2C_CERTIFIED_RESIDUAL_METRICS Verify certification and fallback.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root,"src"));
end

function testBinary64ResidualIsAcceptedOnlyWithCertificate(testCase)
matrix = sparse([4,1;1,3]);
solution = [0.25;-0.5];
rhs = matrix*solution;
metrics = rkkt.solver.compute_certified_retained_residual_metrics( ...
    matrix,solution,rhs,1e-10);

verifyTrue(testCase,metrics.certified_binary64);
verifyFalse(testCase,metrics.extended_residual_fallback_used);
verifyFalse(testCase,metrics.extended_residual_used);
verifyEqual(testCase,metrics.residual_validation_mode, ...
    "certified_binary64");
verifyLessThanOrEqual(testCase, ...
    metrics.certified_relative_upper_bound,1e-10);
end

function testUncertifiedResidualFallsBackToDoubleDouble(testCase)
matrix = speye(2);
solution = [1;1];
rhs = [1+1e-5;1];
metrics = rkkt.solver.compute_certified_retained_residual_metrics( ...
    matrix,solution,rhs,1e-10);

verifyFalse(testCase,metrics.certified_binary64);
verifyTrue(testCase,metrics.extended_residual_fallback_used);
verifyTrue(testCase,metrics.extended_residual_used);
verifyEqual(testCase,metrics.residual_validation_mode, ...
    "extended_double_double_fallback");
verifyGreaterThan(testCase,metrics.maximum_column_relative,1e-10);
end

function testMultipleRightHandSidesAreCertifiedTogether(testCase)
matrix = sparse(diag([2,3,5]));
solution = [1,-2;3,4;-1,0.5];
rhs = matrix*solution;
metrics = rkkt.solver.compute_certified_retained_residual_metrics( ...
    matrix,solution,rhs,1e-10);

verifyTrue(testCase,metrics.certified_binary64);
verifySize(testCase,metrics.certified_column_relative_upper_bound,[1,2]);
verifyLessThanOrEqual(testCase, ...
    max(metrics.certified_column_relative_upper_bound),1e-10);
end
