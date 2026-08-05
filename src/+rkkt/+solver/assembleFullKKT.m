function assembly = assembleFullKKT(linearization)
%ASSEMBLEFULLKKT Assemble the Stage-A4 full sparse KKT system.

arguments
    linearization (1,1) struct
end

assembly = rkkt.solver.assemble_stage_a_multiday_full_kkt(linearization);
end
