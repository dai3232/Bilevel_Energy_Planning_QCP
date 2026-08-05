function [isValid, details] = validate_docx_package(docxPath)
%VALIDATE_DOCX_PACKAGE Perform deterministic structural checks on a DOCX.
%   [ISVALID, DETAILS] = VALIDATE_DOCX_PACKAGE(PATH) verifies the ZIP parts,
%   core relationships, fixed-width table markup, page geometry, and visible
%   document text. It does not replace render-based visual QA.

arguments
    docxPath {mustBeTextScalar}
end

docxPath = char(string(docxPath));
errors = strings(0, 1);
details = struct('errors', errors, 'entries', strings(0, 1), ...
    'document_text', "", 'document_xml', "", 'styles_xml', "");

if ~isfile(docxPath)
    details.errors = "DOCX file does not exist.";
    isValid = false;
    return;
end

extractRoot = tempname;
mkdir(extractRoot);
cleanup = onCleanup(@() remove_extract_tree(extractRoot)); %#ok<NASGU>
try
    extracted = unzip(docxPath, extractRoot);
catch exception
    details.errors = "ZIP extraction failed: " + string(exception.message);
    isValid = false;
    return;
end

relativeEntries = strings(numel(extracted), 1);
for index = 1:numel(extracted)
    relativeEntries(index) = replace(erase(string(extracted{index}), ...
        string(extractRoot) + filesep), '\', '/');
end
details.entries = sort(relativeEntries);

requiredEntries = [ ...
    "[Content_Types].xml"; ...
    "_rels/.rels"; ...
    "word/document.xml"; ...
    "word/styles.xml"; ...
    "word/settings.xml"; ...
    "word/header1.xml"; ...
    "word/footer1.xml"; ...
    "word/_rels/document.xml.rels"; ...
    "docProps/core.xml"; ...
    "docProps/app.xml"];
for index = 1:numel(requiredEntries)
    if ~any(details.entries == requiredEntries(index))
        errors(end + 1) = "Missing package entry: " + requiredEntries(index); %#ok<AGROW>
    end
end

if isempty(errors)
    xmlEntries = requiredEntries(endsWith(requiredEntries, '.xml') | ...
        endsWith(requiredEntries, '.rels'));
    for index = 1:numel(xmlEntries)
        xmlPath = fullfile(extractRoot, ...
            strrep(char(xmlEntries(index)), '/', filesep));
        try
            xmlread(xmlPath);
        catch exception
            errors(end + 1) = "Malformed XML part " + xmlEntries(index) + ...
                ": " + string(exception.message); %#ok<AGROW>
        end
    end

    documentXml = string(fileread(fullfile(extractRoot, 'word', 'document.xml')));
    stylesXml = string(fileread(fullfile(extractRoot, 'word', 'styles.xml')));
    relationshipsXml = string(fileread(fullfile(extractRoot, 'word', ...
        '_rels', 'document.xml.rels')));
    rootRelationshipsXml = string(fileread(fullfile(extractRoot, ...
        '_rels', '.rels')));
    contentTypesXml = string(fileread(fullfile(extractRoot, '[Content_Types].xml')));
    details.document_xml = documentXml;
    details.styles_xml = stylesXml;

    checks = { ...
        contains(documentXml, '<w:document'), 'word/document.xml has no document root.'; ...
        contains(documentXml, '<w:sectPr>'), 'word/document.xml has no section properties.'; ...
        contains(documentXml, 'w:w="12240" w:h="15840"'), 'Letter page geometry is missing.'; ...
        contains(documentXml, 'w:top="1440" w:right="1440" w:bottom="1440"'), 'One-inch page margins are missing.'; ...
        contains(documentXml, '<w:tblLayout w:type="fixed"/>'), 'No fixed-layout table was found.'; ...
        contains(documentXml, '<w:tblW w:w="9360" w:type="dxa"/>'), '9360-DXA table geometry is missing.'; ...
        contains(stylesXml, 'w:eastAsia="Microsoft YaHei"'), 'Chinese font mapping is missing.'; ...
        contains(stylesXml, 'w:styleId="Heading1"'), 'Heading 1 style is missing.'; ...
        has_relationship(relationshipsXml, 'rId1', 'relationships/styles', 'styles.xml'), 'Styles relationship is invalid.'; ...
        has_relationship(relationshipsXml, 'rId2', 'relationships/settings', 'settings.xml'), 'Settings relationship is invalid.'; ...
        has_relationship(relationshipsXml, 'rId3', 'relationships/header', 'header1.xml'), 'Header relationship is invalid.'; ...
        has_relationship(relationshipsXml, 'rId4', 'relationships/footer', 'footer1.xml'), 'Footer relationship is invalid.'; ...
        contains(documentXml, 'w:headerReference w:type="default" r:id="rId3"'), 'Section header reference is invalid.'; ...
        contains(documentXml, 'w:footerReference w:type="default" r:id="rId4"'), 'Section footer reference is invalid.'; ...
        has_relationship(rootRelationshipsXml, 'rId1', 'relationships/officeDocument', 'word/document.xml'), 'Root document relationship is invalid.'; ...
        has_relationship(rootRelationshipsXml, 'rId2', 'metadata/core-properties', 'docProps/core.xml'), 'Core-properties relationship is invalid.'; ...
        has_relationship(rootRelationshipsXml, 'rId3', 'relationships/extended-properties', 'docProps/app.xml'), 'App-properties relationship is invalid.'; ...
        has_content_type(contentTypesXml, '/word/document.xml', 'wordprocessingml.document.main+xml'), 'Main document content type is invalid.'; ...
        has_content_type(contentTypesXml, '/word/styles.xml', 'wordprocessingml.styles+xml'), 'Styles content type is invalid.'; ...
        has_content_type(contentTypesXml, '/word/settings.xml', 'wordprocessingml.settings+xml'), 'Settings content type is invalid.'; ...
        has_content_type(contentTypesXml, '/word/header1.xml', 'wordprocessingml.header+xml'), 'Header content type is invalid.'; ...
        has_content_type(contentTypesXml, '/word/footer1.xml', 'wordprocessingml.footer+xml'), 'Footer content type is invalid.'; ...
        has_content_type(contentTypesXml, '/docProps/core.xml', 'core-properties+xml'), 'Core-properties content type is invalid.'; ...
        has_content_type(contentTypesXml, '/docProps/app.xml', 'extended-properties+xml'), 'App-properties content type is invalid.'};
    for index = 1:size(checks, 1)
        if ~checks{index, 1}
            errors(end + 1) = string(checks{index, 2}); %#ok<AGROW>
        end
    end

    geometryErrors = audit_table_geometry(documentXml);
    errors = [errors; geometryErrors(:)];
    errors = [errors; relationship_target_errors(rootRelationshipsXml, ...
        extractRoot, extractRoot); ...
        relationship_target_errors(relationshipsXml, ...
        fullfile(extractRoot, 'word'), extractRoot)];

    visibleText = regexprep(documentXml, '<w:tab[^>]*/>', sprintf('\t'));
    visibleText = regexprep(visibleText, '</w:p>', newline);
    visibleText = regexprep(visibleText, '<[^>]+>', ' ');
    visibleText = replace(visibleText, ...
        {'&lt;', '&gt;', '&quot;', '&apos;', '&amp;'}, ...
        {'<', '>', '"', '''', '&'});
    visibleText = regexprep(visibleText, '[ \t]+', ' ');
    details.document_text = strtrim(visibleText);
    if strlength(details.document_text) == 0
        errors(end + 1) = "The main document contains no visible text."; %#ok<AGROW>
    end
end

details.errors = errors;
isValid = isempty(errors);
end

function tf = has_relationship(xml, id, typeSuffix, target)
tags = regexp(char(xml), '<Relationship\s+[^>]*/>', 'match');
tf = false;
for index = 1:numel(tags)
    if contains(tags{index}, ['Id="' id '"']) && ...
            contains(tags{index}, ['Type="']) && ...
            contains(tags{index}, typeSuffix) && ...
            contains(tags{index}, ['Target="' target '"'])
        tf = true;
        return;
    end
end
end

function tf = has_content_type(xml, partName, typeSuffix)
tags = regexp(char(xml), '<Override\s+[^>]*/>', 'match');
tf = false;
for index = 1:numel(tags)
    if contains(tags{index}, ['PartName="' partName '"']) && ...
            contains(tags{index}, typeSuffix)
        tf = true;
        return;
    end
end
end

function errors = relationship_target_errors(xml, baseFolder, packageRoot)
errors = strings(0, 1);
tags = regexp(char(xml), '<Relationship\s+[^>]*/>', 'match');
for index = 1:numel(tags)
    if contains(tags{index}, 'TargetMode="External"')
        continue;
    end
    targetToken = regexp(tags{index}, 'Target="([^"]+)"', 'tokens', 'once');
    idToken = regexp(tags{index}, 'Id="([^"]+)"', 'tokens', 'once');
    if isempty(targetToken) || isempty(idToken)
        errors(end + 1) = "Malformed Relationship element."; %#ok<AGROW>
        continue;
    end
    target = strrep(targetToken{1}, '/', filesep);
    if startsWith(target, filesep)
        resolved = fullfile(packageRoot, target(2:end));
    else
        resolved = fullfile(baseFolder, target);
    end
    if ~isfile(resolved)
        errors(end + 1) = "Relationship " + string(idToken{1}) + ...
            " has a missing Target: " + string(targetToken{1}); %#ok<AGROW>
    end
end
end

function errors = audit_table_geometry(documentXml)
errors = strings(0, 1);
tables = regexp(char(documentXml), '(?s)<w:tbl>.*?</w:tbl>', 'match');
for tableIndex = 1:numel(tables)
    tableXml = tables{tableIndex};
    prefix = "Table " + string(tableIndex) + ": ";
    if ~contains(tableXml, '<w:tblW w:w="9360" w:type="dxa"/>')
        errors(end + 1) = prefix + "tblW is not 9360 DXA."; %#ok<AGROW>
    end
    if ~contains(tableXml, '<w:tblInd w:w="120" w:type="dxa"/>')
        errors(end + 1) = prefix + "tblInd is not 120 DXA."; %#ok<AGROW>
    end
    if ~contains(tableXml, '<w:tblLayout w:type="fixed"/>')
        errors(end + 1) = prefix + "layout is not fixed."; %#ok<AGROW>
    end

    gridTokens = regexp(tableXml, ...
        '<w:gridCol w:w="([0-9]+)"/>', 'tokens');
    gridWidths = token_numbers(gridTokens);
    if isempty(gridWidths) || sum(gridWidths) ~= 9360
        errors(end + 1) = prefix + "grid columns do not sum to 9360 DXA."; %#ok<AGROW>
        continue;
    end

    rowXml = regexp(tableXml, '(?s)<w:tr>.*?</w:tr>', 'match');
    for rowIndex = 1:numel(rowXml)
        cellTokens = regexp(rowXml{rowIndex}, ...
            '<w:tcW w:w="([0-9]+)" w:type="dxa"/>', 'tokens');
        cellWidths = token_numbers(cellTokens);
        if ~isequal(cellWidths, gridWidths)
            errors(end + 1) = prefix + "row " + string(rowIndex) + ...
                " cell widths do not match tblGrid."; %#ok<AGROW>
        end
    end
end
end

function values = token_numbers(tokens)
values = zeros(1, numel(tokens));
for index = 1:numel(tokens)
    values(index) = str2double(tokens{index}{1});
end
end

function remove_extract_tree(folderPath)
if isfolder(folderPath)
    rmdir(folderPath, 's');
end
end
