function audit = render_stage_a4_reports_with_word(reportPaths,outputDirectory)
%RENDER_STAGE_A4_REPORTS_WITH_WORD Render the three reports to PDF.

arguments
    reportPaths (1,1) struct
    outputDirectory (1,1) string
end

keys = ["model_report","issue_report","run_summary"];
assert(all(isfield(reportPaths,keys)),"rkkt:reporting:ReportSet", ...
    "The three formal A4 reports are required.");
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
    "rkkt:reporting:RenderOutputExists", ...
    "The report render directory already exists: %s",outputDirectory);
[created,message] = mkdir(outputDirectory);
assert(created,"rkkt:reporting:RenderDirectory","%s",message);

word = actxserver("Word.Application");
word.Visible = false;
word.DisplayAlerts = 0;
wordGuard = onCleanup(@()invoke(word,"Quit"));

report_key = strings(numel(keys),1);
report_path = strings(numel(keys),1);
pdf_path = strings(numel(keys),1);
page_count = zeros(numel(keys),1);
docx_sha256 = strings(numel(keys),1);
pdf_sha256 = strings(numel(keys),1);
status = repmat("PASS",numel(keys),1);
for k = 1:numel(keys)
    key = keys(k);
    docxPath = string(reportPaths.(key));
    assert(isfile(docxPath),"rkkt:reporting:ReportMissing", ...
        "A formal report is missing: %s",docxPath);
    pdfPath = fullfile(outputDirectory,key+".pdf");
    document = invoke(word.Documents,"Open",char(docxPath),false,true);
    documentGuard = onCleanup(@()invoke(document,"Close",false));
    pages = double(invoke(document,"ComputeStatistics",2));
    assert(pages>=1 && pages==fix(pages), ...
        "rkkt:reporting:ReportPageCount", ...
        "Word returned an invalid page count for %s.",docxPath);
    invoke(document,"ExportAsFixedFormat",char(pdfPath),17);
    clear documentGuard
    information = dir(pdfPath);
    assert(isfile(pdfPath) && information.bytes>0, ...
        "rkkt:reporting:PdfRender", ...
        "Word did not create a nonempty PDF for %s.",docxPath);

    report_key(k) = key;
    report_path(k) = docxPath;
    pdf_path(k) = string(pdfPath);
    page_count(k) = pages;
    docx_sha256(k) = rkkt.data.compute_sha256_file(docxPath);
    pdf_sha256(k) = rkkt.data.compute_sha256_file(pdfPath);
end
clear wordGuard

audit = table(report_key,report_path,pdf_path,page_count, ...
    docx_sha256,pdf_sha256,status);
end
