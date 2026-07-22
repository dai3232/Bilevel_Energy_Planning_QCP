function tests = test_stage_a4_step_update
%TEST_STAGE_A4_STEP_UPDATE Verify the frozen A4 fraction and update rules.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(projectRoot,"src")));
testCase.TestData.project_root = projectRoot;
end

function testNoNegativeDirectionUsesUnitStep(testCase)
step = compute_fraction_to_boundary_step([1;2;3],[0;4;1],0.9995);
verifyEqual(testCase,step.alpha,1,"AbsTol",0);
verifyEqual(testCase,step.raw_boundary_step,Inf);
verifyEqual(testCase,step.limiting_index,0);
verifyTrue(testCase,isnan(step.limiting_value));
verifyTrue(testCase,isnan(step.limiting_direction));
verifyEqual(testCase,step.negative_direction_count,0);
verifyFalse(testCase,step.step_was_limited);
verifyEqual(testCase,step.minimum_trial_value,1,"AbsTol",0);
end

function testNegativeDirectionUsesTightestUnscaledRatio(testCase)
step = compute_fraction_to_boundary_step([2;4;3],[-1;-8;1],0.9);
verifyEqual(testCase,step.raw_boundary_step,0.5,"AbsTol",0);
verifyEqual(testCase,step.alpha,0.45,"AbsTol",eps(0.45));
verifyEqual(testCase,step.limiting_index,2);
verifyEqual(testCase,step.limiting_value,4,"AbsTol",0);
verifyEqual(testCase,step.limiting_direction,-8,"AbsTol",0);
verifyEqual(testCase,step.negative_direction_count,2);
verifyTrue(testCase,step.step_was_limited);
verifyGreaterThan(testCase,step.minimum_trial_value,0);
end

function testNearBoundaryRemainsStrictlyPositive(testCase)
value = [1e-12;1];
direction = [-1;0];
step = compute_fraction_to_boundary_step(value,direction,0.9995);
trial = value + step.alpha*direction;
verifyEqual(testCase,step.raw_boundary_step,1e-12,"RelTol",eps);
verifyEqual(testCase,step.alpha,0.9995e-12,"RelTol",eps);
verifyEqual(testCase,step.limiting_index,1);
verifyGreaterThan(testCase,trial(1),0);
verifyEqual(testCase,step.minimum_trial_value,trial(1),"AbsTol",0);
end

function testUnitStepStillReportsTightestNegativeComponent(testCase)
step = compute_fraction_to_boundary_step([4;10],[-1;-1],0.9995);
verifyEqual(testCase,step.alpha,1,"AbsTol",0);
verifyEqual(testCase,step.raw_boundary_step,4,"AbsTol",0);
verifyEqual(testCase,step.limiting_index,1);
verifyEqual(testCase,step.limiting_value,4,"AbsTol",0);
verifyEqual(testCase,step.limiting_direction,-1,"AbsTol",0);
verifyFalse(testCase,step.step_was_limited);
end

function testStateUpdateUsesSeparatePrimalAndDualSteps(testCase)
state = struct( ...
    "xi",[2;4],"y",[5;6;7],"l",[8;10],"z",[12;14], ...
    "stage_id","stage_A4","audit_token",17);
direction = struct( ...
    "xi",[-1;2],"y",[1;-1;3],"l",[-2;1],"z",[-4;2]);
updated = update_primal_dual_state(state,direction,0.25,0.5);
verifyEqual(testCase,updated.xi,[1.75;4.5],"AbsTol",0);
verifyEqual(testCase,updated.l,[7.5;10.25],"AbsTol",0);
verifyEqual(testCase,updated.y,[5.5;5.5;8.5],"AbsTol",0);
verifyEqual(testCase,updated.z,[10;15],"AbsTol",0);
verifyEqual(testCase,updated.stage_id,"stage_A4");
verifyEqual(testCase,updated.audit_token,17);
verifyTrue(testCase,all(structfun(@(value)all(isfinite(value)), ...
    rmfield(updated,["stage_id","audit_token"]))));
verifyTrue(testCase,all(updated.l > 0));
verifyTrue(testCase,all(updated.z > 0));
end

function testStepRejectsInvalidInputs(testCase)
verifyError(testCase, ...
    @()compute_fraction_to_boundary_step([1;0],[0;0],0.9995), ...
    "stageA4:step:NonpositiveValues");
verifyError(testCase, ...
    @()compute_fraction_to_boundary_step([1;2],[0;NaN],0.9995), ...
    "stageA4:step:NonfiniteVector");
verifyError(testCase, ...
    @()compute_fraction_to_boundary_step([1;2],[0;1;2],0.9995), ...
    "stageA4:step:DimensionMismatch");
verifyError(testCase, ...
    @()compute_fraction_to_boundary_step([1,2],[0;1],0.9995), ...
    "stageA4:step:InvalidVector");
verifyError(testCase, ...
    @()compute_fraction_to_boundary_step([1;2],[0;1],1), ...
    "stageA4:step:InvalidTau");
end

function testUpdateRejectsInvalidInputsAndOutputs(testCase)
state = struct("xi",[1;2],"y",1,"l",[1;2],"z",[3;4]);
direction = struct("xi",[0;0],"y",0,"l",[-2;0],"z",[0;0]);
verifyError(testCase, ...
    @()update_primal_dual_state(state,direction,0,0.5), ...
    "stageA4:update:InvalidStep");
badState = state;
badState.l(1) = 0;
verifyError(testCase, ...
    @()update_primal_dual_state(badState,direction,0.25,0.5), ...
    "stageA4:update:NonpositiveInput");
badDirection = direction;
badDirection.xi = 0;
verifyError(testCase, ...
    @()update_primal_dual_state(state,badDirection,0.25,0.5), ...
    "stageA4:update:DimensionMismatch");
verifyError(testCase, ...
    @()update_primal_dual_state(state,direction,0.5,0.5), ...
    "stageA4:update:NonpositiveOutput");
badDirection = rmfield(direction,"z");
verifyError(testCase, ...
    @()update_primal_dual_state(state,badDirection,0.25,0.5), ...
    "stageA4:update:MissingDirectionField");
end
