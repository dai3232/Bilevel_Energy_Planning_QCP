function value = stage_b2c_recursive_runtime_water_index(runtime)
%STAGE_B2C_RECURSIVE_RUNTIME_WATER_INDEX Materialize the small water view.

arguments
    runtime (1,1) struct
end
map = runtime.water_map;
day = double(map.day(:));
hydro_id = double(map.hydro_id(:));
inequality_position = double(map.inequality_position(:));
bound_type = repmat("lower",numel(day),1);
bound_type(map.bound_side==2) = "upper";
constraint_id = compose("INEQ-WATER-D%03d-HYDRO%02d-%s", ...
    day,hydro_id,upper(bound_type));
value = table(constraint_id,day,hydro_id,bound_type, ...
    inequality_position);
end
