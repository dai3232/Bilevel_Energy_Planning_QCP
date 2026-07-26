function audit = evaluate_stage_a4_3_physical_audit( ...
        runResult,index,data,config)
%EVALUATE_STAGE_A4_3_PHYSICAL_AUDIT Rebuild final physical feasibility.

arguments
    runResult (1,1) struct
    index (1,1) struct
    data (1,1) struct
    config (1,1) struct
end
lin = runResult.final_linearization;
zeroDirection = zeros(size(runResult.final_state.xi));
physical = recover_stage_a_physical_arrays( ...
    runResult.final_state.xi,zeroDirection,index,data);
constraintIndex = index.constraint_index;
equalityIndex = constraintIndex( ...
    string(constraintIndex.constraint_type)=="equality",:);
assert(height(equalityIndex)==numel(lin.r_eq), ...
    "stageA4:a43:PhysicalEqualityIndex", ...
    "Equality constraint index does not match r_eq.");

names = string(equalityIndex.constraint_name);
balanceMask = names=="hourly_power_balance";
terminalMask = names=="terminal_soc";
socMask = names=="soc_dynamics" | terminalMask;
links = index.soc_link_map;
dailyStructure = true;
for day = 14:20
    first = links(links.day==day & links.hour==1,:);
    terminal = links(links.day==day & links.terminal_equality,:);
    dailyStructure = dailyStructure && height(first)==2 && ...
        all(isnan(first.predecessor_hour)) && ...
        all(first.predecessor_soc_global_index==0) && ...
        all(first.initial_energy_fraction==0.5) && ...
        height(terminal)==2 && all(terminal.hour==24) && ...
        all(terminal.terminal_energy_fraction==0.5);
end
noInterday = ~any(links.predecessor_hour==24 & links.hour==1) && ...
    dailyStructure;

fixed = physical.fixed_zero_audit;
iterationEvidence = runResult.iteration_summary;
if isempty(iterationEvidence)
    actualFixedDirection = Inf;
else
    actualFixedDirection = max( ...
        iterationEvidence.fixed_zero_maximum_absolute_direction);
    if ~(all(iterationEvidence.fixed_zero_exact) && ...
            all(iterationEvidence.fixed_zero_count== ...
            config.expected_fixed_zero_count))
        actualFixedDirection = Inf;
    end
end
values = [ ...
    norm(lin.r_eq,inf)
    max_abs_selected(lin.r_eq,balanceMask)
    max_abs_selected(lin.r_eq,socMask)
    max_abs_selected(lin.r_eq,terminalMask)
    runResult.final_metrics.physical_inequality_violation
    fixed.maximum_absolute_value
    actualFixedDirection
    double(~noInterday)];
thresholds = [1e-8;1e-8;1e-8;1e-8;1e-8;0;0;0];
auditId = [ ...
    "A43-PHY-EQUALITY"
    "A43-PHY-POWER-BALANCE"
    "A43-PHY-SOC-CHAIN"
    "A43-PHY-SOC-TERMINAL"
    "A43-PHY-INEQUALITY"
    "A43-PHY-FIXED-ZERO-VALUE"
    "A43-PHY-FIXED-ZERO-DIRECTION"
    "A43-PHY-NO-INTERDAY-SOC"];
requirement = [ ...
    "all formal equality residuals"
    "hourly power-balance residuals"
    "daily SOC-chain residuals"
    "fourteen day-terminal SOC equalities"
    "maximum physical inequality violation"
    "fixed-zero renewable physical values"
    "fixed-zero renewable directions"
    "no cross-day SOC predecessor"];
actualValue = compose("%.17g",values);
thresholdText = compose("<=%.17g",thresholds);
status = repmat("FAIL",numel(values),1);
status(values<=thresholds) = "PASS";
evidencePath = repmat("iterations/iteration_summary.csv",numel(values),1);
evidencePath(2:4) = "results/physical_results.mat";
evidencePath(6) = "results/physical_results.mat";
evidencePath(7) = "iterations/iteration_summary.csv";
evidencePath(8) = "indices/soc_link_map.csv";
audit = table(auditId,requirement,actualValue,thresholdText,status, ...
    evidencePath,"VariableNames",{"audit_id","requirement", ...
    "actual_value","threshold","status","evidence_path"});
assert(nnz(terminalMask)==14 && ...
    fixed.count==config.expected_fixed_zero_count, ...
    "stageA4:a43:PhysicalAuditStructure", ...
    "The final physical audit structure is incomplete.");
end

function value = max_abs_selected(vector,mask)
if any(mask)
    value = max(abs(vector(mask)));
else
    value = Inf;
end
end
