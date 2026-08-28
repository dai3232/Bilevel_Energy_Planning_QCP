function value = build_stage_b2c_water_input_audit( ...
        data,config,runId)
%BUILD_STAGE_B2C_WATER_INPUT_AUDIT Audit selected daily hydro inputs.

arguments
    data (1,1) struct
    config (1,1) struct
    runId (1,1) string
end
n = numel(config.days)*numel(config.hydro_ids);
run_id = repmat(runId,n,1);
day = repelem(config.days(:),numel(config.hydro_ids));
hydro_id = repmat(config.hydro_ids(:),numel(config.days),1);
water_a = zeros(n,1); water_b = zeros(n,1); water_c = zeros(n,1);
water_min_m3 = zeros(n,1); water_max_m3 = zeros(n,1);
max_output_mw = zeros(n,1); all_finite = false(n,1);
min_not_above_max = false(n,1); nonnegative_bounds = false(n,1);
status = repmat("FAIL",n,1);
for row = 1:n
    h = hydro_id(row); d = day(row);
    water_a(row) = data.base.hydro.waterA(h);
    water_b(row) = data.base.hydro.waterB(h);
    water_c(row) = data.base.hydro.waterC(h);
    max_output_mw(row) = data.base.hydro.maxOutputMW(h);
    water_min_m3(row) = data.timeseries.hydroWaterMin(d,h);
    water_max_m3(row) = data.timeseries.hydroWaterMax(d,h);
    all_finite(row) = all(isfinite([water_a(row),water_b(row), ...
        water_c(row),max_output_mw(row),water_min_m3(row), ...
        water_max_m3(row)]));
    min_not_above_max(row) = water_min_m3(row)<=water_max_m3(row);
    nonnegative_bounds(row) = water_min_m3(row)>=0 && ...
        water_max_m3(row)>=0 && max_output_mw(row)>0;
    if all_finite(row) && min_not_above_max(row) && ...
            nonnegative_bounds(row)
        status(row) = "PASS";
    end
end
value = table(run_id,day,hydro_id,water_a,water_b,water_c, ...
    water_min_m3,water_max_m3,max_output_mw,all_finite, ...
    min_not_above_max,nonnegative_bounds,status);
end
