function audit = render_stage_b2c_report_external(runRoot,reportPath)
%RENDER_STAGE_B2C_REPORT_EXTERNAL Render DOCX pages when tools are supplied.
%
% The caller supplies the bundled Python and renderer through environment
% variables.  Absence is recorded truthfully and never fabricated as PASS.

arguments
    runRoot (1,1) string
    reportPath (1,1) string
end
python = string(getenv("B2C_DOCX_RENDERER_PYTHON"));
renderer = string(getenv("B2C_DOCX_RENDERER_SCRIPT"));
outputDir = fullfile(runRoot,"reports","rendered_pages");
if ~isfolder(outputDir), mkdir(outputDir); end
available = strlength(strip(python))>0 && isfile(python) && ...
    strlength(strip(renderer))>0 && isfile(renderer);
exitCode = NaN; output = "renderer environment not supplied";
if available
    command='"'+python+'" "'+renderer+'" "'+reportPath+ ...
        '" --output_dir "'+outputDir+'" --emit_pdf';
    [exitCode,output] = system(command);
end
pages = dir(fullfile(outputDir,"page-*.png"));
[~,stem]=fileparts(reportPath);
pdfPath=fullfile(outputDir,stem+".pdf");
rendered = available && exitCode==0 && ~isempty(pages) && isfile(pdfPath);
status="NOT_RUN_EXTERNAL_GATE";
engineMissing = available && exitCode~=0 && ...
    (contains(string(output),"FileNotFoundError") || ...
    contains(string(output),"WinError 2") || ...
    contains(lower(string(output)),"soffice"));
engineAvailable = available && ~engineMissing;
if rendered
    status="PASS";
elseif engineMissing
    status="NOT_RUN_LIBREOFFICE_UNAVAILABLE";
elseif available
    status="FAIL";
end
audit = table("DOCX_PAGE_RENDER",available,engineAvailable,exitCode,numel(pages), ...
    isfile(pdfPath),string(outputDir),string(output),status, ...
    'VariableNames',{'check_id','renderer_wrapper_available', ...
    'render_engine_available','exit_code','page_png_count','pdf_exists', ...
    'output_directory','details','status'});
end
