function reportPath = generate_stage_a2_failure_report( ...
        runContext,exception,issues,acceptance)
%GENERATE_STAGE_A2_FAILURE_REPORT Preserve a minimal catch-path A2 report.
% The report is intentionally independent of numerical A2 artifacts. Its
% only run-specific facts come from run_manifest.json, the supplied issue
% and acceptance tables, and the caught MException. It never asserts PASS.

if ~isstruct(runContext) || ~isscalar(runContext) || ...
        ~isfield(runContext,'root')
    error('stageA2:failureReport:InvalidRunContext', ...
        'runContext.root is required.');
end
if ~isa(exception,'MException')
    error('stageA2:failureReport:InvalidException', ...
        'exception must be an MException captured from the failed run.');
end
if ~istable(issues) || ~istable(acceptance)
    error('stageA2:failureReport:InvalidEvidence', ...
        'issues and acceptance must be persisted-evidence tables.');
end

runRoot = char(java.io.File(char(string(runContext.root))).getCanonicalPath());
if ~isfolder(runRoot)
    error('stageA2:failureReport:MissingRunRoot', ...
        'Run root does not exist: %s',runRoot);
end
manifestPath = fullfile(runRoot,'run_manifest.json');
if ~isfile(manifestPath)
    error('stageA2:failureReport:MissingManifest', ...
        'run_manifest.json is required for a failure report.');
end
try
    manifest = jsondecode(fileread(manifestPath));
catch readException
    error('stageA2:failureReport:InvalidManifest', ...
        'Could not decode run_manifest.json: %s',readException.message);
end
runId = required_manifest_text(manifest,'run_id');
stageId = required_manifest_text(manifest,'stage_id');
manifestStatus = required_manifest_text(manifest,'status');
gitCommit = manifest_text(manifest,'git_commit');

reportsDirectory = fullfile(runRoot,'reports');
ensure_directory(reportsDirectory);
reportPath = fullfile(reportsDirectory,'阶段A2_失败与首层定位报告.docx');
if isfile(reportPath) || isfolder(reportPath)
    error('stageA2:failureReport:ArtifactExists', ...
        'Refusing to overwrite an existing failure report: %s',reportPath);
end

bodyXml = build_failure_body(runId,stageId,manifestStatus,gitCommit, ...
    exception,issues,acceptance);
stagingDirectory = tempname;
mkdir(stagingDirectory);
stagingCleanup = onCleanup(@() remove_temp_tree(stagingDirectory));
stagedPath = fullfile(stagingDirectory,'阶段A2_失败与首层定位报告.docx');
write_failure_docx(stagedPath,runId,bodyXml);
[valid,validation] = rkkt.reporting.validate_docx_package(stagedPath);
if ~valid
    error('stageA2:failureReport:InvalidDocxPackage', ...
        'Failure DOCX did not pass structural validation: %s', ...
        strjoin(string(validation.errors),'; '));
end
if isfile(reportPath) || isfolder(reportPath)
    error('stageA2:failureReport:ArtifactExists', ...
        'Refusing to overwrite an existing failure report: %s',reportPath);
end
[moved,message] = movefile(stagedPath,reportPath);
if ~moved
    error('stageA2:failureReport:PublishFailed', ...
        'Could not publish the failure report: %s',message);
end
clear stagingCleanup;
end

function body = build_failure_body(runId,stageId,manifestStatus,gitCommit, ...
        exception,issues,acceptance)
parts = strings(0,1);
parts(end+1) = paragraph_xml('STAGE A2 · 失败证据备忘','Kicker');
parts(end+1) = paragraph_xml('阶段A2 失败与首层定位报告','Title');
parts(end+1) = paragraph_xml( ...
    'catch 路径最小闭环；不补写未生成的数值工件','Subtitle');

parts(end+1) = heading_xml('一、运行身份');
identityRows = [ ...
    "运行标识",runId; ...
    "阶段",stageId; ...
    "manifest 当前状态",manifestStatus; ...
    "Git 提交",gitCommit];
parts(end+1) = table_xml(["字段","真实记录"],identityRows,[2800,6560]);

