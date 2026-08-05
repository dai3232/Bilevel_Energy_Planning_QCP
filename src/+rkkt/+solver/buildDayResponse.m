function response = buildDayResponse(dayPartition,thomas)
%BUILDDAYRESPONSE Form one day response from its retained chain solve.

arguments
    dayPartition (1,1) struct
    thomas (1,1) struct
end

response = rkkt.solver.form_stage_a_multiday_day_response( ...
    dayPartition,thomas);
end
