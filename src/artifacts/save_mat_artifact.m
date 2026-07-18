function save_mat_artifact(filePath, varargin)
%SAVE_MAT_ARTIFACT Save named artifacts to a v7.3 MAT file atomically.
%
% save_mat_artifact(path, scalarStruct) saves each struct field as a named
% MAT variable. save_mat_artifact(path, name1, value1, ...) does the same for
% name-value pairs. A single non-struct value is stored as variable artifact.

    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
        error('stage0:artifacts:InvalidPath', 'File path must be a text scalar.');
    end
    filePath = char(string(filePath));
    if isempty(filePath)
        error('stage0:artifacts:InvalidPath', 'File path must not be empty.');
    end
    if isempty(varargin)
        error('stage0:artifacts:MissingMatData', ...
            'At least one value must be supplied for a MAT artifact.');
    end

    payload = build_payload(varargin{:});
    ensure_parent_directory(filePath);
    parent = fileparts(filePath);
    temporaryPath = [tempname(parent), '.mat'];
    cleanupGuard = onCleanup(@() delete_file_if_exists(temporaryPath));

    try
        save(temporaryPath, '-struct', 'payload', '-v7.3');
    catch exception
        error('stage0:artifacts:MatSaveFailed', ...
            'Could not save MAT artifact %s: %s', filePath, exception.message);
    end

    [moved, moveMessage] = movefile(temporaryPath, filePath, 'f');
    if ~moved
        error('stage0:artifacts:MatMoveFailed', ...
            'Could not finalize MAT artifact %s: %s', filePath, moveMessage);
    end
    clear cleanupGuard;
end

function payload = build_payload(varargin)
    if isscalar(varargin)
        value = varargin{1};
        if isstruct(value) && isscalar(value)
            payload = value;
        else
            payload = struct('artifact', value);
        end
        return;
    end

    if mod(numel(varargin), 2) ~= 0
        error('stage0:artifacts:InvalidMatArguments', ...
            'MAT artifacts require a scalar struct or name-value pairs.');
    end
    payload = struct();
    for k = 1:2:numel(varargin)
        name = varargin{k};
        if ~(ischar(name) || (isstring(name) && isscalar(name)))
            error('stage0:artifacts:InvalidMatVariableName', ...
                'MAT variable names must be text scalars.');
        end
        name = char(string(name));
        if ~isvarname(name)
            error('stage0:artifacts:InvalidMatVariableName', ...
                'Invalid MAT variable name: %s', name);
        end
        if isfield(payload, name)
            error('stage0:artifacts:DuplicateMatVariableName', ...
                'Duplicate MAT variable name: %s', name);
        end
        payload.(name) = varargin{k + 1};
    end
end
