function result = evaluateStageBDailyHydroWater( ...
        powerMW,waterA,waterB,waterC)
%EVALUATESTAGEBDAILYHYDROWATER Evaluate one plant-day water function.

arguments
    powerMW (24,1) double {mustBeReal,mustBeFinite}
    waterA (1,1) double {mustBeReal,mustBeFinite}
    waterB (1,1) double {mustBeReal,mustBeFinite}
    waterC (1,1) double {mustBeReal,mustBeFinite}
end

result = rkkt.model.evaluate_stage_b_daily_hydro_water( ...
    powerMW,waterA,waterB,waterC);
end
