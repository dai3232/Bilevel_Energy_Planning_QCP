function result = solveStageB2BFullKKTDirection(linearization)
%SOLVESTAGEB2BFULLKKTDIRECTION Solve the independent B-2B audit direction.

arguments
    linearization (1,1) struct
end

result = rkkt.solver.solve_stage_b2b_full_kkt_direction(linearization);
end
