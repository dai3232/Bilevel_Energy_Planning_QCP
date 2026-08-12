function [passed,details] = validate_stage_b2c_report(runRoot)
%VALIDATE_STAGE_B2C_REPORT Validate OOXML and required visible semantics.

arguments
    runRoot (1,1) string
end
pathValue=fullfile(runRoot,"reports", ...
    "阶段B-2C_七日递推IPM收敛与水量物理验收报告.docx");
errors=strings(0,1);
if ~isfile(pathValue)
    errors(end+1)="missing report";
    passed=false; details=make_details(errors,pathValue); return
end
[packagePassed,packageDetails]=rkkt.reporting.validate_docx_package(pathValue);
if ~packagePassed, errors=[errors;string(packageDetails.errors(:))]; end
visible=string(packageDetails.document_text);
required=["阶段B-2C：七日递推IPM收敛与水量物理验收报告"; ...
    "第14—20日";"非零水量";"672";"23个右端";"28项"; ...
    "SB-PHY-001";"完整KKT";"仅作独立审计";"Stage C1"; ...
    "56条水量松弛";"精确二阶余项";"中心性限幅校正"; ...
    "l_corrected";"beta"];
for token=required
    if ~contains(visible,token)
        errors(end+1)="missing visible token: "+token; %#ok<AGROW>
    end
end
if contains(visible,["stage_A4","STAGE A4"])
    errors(end+1)="stale stage identity in report";
end
if ~isempty(regexp(visible,"(?i)\b(TBD|TODO|PLACEHOLDER)\b","once"))
    errors(end+1)="placeholder token in report";
end
xml=string(packageDetails.document_xml);
tableCount=numel(regexp(xml,"<w:tbl>","match"));
headerCount=numel(regexp(xml,"<w:tblHeader/>","match"));
rowCount=numel(regexp(xml,"<w:tr>","match"));
cantSplitCount=numel(regexp(xml,"<w:cantSplit/>","match"));
geometryPassed=contains(xml,'w:tblW w:w="9360"') && ...
    contains(xml,'w:tblInd w:w="120"');
if tableCount<7 || headerCount<6 || rowCount~=cantSplitCount || ...
        ~geometryPassed
    errors(end+1)="preset table geometry/header/cantSplit gate failed";
end
passed=isempty(errors); details=make_details(errors,pathValue);
details.package=packageDetails;
details.design_preset="standard_business_brief";
details.header_pattern="memo_masthead";
details.table_count=tableCount;
details.all_rows_cant_split=rowCount==cantSplitCount;
end

function details=make_details(errors,pathValue)
details=struct("message","PASS","errors",errors, ...
    "report_path",string(pathValue));
if ~isempty(errors), details.message=strjoin(errors," | "); end
end
