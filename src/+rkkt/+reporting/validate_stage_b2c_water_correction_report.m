function [passed,details] = validate_stage_b2c_water_correction_report(runRoot)
%VALIDATE_STAGE_B2C_WATER_CORRECTION_REPORT Validate package and semantics.

arguments
    runRoot (1,1) string
end
pathValue = fullfile(runRoot,"reports", ...
    "阶段B-2C_水量二阶松弛校正实验报告.docx");
[packagePassed,packageDetails] = ...
    rkkt.reporting.validate_docx_package(pathValue);
errors = string(packageDetails.errors(:));
visible = string(packageDetails.document_text);
required = ["阶段B-2C：水量二阶松弛校正实验报告"; ...
    "精确水量二阶松弛校正";"56条";"l_corrected"; ...
    "第17日";"完整KKT";"正式B-2C入口";"Stage C1"];
for token = required
    if ~contains(visible,token)
        errors(end+1) = "missing visible token: "+token; %#ok<AGROW>
    end
end
if ~isempty(regexp(visible,"(?i)\b(TBD|TODO|PLACEHOLDER)\b","once"))
    errors(end+1) = "placeholder token in report";
end
xml = string(packageDetails.document_xml);
tableCount = numel(regexp(xml,"<w:tbl>","match"));
headerCount = numel(regexp(xml,"<w:tblHeader/>","match"));
rowCount = numel(regexp(xml,"<w:tr>","match"));
cantSplitCount = numel(regexp(xml,"<w:cantSplit/>","match"));
if tableCount<6 || headerCount<6 || rowCount~=cantSplitCount || ...
        ~contains(xml,'w:tblW w:w="9360"') || ...
        ~contains(xml,'w:tblInd w:w="120"')
    errors(end+1) = "preset table geometry/header/cantSplit gate failed";
end
passed = packagePassed && isempty(errors);
details = struct("message","PASS","errors",errors, ...
    "report_path",string(pathValue),"package",packageDetails, ...
    "design_preset","standard_business_brief", ...
    "header_pattern","memo_masthead","table_count",tableCount, ...
    "all_rows_cant_split",rowCount==cantSplitCount);
if ~passed
    details.message = strjoin(errors," | ");
end
end
