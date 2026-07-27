function validateModuleResult(moduleResult)
%VALIDATEMODULERESULT Validate the manual module-validation envelope.
%   Diagnostics may contain objective numeric/logical facts, but terminal
%   PASS/FAIL verdict strings are forbidden.

context = "moduleResult";
required = rkkt.contracts.requiredFields("moduleResult");
rkkt.contracts.requireFields(moduleResult,required,context, ...
    "AllowAdditionalFields",false);
rkkt.contracts.validateModuleMetadata(moduleResult.meta);
requireStringColumn(moduleResult.tableFiles,context+".tableFiles");
requireStringColumn(moduleResult.figureFiles,context+".figureFiles");
assertNoVerdict(moduleResult.diagnostics,context+".diagnostics");
end

function requireStringColumn(value,context)
if ~isstring(value) || size(value,2)~=1 || any(ismissing(value),"all")
    error("rkkt:contracts:InvalidFileList", ...
        "[%s] expected a nonmissing string column; actual class=%s, size=%s.", ...
        context,class(value),describeSize(value));
end
end

function assertNoVerdict(value,context)
if isstring(value) || ischar(value) || iscategorical(value)
    tokens = upper(strtrim(string(value)));
    forbidden = ~cellfun(@isempty,regexp(cellstr(tokens(:)), ...
        "^(PASS|FAIL(?:_.+)?)$","once"));
    if any(forbidden)
        error("rkkt:contracts:ManualVerdictForbidden", ...
            "[%s] manual diagnostics must contain objective facts, not PASS/FAIL verdicts.", ...
            context);
    end
elseif isstruct(value)
    fields = string(fieldnames(value));
    for elementIndex = 1:numel(value)
        for fieldIndex = 1:numel(fields)
            name = fields(fieldIndex);
            assertNoVerdict(value(elementIndex).(name), ...
                context+"."+name);
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        assertNoVerdict(value{k},context+"{"+string(k)+"}");
    end
elseif istable(value)
    names = string(value.Properties.VariableNames);
    for k = 1:numel(names)
        assertNoVerdict(value.(names(k)),context+"."+names(k));
    end
end
end
