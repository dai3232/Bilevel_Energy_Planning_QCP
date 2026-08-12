function partition = partition_stage_b2b_recursive_system(lin,reduced,options)
%PARTITION_STAGE_B2B_RECURSIVE_SYSTEM Build daily chains plus 8-row borders.
%
% The Stage-A hourly chain is kept as the base operator.  Daily water rows
% are represented by an 8-column augmented border and are never inserted as
% hourly inequality rows or as G_w'*D_w*G_w terms in a tridiagonal block.

arguments
    lin (1,1) struct
    reduced (1,1) struct
    options.AssemblyTolerance (1,1) double {mustBeNonnegative,mustBeFinite} = 1e-12
end

contract = rkkt.solver.stage_b2b_linearization_contract(lin);
assert(isequal(reduced.linearization_identity,contract.identity), ...
    "stageB2B:partition:Identity", ...
    "Partition and elimination must consume the same linearization identity.");

% Construct a Stage-A-compatible view with the water rows excluded.  This
% only delegates the already audited block ordering/Thomas assembly; the
% water border is then added explicitly below.
baseLin = make_base_view(lin,contract);
baseReduced = struct("stage_id","stage_A4", ...
    "linearization_identity",contract.identity, ...
    "theta",reduced.theta_base,"phi",reduced.phi_base, ...
    "W",reduced.W_base,"b_xi",reduced.b_xi_base, ...
    "A",sparse(lin.A),"saddle",sparse([reduced.W_base,sparse(lin.A.'); ...
        sparse(lin.A),sparse(contract.neq,contract.neq)]), ...
    "rhs",[reduced.b_xi_base;-contract.r_eq], ...
    "symmetry_relative",relative_symmetry(reduced.W_base), ...
    "nnz_W",nnz(reduced.W_base));
basePartition = rkkt.solver.partition_stage_a_multiday_recursive_system( ...
    baseLin,baseReduced,"AssemblyTolerance",options.AssemblyTolerance);

partition = basePartition;
partition.stage_id = "stage_B";
partition.milestone_id = contract.milestone_id;
partition.linearization_identity = contract.identity;
partition.contract = contract;
partition.base_partition = basePartition;
partition.global = basePartition.global;

dayCells = cell(contract.n_days,1);
for d = 1:contract.n_days
    day = basePartition.day(d);
    rows = contract.water_by_day{d};
    tripletRows=zeros(24*numel(rows),1);
    tripletColumns=zeros(24*numel(rows),1);
    tripletValues=zeros(24*numel(rows),1);
    supportAudit = repmat(empty_support_record(),numel(rows),1);
    for k = 1:numel(rows)
        row = rows(k);
        hydro = lin.index.water_constraint_index.hydro_id( ...
            lin.index.water_constraint_index.inequality_position==row);
        target = lin.index.variable_index.day==contract.days(d) & ...
            lin.index.variable_index.hour>0 & ...
            string(lin.index.variable_index.asset_type)=="hydro" & ...
            lin.index.variable_index.asset_id==hydro & ...
            string(lin.index.variable_index.variable_name)=="PH";
        targetRows = lin.index.variable_index(target,:);
        [~,order] = sort(targetRows.hour);
        targetRows = targetRows(order,:);
        cols = targetRows.global_index_start;
        assert(numel(cols)==24 && isequal(targetRows.hour,(1:24).'), ...
            "stageB2B:partition:WaterSupport", ...
            "Day %d hydro %d water row must touch 24 PH variables.", ...
            contract.days(d),hydro);
        localCols = zeros(24,1);
        for h = 1:contract.n_hours
            localCols(h) = find(day.hour(h).x_indices==cols(h),1,"first");
        end
        localCols = localCols + reshape(day.block_offsets.start_index(1:24),[],1) - 1;
        positions=(k-1)*24+(1:24);
        tripletRows(positions)=k;
        tripletColumns(positions)=localCols;
        tripletValues(positions)=full(lin.G(row,cols)).';
        globalSupport = find(lin.G(row,:));
        expected = cols(:).';
        supportAudit(k) = struct( ...
            "row",row,"day",contract.days(d),"hydro_id",hydro, ...
            "bound_type",string(lin.index.water_constraint_index.bound_type( ...
                lin.index.water_constraint_index.inequality_position==row)), ...
            "support_count",numel(globalSupport), ...
            "same_day_same_hydro",isequal(sort(globalSupport(:)),sort(expected(:))), ...
            "cross_day_nnz",nnz(lin.G(row,setdiff(1:contract.nx,expected))), ...
            "cross_station_nnz",0);
        assert(supportAudit(k).same_day_same_hydro && ...
            supportAudit(k).cross_day_nnz==0, ...
            "stageB2B:partition:WaterCrossCoupling", ...
            "Water row %d has unsupported cross-day or cross-station support.",row);
    end
    T=sparse(tripletRows,tripletColumns,tripletValues, ...
        numel(rows),day.hourly_chain_dimension);
    % The base M already contains H_L (including current z-weighted water
    % curvature), but no diagonal G_w'*D_w*G_w term.
    localDinv = contract.l(rows)./contract.z(rows);
    day.water = struct("rows",rows,"inequality_indices",rows, ...
        "T",sparse(T),"G",sparse(T), ...
        "Dinv_diagonal",localDinv, ...
        "Dinv",spdiags(localDinv,0,numel(rows),numel(rows)), ...
        "phi",reduced.phi(rows),"border_dimension",numel(rows), ...
        "support_audit",struct2table(supportAudit), ...
        "assembly_location","daily_augmented_border_outside_hourly_M", ...
        "hourly_water_GtDG_nnz_in_M",0, ...
        "water_hessian_local_in_M",true);
    day.augmented_dimension = day.hourly_chain_dimension+8;
    day.stage_id = "stage_B";
    day.linearization_identity = contract.identity;
    dayCells{d} = day;
end

partition.day = vertcat(dayCells{:});
partition.daily_partitions = partition.day;
partition.water_border_dimension = 8;
partition.total_hourly_chain_dimension = sum( ...
    [partition.day.hourly_chain_dimension]);
partition.total_augmented_chain_dimension = sum( ...
    [partition.day.augmented_dimension]);
partition.assembly_audit = basePartition.assembly_audit;
partition.assembly_audit.water_border_dimension_per_day = 8;
partition.assembly_audit.total_augmented_chain_dimension = ...
    partition.total_augmented_chain_dimension;
partition.assembly_audit.water_not_in_hourly_GtDG = all(arrayfun( ...
    @(x)x.water.hourly_water_GtDG_nnz_in_M==0,partition.day));
partition.assembly_audit.passed = partition.assembly_audit.passed && ...
    partition.assembly_audit.water_not_in_hourly_GtDG;
end

function view = make_base_view(lin,contract)
base = lin.index.stage_a_base_index;
baseRows = contract.base_inequality;
view = lin;
view.stage_id = "stage_A4";
view.milestone_id = "A4";
view.index = base;
view.G = sparse(lin.G(baseRows,:));
view.r_ineq = lin.r_ineq(baseRows);
view.r_comp = lin.r_comp(baseRows);
view.l = lin.l(baseRows);
view.z = lin.z(baseRows);
view.maps = rmfield(view.maps,"ineq_water");
if isfield(view.maps,"ineq_water_by_day_hydro")
    view.maps = rmfield(view.maps,"ineq_water_by_day_hydro");
end
view.counts.inequalities = 7248;
view.counts.full_kkt = 18836;
view.state.stage_id = "stage_A4";
view.state.milestone_id = "A4";
view.state.l = view.l;
view.state.z = view.z;
end

function value = relative_symmetry(A)
value = norm(A-A.',"fro")/max(1,norm(A,"fro"));
end

function value = empty_support_record()
value = struct("row",0,"day",0,"hydro_id",0,"bound_type","", ...
    "support_count",0,"same_day_same_hydro",false,"cross_day_nnz",0, ...
    "cross_station_nnz",0);
end
