function result = solveFullKKT(linearization)
%SOLVEFULLKKT Solve the independent complete-KKT audit direction.

arguments
    linearization (1,1) struct
end

result = rkkt.solver.solve_stage_a_multiday_full_kkt_direction( ...
    linearization);
end
