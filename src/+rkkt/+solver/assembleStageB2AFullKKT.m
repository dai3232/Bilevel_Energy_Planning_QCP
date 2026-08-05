function assembly = assembleStageB2AFullKKT(linearization,config)
%ASSEMBLESTAGEB2AFULLKKT Assemble the Stage B-2A full sparse KKT system.

arguments
    linearization (1,1) struct
    config (1,1) struct
end

assembly = rkkt.solver.assemble_stage_b_multiday_full_kkt( ...
    linearization,config);
end
