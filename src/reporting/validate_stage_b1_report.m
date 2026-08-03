function [passed,details] = validate_stage_b1_report(runRoot)
%VALIDATE_STAGE_B1_REPORT Validate B-1 structure, identity, and semantics.

arguments
    runRoot (1,1) string
end
runRoot = string(java.io.File(char(runRoot)).getCanonicalPath());
reportPath = fullfile(runRoot,"reports", ...
    "阶段B-1_水量数据与导数基线报告.docx");
[packagePassed,packageDetails] = validate_docx_package(reportPath);
errors = string(packageDetails.errors(:));

manifestPath = fullfile(runRoot,"run_manifest.json");
waterPath = fullfile(runRoot,"diagnostics","water_input_audit.csv");
derivativePath = fullfile(runRoot,"diagnostics","derivative_check.csv");
acceptancePath = fullfile(runRoot,"acceptance","acceptance_results.csv");
requiredPaths = [manifestPath,waterPath,derivativePath,acceptancePath];
for k = 1:numel(requiredPaths)
    if ~isfile(requiredPaths(k))
        errors(end+1,1) = "Missing validation source: "+requiredPaths(k); %#ok<AGROW>
    end
end
if ~packagePassed || any(~isfile(requiredPaths))
    details = finish_details(errors,packageDetails,reportPath);
    passed = false;
    return
end

manifest = jsondecode(fileread(manifestPath));
water = read_csv(waterPath);
derivatives = read_csv(derivativePath);
acceptance = read_csv(acceptancePath);
visible = string(packageDetails.document_text);
requiredText = [ ...
    "阶段B-1：水量数据与解析导数基线报告"; ...
    string(manifest.run_id); ...
    "第14—20日"; ...
    "28条"; ...
    "W(d,u)=sum"; ...
    "gradient_W=2aP+b"; ...
    "Hessian_W=2a·I_24"; ...
    "SB-DATA-001"; ...
    "SB-DER-001"; ...
    "SB-EQ-001"; ...
    "SB-PHY-001"; ...
    "NOT_RUN"; ...
    "Stage B整体通过"; ...
    "未装配完整KKT"; ...
    "未建立递推日响应"; ...
    "未运行IPM"; ...
    "未验证最终物理水量可行性"; ...
    "Stage C1"];
for k = 1:numel(requiredText)
    if ~contains(visible,requiredText(k))
        errors(end+1,1) = "Missing visible B-1 text: "+requiredText(k); %#ok<AGROW>
    end
end
if contains(visible,["STAGE A4","Stage A4","stage_A4"])
    errors(end+1,1) = "Visible report contains stale Stage A4 identity.";
end
if ~isempty(regexp(visible,"(?i)\b(TBD|TODO|PLACEHOLDER)\b","once"))
    errors(end+1,1) = "Visible report contains a placeholder token.";
end

if height(water)~=28 || any(string(water.status)~="PASS")
    errors(end+1,1) = "Water evidence is not exactly 28 passing rows.";
else
    for row = 1:height(water)
        requiredNumbers = [compose("%.2f",water.water_min_m3(row)), ...
            compose("%.2f",water.water_max_m3(row))];
        if any(~contains(visible,requiredNumbers))
            errors(end+1,1) = compose( ...
                "Report omits a persisted water-bound value at row %d.",row); %#ok<AGROW>
            break
        end
    end
    for hydro = 1:4
        row = find(water.hydro_id==hydro,1,"first");
        requiredNumbers = [concise_text(water.water_a(row)), ...
            concise_text(water.water_b(row)), ...
            concise_text(water.water_c(row))];
        if any(~contains(visible,requiredNumbers))
            errors(end+1,1) = compose( ...
                "Report omits persisted coefficients for hydro %d.",hydro); %#ok<AGROW>
        end
    end
end

if height(derivatives)~=112 || any(string(derivatives.status)~="PASS")
    errors(end+1,1) = "Derivative evidence is not 112 passing samples.";
else
    requiredErrors = [compose("%.8e", ...
        max(derivatives.gradient_relative_error)), ...
        compose("%.8e",max(derivatives.hessian_relative_error))];
    if any(~contains(visible,requiredErrors))
        errors(end+1,1) = ...
            "Report does not contain both persisted maximum derivative errors.";
    end
end
if height(acceptance)~=4 || ...
        ~isequal(string(acceptance.test_id), ...
        ["SB-DATA-001";"SB-DER-001";"SB-EQ-001";"SB-PHY-001"]) || ...
        ~isequal(string(acceptance.status), ...
        ["PASS";"PASS";"NOT_RUN";"NOT_RUN"])
    errors(end+1,1) = "Acceptance identity/status is not B-1 exact.";
end

allXml = package_xml_text(reportPath);
if contains(allXml,["stage_A4","Stage A4","STAGE A4"])
    errors(end+1,1) = "OOXML package metadata contains stale Stage A4 identity.";
end
documentXml = string(packageDetails.document_xml);
tableCount = numel(regexp(documentXml,"<w:tbl>","match"));
headerCount = numel(regexp(documentXml,"<w:tblHeader/>","match"));
cantSplitCount = numel(regexp(documentXml,"<w:cantSplit/>","match"));
if tableCount<6 || headerCount<5 || cantSplitCount<headerCount
    errors(end+1,1) = ...
        "Report tables do not satisfy repeated-header/cantSplit layout gates.";
end

details = finish_details(errors,packageDetails,reportPath);
passed = isempty(errors);
end

function value = read_csv(pathValue)
options = detectImportOptions(pathValue,"Delimiter",",", ...
    "TextType","string","VariableNamingRule","preserve");
value = readtable(pathValue,options);
end

function value = concise_text(number)
value = compose("%.6g",double(number));
end

function textValue = package_xml_text(docxPath)
root = string(tempname(tempdir));
mkdir(root);
guard = onCleanup(@()remove_tree(root));
unzip(docxPath,root);
files = [dir(fullfile(root,"**","*.xml")); ...
    dir(fullfile(root,"**","*.rels"))];
textValue = "";
for k = 1:numel(files)
    textValue = textValue+newline+ ...
        string(fileread(fullfile(files(k).folder,files(k).name)));
end
clear guard
end

function details = finish_details(errors,packageDetails,reportPath)
details = struct();
details.message = "PASS";
if ~isempty(errors)
    details.message = strjoin(errors," | ");
end
details.errors = errors;
details.package = packageDetails;
details.report_path = string(reportPath);
end

function remove_tree(pathValue)
try
    if isfolder(pathValue)
        rmdir(pathValue,"s");
    end
catch
end
end
