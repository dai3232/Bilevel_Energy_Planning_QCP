function [passed,audit] = validate_stage_a4_report_set(reportPaths,runId)
%VALIDATE_STAGE_A4_REPORT_SET Validate the three required A4 DOCX packages.
%
% This is a deterministic OOXML/package gate.  It intentionally does not
% claim rendered visual QA; DOCX-to-page-image rendering remains a separate
% external gate.

arguments
    reportPaths (1,1) struct
    runId (1,1) string
end
required = ["model_report","issue_report","run_summary"];
assert(all(isfield(reportPaths,cellstr(required)))&& ...
    numel(fieldnames(reportPaths))==numel(required), ...
    "stageA4:report:ReportSetSchema", ...
    "Exactly model_report, issue_report, and run_summary are required.");

n = numel(required);
report_key = required.';
path = strings(n,1);
relative_name = strings(n,1);
package_valid = false(n,1);
has_run_id = false(n,1);
has_a4_identity = false(n,1);
all_table_rows_cant_split = false(n,1);
placeholder_free = false(n,1);
sha256 = strings(n,1);
error_text = strings(n,1);
visual_qa_status = repmat("NOT_RUN_EXTERNAL_GATE",n,1);
status = strings(n,1);

for k = 1:n
    pathValue = string(reportPaths.(required(k)));
    path(k) = string(char(java.io.File(char(pathValue)).getCanonicalPath()));
    [~,name,extension] = fileparts(pathValue);
    relative_name(k) = string(name)+string(extension);
    [package_valid(k),details] = validate_docx_package(pathValue);
    textValue = string(details.document_text);
    xml = string(details.document_xml);
    has_run_id(k) = contains(textValue,runId);
    has_a4_identity(k) = contains(textValue,"Stage A4", ...
        'IgnoreCase',true)||contains(textValue,"阶段A4")|| ...
        contains(textValue,"STAGE A4");
    tableRows = regexp(char(xml),'(?s)<w:tr>.*?</w:tr>','match');
    all_table_rows_cant_split(k) = ~isempty(tableRows)&& ...
        all(cellfun(@(value)contains(value,'<w:cantSplit/>'),tableRows));
    placeholder_free(k) = ~any(contains(textValue, ...
        ["{{","}}","TODO","TBD","待填写","手工填入"], ...
        'IgnoreCase',true));
    if isfile(pathValue)
        sha256(k) = compute_sha256_file(pathValue);
    end
    error_text(k) = strjoin(string(details.errors),"; ");
    rowPassed = package_valid(k)&&has_run_id(k)&&has_a4_identity(k)&& ...
        all_table_rows_cant_split(k)&&placeholder_free(k)&& ...
        strlength(sha256(k))==64;
    if rowPassed, status(k)="PASS"; else, status(k)="FAIL"; end
end
audit = table(report_key,path,relative_name,package_valid,has_run_id, ...
    has_a4_identity,all_table_rows_cant_split,placeholder_free,sha256, ...
    error_text,visual_qa_status,status);
passed = all(status=="PASS");
end
