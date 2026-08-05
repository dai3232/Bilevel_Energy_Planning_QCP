function [passed,details] = validate_stage_b2b_report(runRoot)
%VALIDATE_STAGE_B2B_REPORT Validate OOXML package and visible semantics.

arguments
    runRoot (1,1) string
end
pathValue=fullfile(runRoot,"reports", ...
    "阶段B-2B_日级水量边框递推KKT方向等价验证报告.docx");
errors=strings(0,1);
if ~isfile(pathValue)
    errors(end+1)="missing report";
    passed=false; details=make_details(errors,pathValue); return
end
[packagePassed,packageDetails]=rkkt.reporting.validate_docx_package(pathValue);
if ~packagePassed, errors=[errors;string(packageDetails.errors(:))]; end
visible=string(packageDetails.document_text);
required=["阶段B-2B：日级水量边框递推KKT方向等价验证报告"; ...
    "56条日级水量不等式";"18948";"16×16";"SB-EQ-001"; ...
    "SB-PHY-001";"READY_FOR_REVIEW";"未执行";"Stage C1"];
for token=required
    if ~contains(visible,token), errors(end+1)="missing visible token: "+token; end %#ok<AGROW>
end
if contains(visible,["stage_A4","Stage A4","STAGE A4","stage_B_2A"])
    errors(end+1)="stale stage identity in report";
end
if ~isempty(regexp(visible,"(?i)\b(TBD|TODO|PLACEHOLDER)\b","once"))
    errors(end+1)="placeholder token in report";
end
xml=string(packageDetails.document_xml);
tableCount=numel(regexp(xml,"<w:tbl>","match"));
headerCount=numel(regexp(xml,"<w:tblHeader/>","match"));
if tableCount<4 || headerCount<3
    errors(end+1)="table geometry/header gate failed";
end
passed=isempty(errors); details=make_details(errors,pathValue);
details.package=packageDetails;
end

function details=make_details(errors,pathValue)
details=struct("message","PASS","errors",errors,"report_path",string(pathValue));
if ~isempty(errors), details.message=strjoin(errors," | "); end
end