parts(end+1) = heading_xml('二、原始异常');
exceptionRows = exception_rows(exception);
parts(end+1) = table_xml(["异常字段","真实记录"], ...
    exceptionRows,[2800,6560]);

parts(end+1) = heading_xml('三、首个已记录失败层级');
if height(issues) == 0
    parts(end+1) = paragraph_xml( ...
        '调用方提供的 issue_log 表无数据行；本报告仅保留上方原始异常。', ...
        'Normal');
else
    issueColumns = existing_columns(issues,{ ...
        'issue_id','test_id','elimination_layer','variable_or_equation', ...
        'status','error_message','evidence_path'});
    firstIssue = issues(1,:);
    issueRows = strings(numel(issueColumns),2);
    for index = 1:numel(issueColumns)
        issueRows(index,:) = [display_header(issueColumns(index)), ...
            display_text(firstIssue.(issueColumns(index))(1))];
    end
    parts(end+1) = table_xml(["定位字段","真实记录"], ...
        issueRows,[2800,6560]);
end

parts(end+1) = heading_xml('四、调用方提供的验收状态');
if height(acceptance) == 0
    parts(end+1) = paragraph_xml( ...
        '调用方提供的 acceptance 表无数据行；没有数值验收结果可列示。', ...
        'Normal');
else
    acceptanceColumns = existing_columns(acceptance,{ ...
        'test_id','status','actual_value','evidence_path'});
    if isempty(acceptanceColumns)
        parts(end+1) = paragraph_xml( ...
            'acceptance 表不含可识别的验收字段。','Normal');
    else
        rows = table_rows(acceptance,acceptanceColumns);
        headers = strings(1,numel(acceptanceColumns));
        for index = 1:numel(acceptanceColumns)
            headers(index) = display_header(acceptanceColumns(index));
        end
        parts(end+1) = table_xml(headers,rows, ...
            equal_widths(numel(headers)));
    end
end

parts(end+1) = heading_xml('五、结论边界');
parts(end+1) = paragraph_xml([ ...
    '本报告只证明 catch 路径已保存当时可获得的失败事实，不宣告 Stage A2 ' ...
    '通过，也不推断未运行的矩阵维数、方向误差或残差。未执行完整 IPM、优化、' ...
    '并行、容量规划、物理调度或经济性解释；正式 24 小时模型口径未改变。'],'Normal');
body = strjoin(parts,newline);
end

function rows = exception_rows(exception)
rows = [ ...
    "identifier",display_text(exception.identifier); ...
    "message",display_text(exception.message); ...
    "cause_count",string(numel(exception.cause))];
if isempty(exception.stack)
    rows(end+1,:) = ["first_stack_frame","无堆栈帧"];
else
    frame = exception.stack(1);
    rows(end+1,:) = ["first_stack_frame", ...
        string(frame.name)+" | "+string(frame.file)+" | line "+ ...
        string(frame.line)];
end
end

function columns = existing_columns(tableValue,candidates)
actual = string(tableValue.Properties.VariableNames);
columns = strings(0,1);
for candidate = string(candidates)
    match = actual(strcmpi(actual,candidate));
    if ~isempty(match)
        columns(end+1) = match(1); %#ok<AGROW>
    end
end
end

function rows = table_rows(tableValue,columns)
rows = strings(height(tableValue),numel(columns));
for column = 1:numel(columns)
    values = tableValue.(columns(column));
    for row = 1:height(tableValue)
        if iscell(values)
            rows(row,column) = display_text(values{row});
        else
            rows(row,column) = display_text(values(row));
        end
    end
end
end

function textValue = display_header(name)
switch lower(string(name))
    case 'issue_id', textValue = '问题编号';
    case 'test_id', textValue = '验收项';
    case 'elimination_layer', textValue = '首个失败层级';
    case 'variable_or_equation', textValue = '变量或方程';
    case 'status', textValue = '状态';
    case 'error_message', textValue = '错误信息';
    case 'actual_value', textValue = '实际记录';
    case 'evidence_path', textValue = '证据路径';
    otherwise, textValue = string(name);
end
end

