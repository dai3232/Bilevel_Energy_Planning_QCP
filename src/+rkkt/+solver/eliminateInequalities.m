function reduced = eliminateInequalities(linearization)
%ELIMINATEINEQUALITIES Eliminate the inequality directions exactly.

arguments
    linearization (1,1) struct
end

reduced = rkkt.solver.eliminate_stage_a_multiday_inequality_directions( ...
    linearization);
end
