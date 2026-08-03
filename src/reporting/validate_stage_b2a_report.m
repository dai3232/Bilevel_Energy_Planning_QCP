function [passed,details] = validate_stage_b2a_report(runRoot)
%VALIDATE_STAGE_B2A_REPORT Validate OOXML and persisted semantic content.

arguments
    runRoot (1,1) string
end
runRoot = string(java.io.File(char(runRoot)).getCanonicalPath());
reportPath = fullfile(runRoot,"reports", ...
    "阶段B-2A_水量约束线性化与完整KKT结构报告.docx");
errors = strings(0,1);
if ~isfile(reportPath)
    errors(end+1) = "missing report";
    passed = false; details = make_details(errors,reportPath); return
end
[packagePassed,packageDetails] = validate_docx_package(reportPath);
if ~packagePassed
    errors = [errors;string(packageDetails.errors(:))];
end
visible = string(packageDetails.document_text);
requiredText = ["阶段B-2A：水量约束线性化与完整KKT结构报告"; ...
    "56条日级水量不等式";"18948";"54664"; ...
    "G*x+offset";"Lagrangian Hessian";"仅装配"; ...
    "未运行IPM";"SB-EQ-001";"SB-PHY-001";"NOT_RUN"; ...
    "Stage C1"];
for token = requiredText
    if ~contains(visible,token)
        errors(end+1) = "missing visible token: "+token; %#ok<AGROW>
    end
end
if contains(visible,["stage_A4","Stage A4","STAGE A4"])
    errors(end+1) = "stale Stage A4 identity in report";
end
if ~isempty(regexp(visible,"(?i)\b(TBD|TODO|PLACEHOLDER)\b","once"))
    errors(end+1) = "placeholder token in report";
end
documentXml = string(packageDetails.document_xml);
tableCount = numel(regexp(documentXml,"<w:tbl>","match"));
headerCount = numel(regexp(documentXml,"<w:tblHeader/>","match"));
cantSplitCount = numel(regexp(documentXml,"<w:cantSplit/>","match"));
if tableCount<5 || headerCount<4 || cantSplitCount<headerCount
    errors(end+1) = "table header/repeat geometry gate failed";
end
passed = isempty(errors);
details = make_details(errors,reportPath);
details.package = packageDetails;
end

function details = make_details(errors,pathValue)
details = struct("message","PASS","errors",errors,"report_path",string(pathValue));
if ~isempty(errors), details.message = strjoin(errors," | "); end
end
