function info = capture_git_state(projectRoot)
%CAPTURE_GIT_STATE Read git commit/status without changing git configuration.

    normalizedRoot = strrep(projectRoot, '\', '/');
    if contains(normalizedRoot, '"') || contains(projectRoot, '"')
        error('stage0:artifacts:InvalidProjectPath', ...
            'Project path cannot contain a double quote.');
    end
    prefix = sprintf('git -c "safe.directory=%s" -C "%s"', ...
        normalizedRoot, projectRoot);
    [commitStatus, commitOutput] = system( ...
        sprintf('%s rev-parse --verify HEAD 2>&1', prefix));

    info = struct();
    info.commit = 'NOT_AVAILABLE';
    info.short_commit = 'nogit';
    if commitStatus ~= 0
        info.state_text = sprintf([ ...
            'git_available: false\r\n', ...
            'git_commit: NOT_AVAILABLE\r\n', ...
            'diagnostic:\r\n%s\r\n'], strtrim(normalize_newlines(commitOutput)));
        return;
    end

    commit = first_nonempty_line(commitOutput);
    if isempty(commit)
        commit = 'NOT_AVAILABLE';
    end
    info.commit = commit;
    info.short_commit = commit(1:min(8, numel(commit)));

    [statusCode, statusOutput] = system( ...
        sprintf('%s status --short --branch 2>&1', prefix));
    if statusCode ~= 0
        statusOutput = sprintf('git status failed (exit %d):\n%s', ...
            statusCode, statusOutput);
    end
    info.state_text = sprintf([ ...
        'git_available: true\r\n', ...
        'git_commit: %s\r\n', ...
        'git_status:\r\n%s\r\n'], ...
        commit, strtrim(normalize_newlines(statusOutput)));
end

function line = first_nonempty_line(textValue)
    lines = splitlines(string(textValue));
    lines = strip(lines);
    lines(lines == "") = [];
    if isempty(lines)
        line = '';
    else
        line = char(lines(1));
    end
end

function output = normalize_newlines(input)
    output = strrep(input, [char(13), newline], newline);
    output = strrep(output, char(13), newline);
end
