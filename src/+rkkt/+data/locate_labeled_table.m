function location = locate_labeled_table(rawCells, sheetName, sectionLabel, headers, mode)
%LOCATE_LABELED_TABLE Locate a table by label and complete contiguous header.
%   LOCATION = LOCATE_LABELED_TABLE(RAWCELLS, SHEETNAME, SECTIONLABEL,
%   HEADERS, MODE) never uses an Excel row number. MODE is either:
%     "within-section" - search from SECTIONLABEL to the next nonempty cell
%                        in the section-label column; or
%     "same-row"       - require HEADERS immediately to the right of the
%                        unique SECTIONLABEL cell.

arguments
    rawCells cell
    sheetName (1, 1) string
    sectionLabel (1, 1) string
    headers (1, :) string
    mode (1, 1) string = "within-section"
end

if strlength(sheetName) == 0 || strlength(sectionLabel) == 0
    error("stage0:InvalidLocatorContract", "Sheet and section labels must not be empty.");
end
headers = strip(headers);
if isempty(headers) || any(ismissing(headers) | strlength(headers) == 0)
    error("stage0:InvalidLocatorContract", "Complete headers must contain only nonempty labels.");
end
if ~ismember(mode, ["within-section", "same-row"])
    error("stage0:InvalidLocatorMode", "Unsupported table locator mode: %s", mode);
end

cellText = normalize_cell_text(rawCells);
[labelRows, labelColumns] = find(cellText == sectionLabel);
if isempty(labelRows)
    error("stage0:SectionLabelMissing", ...
        "Sheet '%s' does not contain required section label '%s'.", sheetName, sectionLabel);
end
if numel(labelRows) ~= 1
    error("stage0:DuplicateSectionLabel", ...
        "Sheet '%s' contains %d copies of section label '%s'; exactly one is required.", ...
        sheetName, numel(labelRows), sectionLabel);
end
labelRow = labelRows(1);
labelColumn = labelColumns(1);

candidateRows = zeros(0, 1);
candidateColumns = zeros(0, 1);
headerCount = numel(headers);
if mode == "same-row"
    headerColumn = labelColumn + 1;
    if headerColumn + headerCount - 1 <= size(cellText, 2) && ...
            all(cellText(labelRow, headerColumn:(headerColumn + headerCount - 1)) == headers)
        candidateRows = labelRow;
        candidateColumns = headerColumn;
    end
else
    followingLabelOffset = find(strlength(cellText((labelRow + 1):end, labelColumn)) > 0, 1, "first");
    if isempty(followingLabelOffset)
        sectionEndRow = size(cellText, 1);
    else
        sectionEndRow = labelRow + followingLabelOffset - 1;
    end
    lastStartColumn = size(cellText, 2) - headerCount + 1;
    if lastStartColumn >= 1
        for rowIndex = labelRow:sectionEndRow
            for columnIndex = 1:lastStartColumn
                if all(cellText(rowIndex, columnIndex:(columnIndex + headerCount - 1)) == headers)
                    candidateRows(end + 1, 1) = rowIndex; %#ok<AGROW>
                    candidateColumns(end + 1, 1) = columnIndex; %#ok<AGROW>
                end
            end
        end
    end
end

if isempty(candidateRows)
    error("stage0:CompleteHeaderMissing", ...
        "Sheet '%s', section '%s' does not contain the required complete header: %s", ...
        sheetName, sectionLabel, strjoin(headers, " | "));
end
if numel(candidateRows) ~= 1
    error("stage0:DuplicateCompleteHeader", ...
        "Sheet '%s', section '%s' contains %d copies of the required complete header.", ...
        sheetName, sectionLabel, numel(candidateRows));
end

location = struct();
location.sheet = sheetName;
location.sectionLabel = sectionLabel;
location.labelRow = labelRow;
location.labelColumn = labelColumn;
location.headerRow = candidateRows(1);
location.headerStartColumn = candidateColumns(1);
location.headerEndColumn = candidateColumns(1) + headerCount - 1;
location.headers = headers;
location.mode = mode;
location.locator = "sheet+unique section label+complete contiguous header";
end

function cellText = normalize_cell_text(rawCells)
cellText = strings(size(rawCells));
for cellIndex = 1:numel(rawCells)
    value = rawCells{cellIndex};
    if isempty(value)
        continue;
    end
    try
        valueText = string(value);
    catch
        continue;
    end
    if ~isscalar(valueText) || ismissing(valueText)
        continue;
    end
    cellText(cellIndex) = strip(valueText);
end
end
