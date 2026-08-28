function partition = partition_stage_b2c_daily_joint_system(lin,reduced,options)
%PARTITION_STAGE_B2C_DAILY_JOINT_SYSTEM Extract current numerical day blocks.
%
% The canonical structure is supplied by a once-per-run template. Only the
% current reduced matrices, couplings, right-hand sides, and water ratios
% are refreshed inside an IPM iteration.

arguments
    lin (1,1) struct
    reduced (1,1) struct
    options.StructureTemplate (1,1) struct = struct()
end

structureTemplate = options.StructureTemplate;
structureTemplateReused = ~isempty(fieldnames(structureTemplate));
if ~structureTemplateReused
    structureTemplate = ...
        rkkt.solver.build_stage_b2c_daily_joint_structure_template(lin);
end
contract = refresh_contract(lin,structureTemplate);
assert(isequal(reduced.linearization_identity,contract.identity), ...
    "stageB2C:dailyJoint:PartitionIdentity", ...
    "Partition and elimination must use the same linearization.");

globalIndices = structureTemplate.global_indices;
globalMatrix = reduced.saddle(globalIndices,globalIndices);
globalRhs = reduced.rhs(globalIndices);
dayCells = cell(contract.n_days,1);

for d = 1:contract.n_days
    staticDay = structureTemplate.day(d);
    localIndices = staticDay.canonical_reduced_indices;
    matrix = reduced.saddle(localIndices,localIndices);
    coupling = reduced.saddle(localIndices,globalIndices);
    rhs = reduced.rhs(localIndices);
    waterRows = staticDay.water_rows;
    waterRatio = contract.l(waterRows)./contract.z(waterRows);

    dayCells{d} = struct( ...
        "day_id",staticDay.day_id, ...
        "linearization_identity",contract.identity, ...
        "canonical_reduced_indices",localIndices, ...
        "matrix",sparse(matrix), ...
        "coupling",sparse(coupling), ...
        "capacity_coupling",sparse(coupling(:,1:14)), ...
        "rhs",rhs, ...
        "dimension",numel(localIndices), ...
        "nnz",nnz(matrix), ...
        "q_day_local_positions",staticDay.q_day_local_positions, ...
        "pi_day_local_positions",staticDay.pi_day_local_positions, ...
        "hourly_local_positions",staticDay.hourly_local_positions, ...
        "hourly_dimension",staticDay.hourly_dimension, ...
        "rho_coupling_nnz",nnz(coupling(:,15:16)), ...
        "symmetry_relative",relative_symmetry(matrix), ...
        "water_rows",waterRows, ...
        "maximum_water_l_over_z",max(waterRatio), ...
        "minimum_water_z_over_l",min(1./waterRatio), ...
        "water_eta_dimension",0);
end

days = vertcat(dayCells{:});
templateDimensions = reshape(arrayfun(@(value) ...
    numel(value.canonical_reduced_indices),structureTemplate.day),1,[]);
assert(isequal(reshape([days.dimension],1,[]),templateDimensions) && ...
    all([days.rho_coupling_nnz]==0) && ...
    all([days.water_eta_dimension]==0), ...
    "stageB2C:dailyJoint:DayDimensions", ...
    "Daily joint dimensions or external coupling do not match the template.");

partition = struct();
partition.stage_id = "stage_B";
partition.milestone_id = "B-2C";
partition.linearization_identity = contract.identity;
partition.contract = contract;
partition.global = struct("canonical_reduced_indices",globalIndices, ...
    "matrix",sparse(globalMatrix),"rhs",globalRhs,"dimension",16, ...
    "symmetry_relative",relative_symmetry(globalMatrix));
partition.day = days;
partition.days = contract.days;
partition.permutation = structureTemplate.permutation;
partition.permutation_is_bijection = true;
partition.cross_day_nnz = structureTemplate.cross_day_nnz;
partition.total_daily_dimension = structureTemplate.total_daily_dimension;
partition.canonical_reduced_dimension = ...
    structureTemplate.canonical_reduced_dimension;
partition.water_eta_dimension = 0;
partition.full_inequality_elimination = true;
partition.structure_template_reused = structureTemplateReused;
partition.structure_template_version = structureTemplate.template_version;
end

function contract = refresh_contract(lin,template)
assert(template.nx==size(lin.H,1) && template.neq==size(lin.A,1) && ...
    template.nineq==size(lin.G,1) && ...
    isequal(template.days(:).',double(lin.layout.days(:).')) && ...
    isequal(template.hours(:).',double(lin.layout.hours(:).')), ...
    "stageB2C:dailyJoint:StructureTemplate", ...
    "The cached daily-joint structure does not match this linearization.");
contract = template.contract_static;
contract.identity = lin.identity;
contract.r_dual = double(lin.r_dual(:));
contract.r_eq = double(lin.r_eq(:));
contract.r_ineq = double(lin.r_ineq(:));
contract.r_comp = double(lin.r_comp(:));
contract.l = double(lin.l(:));
contract.z = double(lin.z(:));
contract.xi = double(lin.state.xi(:));
contract.l_water = contract.l(contract.water_inequality);
contract.z_water = contract.z(contract.water_inequality);
contract.l_base = contract.l(contract.base_inequality);
contract.z_base = contract.z(contract.base_inequality);
contract.r_ineq_water = contract.r_ineq(contract.water_inequality);
contract.r_comp_water = contract.r_comp(contract.water_inequality);
contract.r_ineq_base = contract.r_ineq(contract.base_inequality);
contract.r_comp_base = contract.r_comp(contract.base_inequality);
end

function value = relative_symmetry(matrix)
value = norm(matrix-matrix.',"fro")/max(1,norm(matrix,"fro"));
end
