function acceptance = initialize_stage0_acceptance(projectRoot)
%INITIALIZE_STAGE0_ACCEPTANCE Load the controlled stage-0 acceptance matrix.

matrixPath = fullfile(projectRoot,'stages','stage_0','阶段0_验收矩阵.csv');
matrix = readtable(matrixPath,'TextType','string', ...
    'VariableNamingRule','preserve','Encoding','UTF-8');
required = ["test_id","requirement","threshold","blocking"];
if ~all(ismember(required,string(matrix.Properties.VariableNames)))
    error('stage0:acceptance:InvalidMatrix', ...
        'The stage-0 acceptance matrix is missing required columns.');
end

blocking = matrix.blocking;
if ~islogical(blocking)
    blocking = lower(strip(string(blocking))) == "true";
end
n = height(matrix);
acceptance = table(string(matrix.test_id),string(matrix.requirement), ...
    string(matrix.threshold),repmat("",n,1),repmat("",n,1), ...
    repmat("NOT_RUN",n,1),logical(blocking),repmat("",n,1), ...
    repmat("",n,1),'VariableNames',{'test_id','requirement','threshold', ...
    'actual_value','comparison','status','blocking','evidence_path','checked_at'});
end
