function recovery = recoverDirection( ...
        linearization,partition,responses,core)
%RECOVERDIRECTION Recover the canonical complete direction.

arguments
    linearization (1,1) struct
    partition (1,1) struct
    responses (:,1) struct
    core (1,1) struct
end

recovery = rkkt.solver.recover_stage_a_multiday_recursive_direction( ...
    linearization,partition,responses,core);
end
