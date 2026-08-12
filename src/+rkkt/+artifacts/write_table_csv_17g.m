function write_table_csv_17g(filePath, dataTable)
%WRITE_TABLE_CSV_17G Write a table as deterministic UTF-8 RFC 4180 CSV.
%
% Variable order and names are preserved. Double and single floating-point
% values use %.17g. Fields containing commas, quotes, CR/LF, or leading or
% trailing whitespace are quoted, and embedded quotes are doubled. Records
% use CRLF regardless of host platform.

    filePath = validate_file_path(filePath);
    if ~istable(dataTable)
        error('stage0:artifacts:ExpectedTable', 'Input data must be a table.');
    end

    rkkt.artifacts.ensure_parent_directory(filePath);
    [fileId, message] = fopen(filePath, 'wb', 'n', 'UTF-8');
    if fileId < 0
        error('stage0:artifacts:CsvOpenFailed', ...
            'Could not open CSV file %s: %s', filePath, message);
    end
    closeGuard = onCleanup(@() rkkt.artifacts.close_file_if_open(fileId));

    variableNames = dataTable.Properties.VariableNames;
    write_record(fileId, variableNames);
    for rowIndex = 1:height(dataTable)
        fields = cell(1, width(dataTable));
        for columnIndex = 1:width(dataTable)
            column = dataTable.(variableNames{columnIndex});
            fields{columnIndex} = format_table_value( ...
                extract_row_value(column, rowIndex), variableNames{columnIndex});
        end
        write_record(fileId, fields);
    end

    closeStatus = fclose(fileId);
    clear closeGuard;
    if closeStatus ~= 0
        error('stage0:artifacts:CsvCloseFailed', ...
            'Could not close CSV file after writing: %s', filePath);
    end
end

function value = extract_row_value(column, rowIndex)
    if ischar(column)
        value = column(rowIndex, :);
    elseif iscell(column)
        value = column{rowIndex, :};
    else
        value = column(rowIndex, :);
    end
end

function textValue = format_table_value(value, variableName)
    while iscell(value) && isscalar(value)
        value = value{1};
    end
    if isempty(value)
        textValue = '';
        return;
    end
    if ~isscalar(value) && ~ischar(value)
        error('stage0:artifacts:NonScalarCsvValue', ...
            'Table variable %s contains a non-scalar row value.', variableName);
    end
    % MATLAB's SPRINTF rejects even a 1-by-1 sparse numeric input.  CSV
    % rows are scalar by contract, so materializing only that scalar is
    % safe and does not relax the prohibition on densifying model matrices.
    if isnumeric(value) && issparse(value)
        value = full(value);
    end

    if ischar(value)
        textValue = value;
    elseif isstring(value)
        if ismissing(value)
            textValue = '';
        else
            textValue = char(value);
        end
    elseif islogical(value)
        if value
            textValue = 'true';
        else
            textValue = 'false';
        end
    elseif isnumeric(value)
        if ~isreal(value)
            error('stage0:artifacts:ComplexCsvValue', ...
                'Table variable %s contains a complex value.', variableName);
        end
        if isfloat(value)
            textValue = sprintf('%.17g', value);
        elseif isa(value, 'uint8') || isa(value, 'uint16') || ...
                isa(value, 'uint32') || isa(value, 'uint64')
            textValue = sprintf('%u', value);
        else
            textValue = sprintf('%d', value);
        end
    elseif isdatetime(value) || isduration(value) || iscalendarduration(value)
        if ismissing(value)
            textValue = '';
        else
            textValue = char(string(value));
        end
    elseif iscategorical(value)
        if isundefined(value)
            textValue = '';
        else
            textValue = char(string(value));
        end
    else
        error('stage0:artifacts:UnsupportedCsvType', ...
            'Table variable %s has unsupported type %s.', variableName, class(value));
    end
end

function write_record(fileId, fields)
    escaped = cell(1, numel(fields));
    for k = 1:numel(fields)
        escaped{k} = escape_csv_field(char(string(fields{k})));
    end
    record = strjoin(escaped, ',');
    fprintf(fileId, '%s\r\n', record);
end

function escaped = escape_csv_field(value)
    requiresQuotes = contains(value, ',') || contains(value, '"') || ...
        contains(value, char(13)) || contains(value, newline) || ...
        (~isempty(value) && (isspace(value(1)) || isspace(value(end))));
    value = strrep(value, '"', '""');
    if requiresQuotes
        escaped = ['"', value, '"'];
    else
        escaped = value;
    end
end

function filePath = validate_file_path(filePath)
    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
        error('stage0:artifacts:InvalidPath', 'File path must be a text scalar.');
    end
    filePath = char(string(filePath));
    if isempty(filePath)
        error('stage0:artifacts:InvalidPath', 'File path must not be empty.');
    end
end