function textValue = required_manifest_text(manifest,fieldName)
textValue = manifest_text(manifest,fieldName);
if strlength(textValue) == 0
    error('stageA2:failureReport:MissingManifestField', ...
        'run_manifest.json field %s is required.',fieldName);
end
end

function textValue = manifest_text(manifest,fieldName)
if isfield(manifest,fieldName)
    textValue = display_text(manifest.(fieldName));
else
    textValue = "";
end
end

function textValue = display_text(value)
if isstring(value)
    if isempty(value), textValue = ""; else, textValue = strjoin(value(:)',', '); end
elseif ischar(value)
    textValue = string(value);
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        if isnumeric(value) && isfinite(double(value))
            textValue = string(sprintf('%.17g',double(value)));
        else
            textValue = string(value);
        end
    else
        textValue = string(jsonencode(value));
    end
elseif isempty(value)
    textValue = "";
else
    try
        textValue = string(jsonencode(value));
    catch
        textValue = "（无法显示的结构化值）";
    end
end
if ismissing(textValue), textValue = ""; end
textValue = regexprep(textValue,'\s+',' ');
if strlength(textValue) > 500
    textValue = extractBefore(textValue,481)+"…（详见原始工件）";
end
end

function widths = equal_widths(columnCount)
widths = repmat(floor(9360/columnCount),1,columnCount);
widths(end) = widths(end)+9360-sum(widths);
end

function xml = heading_xml(textValue)
xml = paragraph_xml(textValue,'Heading1','keepNext',true);
end

function xml = table_xml(headers,rows,widths)
headers = string(headers(:)');
rows = string(rows);
if isempty(rows), rows = strings(0,numel(headers)); end
if size(rows,2) ~= numel(headers) || numel(widths) ~= numel(headers) || ...
        sum(widths) ~= 9360
    error('stageA2:failureReport:TableGeometry', ...
        'Failure-report table geometry is invalid.');
end
grid = strings(1,numel(widths));
for index = 1:numel(widths)
    grid(index) = sprintf('<w:gridCol w:w="%d"/>',widths(index));
end
properties = [ ...
    '<w:tblPr><w:tblW w:w="9360" w:type="dxa"/>' ...
    '<w:tblInd w:w="120" w:type="dxa"/><w:tblLayout w:type="fixed"/>' ...
    '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '<w:left w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '<w:bottom w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '<w:right w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '<w:insideH w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '<w:insideV w:val="single" w:sz="4" w:color="D9DEE5"/>' ...
    '</w:tblBorders><w:tblCellMar><w:top w:w="80" w:type="dxa"/>' ...
    '<w:start w:w="120" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/>' ...
    '<w:end w:w="120" w:type="dxa"/></w:tblCellMar></w:tblPr>'];
xml = "<w:tbl>"+string(properties)+"<w:tblGrid>"+ ...
    strjoin(grid,'')+"</w:tblGrid>"+table_row_xml(headers,widths,true);
for row = 1:size(rows,1)
    xml = xml+table_row_xml(rows(row,:),widths,false);
end
xml = xml+"</w:tbl>"+paragraph_xml('','Spacer');
end

function xml = table_row_xml(values,widths,isHeader)
if isHeader
    rowProperties = '<w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>';
    styleName = 'TableHeader';
    shading = '<w:shd w:val="clear" w:fill="F2F4F7"/>';
else
    rowProperties = '<w:trPr><w:cantSplit/></w:trPr>';
    styleName = 'TableText';
    shading = '';
end
xml = "<w:tr>"+string(rowProperties);
for column = 1:numel(widths)
    xml = xml+sprintf([ ...
        '<w:tc><w:tcPr><w:tcW w:w="%d" w:type="dxa"/>%s' ...
        '<w:vAlign w:val="center"/></w:tcPr>'],widths(column),shading)+ ...
        paragraph_xml(values(column),styleName,'keepNext',isHeader)+"</w:tc>";
end
xml = xml+"</w:tr>";
end

function xml = paragraph_xml(textValue,styleName,varargin)
parser = inputParser;
addParameter(parser,'keepNext',false,@(x) islogical(x) && isscalar(x));
parse(parser,varargin{:});
properties = "<w:pPr><w:pStyle w:val="""+xml_escape(styleName)+"""/>";
if parser.Results.keepNext, properties = properties+"<w:keepNext/>"; end
properties = properties+"</w:pPr>";
xml = "<w:p>"+properties+"<w:r><w:t xml:space=""preserve"">"+ ...
    xml_escape(textValue)+"</w:t></w:r></w:p>";
end

function write_failure_docx(outputPath,runId,bodyXml)
packageRoot = tempname;
mkdir(packageRoot);
cleanup = onCleanup(@() remove_temp_tree(packageRoot));
mkdir(fullfile(packageRoot,'_rels'));
mkdir(fullfile(packageRoot,'docProps'));
mkdir(fullfile(packageRoot,'word'));
mkdir(fullfile(packageRoot,'word','_rels'));

write_utf8(fullfile(packageRoot,'[Content_Types].xml'),content_types_xml());
write_utf8(fullfile(packageRoot,'_rels','.rels'),root_relationships_xml());
write_utf8(fullfile(packageRoot,'docProps','core.xml'),core_properties_xml());
write_utf8(fullfile(packageRoot,'docProps','app.xml'),app_properties_xml());
write_utf8(fullfile(packageRoot,'word','styles.xml'),styles_xml());
write_utf8(fullfile(packageRoot,'word','settings.xml'),settings_xml());
write_utf8(fullfile(packageRoot,'word','header1.xml'),header_xml(runId));
write_utf8(fullfile(packageRoot,'word','footer1.xml'),footer_xml(runId));
write_utf8(fullfile(packageRoot,'word','_rels','document.xml.rels'), ...
    document_relationships_xml());
write_utf8(fullfile(packageRoot,'word','document.xml'),document_xml(bodyXml));

packageFiles = {'[Content_Types].xml',fullfile('_rels','.rels'), ...
    fullfile('docProps','core.xml'),fullfile('docProps','app.xml'), ...
    fullfile('word','document.xml'),fullfile('word','styles.xml'), ...
    fullfile('word','settings.xml'),fullfile('word','header1.xml'), ...
    fullfile('word','footer1.xml'), ...
    fullfile('word','_rels','document.xml.rels')};
zipPath = [tempname(fileparts(outputPath)),'.zip'];
zipCleanup = onCleanup(@() delete_if_exists(zipPath));
zip(zipPath,packageFiles,packageRoot);
[moved,message] = movefile(zipPath,outputPath);
if ~moved
    error('stageA2:failureReport:PackageWriteFailed', ...
        'Could not finalize DOCX package: %s',message);
end
clear zipCleanup cleanup;
end

function xml = document_xml(bodyXml)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:document xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"" "+ ...
    "xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships"">"+ ...
    "<w:body>"+bodyXml+ ...
    "<w:sectPr><w:headerReference w:type=""default"" r:id=""rId3""/>"+ ...
    "<w:footerReference w:type=""default"" r:id=""rId4""/>"+ ...
    "<w:pgSz w:w=""12240"" w:h=""15840""/>"+ ...
    "<w:pgMar w:top=""1440"" w:right=""1440"" w:bottom=""1440"" "+ ...
    "w:left=""1440"" w:header=""708"" w:footer=""708"" w:gutter=""0""/>"+ ...
    "</w:sectPr></w:body></w:document>";
end

function xml = styles_xml()
xml = string([ ...
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:docDefaults><w:rPrDefault><w:rPr>' ...
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>' ...
    '<w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>' ...
    style_xml('Normal','Normal',22,'000000',false,0,120) ...
    style_xml('Kicker','Kicker',19,'2E74B5',true,0,60) ...
    style_xml('Title','Title',42,'000000',true,0,80) ...
    style_xml('Subtitle','Subtitle',26,'555555',false,0,220) ...
    style_xml('Heading1','Heading 1',30,'2E74B5',true,280,140) ...
    style_xml('TableHeader','Table Header',19,'0B2545',true,0,0) ...
    style_xml('TableText','Table Text',19,'000000',false,0,0) ...
    style_xml('Spacer','Spacer',4,'FFFFFF',false,0,80) ...
    style_xml('Header','Header',18,'666666',false,0,0) ...
    style_xml('Footer','Footer',18,'777777',false,0,0) ...
    '</w:styles>']);
end

function xml = style_xml(id,name,sizeValue,color,bold,before,after)
if bold, boldXml = '<w:b/><w:bCs/>'; else, boldXml = ''; end
xml = sprintf([ ...
    '<w:style w:type="paragraph" w:styleId="%s"><w:name w:val="%s"/>' ...
    '<w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="%d" ' ...
    'w:after="%d" w:line="264" w:lineRule="auto"/></w:pPr><w:rPr>' ...
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>' ...
    '%s<w:color w:val="%s"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>' ...
    '</w:rPr></w:style>'],id,name,before,after,boldXml,color,sizeValue,sizeValue);
end

function xml = header_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:hdr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">"+ ...
    paragraph_xml("STAGE A2 · 失败闭环 | 运行 "+runId,'Header')+"</w:hdr>";
end

function xml = footer_xml(runId)
xml = "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>"+ ...
    "<w:ftr xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main"">"+ ...
    paragraph_xml("运行 "+runId+" | 失败证据",'Footer')+"</w:ftr>";
end

function xml = settings_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' ...
    '<w:zoom w:percent="100"/><w:defaultTabStop w:val="720"/></w:settings>'];
end

function xml = content_types_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' ...
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' ...
    '<Default Extension="xml" ContentType="application/xml"/>' ...
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' ...
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>' ...
    '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>' ...
    '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>' ...
    '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>' ...
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>' ...
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>' ...
    '</Types>'];
end

function xml = root_relationships_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' ...
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' ...
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>' ...
    '</Relationships>'];
end

function xml = document_relationships_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' ...
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' ...
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>' ...
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>' ...
    '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>' ...
    '</Relationships>'];
end

function xml = core_properties_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ' ...
    'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>阶段A2 失败与首层定位报告</dc:title>' ...
    '<dc:creator>MATLAB stage_A2 reporting</dc:creator></cp:coreProperties>'];
end

function xml = app_properties_xml()
xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' ...
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ' ...
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' ...
    '<Application>MATLAB stage_A2 reporting</Application></Properties>'];
end

function write_utf8(pathValue,content)
[fileId,message] = fopen(pathValue,'wb','n','UTF-8');
if fileId < 0
    error('stageA2:failureReport:WriteFailed', ...
        'Could not open %s: %s',pathValue,message);
end
cleanup = onCleanup(@() close_file(fileId));
bytes = unicode2native(char(content),'UTF-8');
written = fwrite(fileId,bytes,'uint8');
if written ~= numel(bytes)
    error('stageA2:failureReport:WriteFailed','Short write for %s.',pathValue);
end
status = fclose(fileId);
clear cleanup;
if status ~= 0
    error('stageA2:failureReport:WriteFailed','Could not close %s.',pathValue);
end
end

function close_file(fileId)
try
    if ischar(fopen(fileId)), fclose(fileId); end
catch
end
end

function value = xml_escape(value)
value = char(display_text(value));
invalid = double(value)<32 & ~ismember(double(value),[9,10,13]);
value(invalid) = [];
value = strrep(value,'&','&amp;');
value = strrep(value,'<','&lt;');
value = strrep(value,'>','&gt;');
value = strrep(value,'"','&quot;');
value = strrep(value,'''','&apos;');
value = string(value);
end

function ensure_directory(pathValue)
if isfolder(pathValue), return; end
if isfile(pathValue)
    error('stageA2:failureReport:PathConflict', ...
        'A file exists where reports/ is required: %s',pathValue);
end
[created,message] = mkdir(pathValue);
if ~created
    error('stageA2:failureReport:CreateDirectoryFailed','%s',message);
end
end

function delete_if_exists(pathValue)
if isfile(pathValue), delete(pathValue); end
end

function remove_temp_tree(pathValue)
if isfolder(pathValue), rmdir(pathValue,'s'); end
end
