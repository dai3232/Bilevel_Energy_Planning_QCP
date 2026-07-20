function acceptance = initialize_stage_a2_acceptance(projectRoot)
%INITIALIZE_STAGE_A2_ACCEPTANCE Load the frozen six-row A2 gate inventory.

arguments
    projectRoot (1,1) string
end
matrixPath = fullfile(projectRoot,"stages","stage_A2", ...
    "阶段A2_验收矩阵.csv");
options = detectImportOptions(matrixPath,"Encoding","UTF-8","Delimiter",",");
options.VariableNamesLine = 1;
options.DataLines = [2 Inf];
options = setvartype(options,options.VariableNames,"string");
matrix = readtable(matrixPath,options);
required = ["test_id","requirement","threshold","blocking"];
assert(all(ismember(required,string(matrix.Properties.VariableNames))), ...
    "stageA2:acceptance:InvalidMatrix", ...
    "Stage A2 acceptance matrix is missing a required column.");

expected = ["SA2-MAT-001";"SA2-ZERO-001";"SA2-ZERO-002"; ...
    "SA2-EQ-001";"SA2-EQ-002";"SA2-PHY-001"];
ids = string(matrix.test_id);
assert(isequal(ids,expected) && numel(unique(ids))==6, ...
    "stageA2:acceptance:UnexpectedInventory", ...
    "Stage A2 acceptance inventory must remain the frozen six-row list.");
blocking = matrix.blocking;
if ~islogical(blocking)
    blocking = lower(strip(string(blocking)))=="true";
end
assert(all(blocking),"stageA2:acceptance:NonblockingRow", ...
    "All six Stage A2 acceptance rows must remain blocking.");
n = height(matrix);
acceptance = table(ids,string(matrix.requirement),string(matrix.threshold), ...
    repmat("",n,1),repmat("",n,1),repmat("NOT_RUN",n,1), ...
    logical(blocking),repmat("",n,1),repmat("",n,1), ...
    'VariableNames',{'test_id','requirement','threshold','actual_value', ...
    'comparison','status','blocking','evidence_path','checked_at'});
end
