classdef (Sealed) ValidationSupport
    %VALIDATIONSUPPORT Internal file helpers for fixed PKG-4 observations.
    %   This class is not a production-model interface.

    methods (Static)
        function result = loadResult(inputArtifact,context)
            inputArtifact = string(inputArtifact);
            if ~isfile(inputArtifact)
                error("rkkt:model:validation:InputArtifactMissing", ...
                    "[%s] input artifact is missing: %s", ...
                    context,inputArtifact);
            end
            loaded = load(inputArtifact,"moduleResult");
            if ~isfield(loaded,"moduleResult")
                error("rkkt:model:validation:ModuleResultMissing", ...
                    "[%s] input artifact has no moduleResult: %s", ...
                    context,inputArtifact);
            end
            result = loaded.moduleResult;
            rkkt.contracts.validateModuleResult(result);
        end

        function requireOutputDirectory(directory,writeArtifacts)
            if writeArtifacts && ~isfolder(directory)
                error("rkkt:model:validation:OutputDirectoryMissing", ...
                    ["OutputDirectory must already exist; PKG-4 does not " ...
                    "create directories: %s"],directory);
            end
        end

        function value = sha256(inputArtifact,projectRoot)
            dataDirectory = fullfile(string(projectRoot),"src","data");
            productionFile = fullfile(dataDirectory,"compute_sha256_file.m");
            originalPath = path;
            pathGuard = onCleanup(@() path(originalPath));
            addpath(dataDirectory,"-begin");
            resolved = string(which("compute_sha256_file"));
            if ~rkkt.model.validation.ValidationSupport.samePath( ...
                    resolved,productionFile)
                error("rkkt:model:validation:HashFunctionShadowed", ...
                    "Expected compute_sha256_file at '%s'; resolved '%s'.", ...
                    productionFile,resolved);
            end
            value = compute_sha256_file(inputArtifact);
            clear pathGuard
        end

        function value = gitCommit(projectRoot)
            value = "NOT_AVAILABLE";
            projectRoot = string(projectRoot);
            if contains(projectRoot,"""")
                return
            end
            command = "git -C """+projectRoot+""" rev-parse HEAD";
            [status,output] = system(command);
            candidate = lower(strip(string(output)));
            if status == 0 && ~isempty(regexp(char(candidate), ...
                    "^[0-9a-f]{40}$","once"))
                value = candidate;
            end
        end

        function value = nowText()
            value = string(datetime("now", ...
                "TimeZone","Asia/Shanghai", ...
                "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
        end

        function value = metadata(interfaceName,productionFunction, ...
                inputArtifact,projectRoot,outputFile,moduleName, ...
                iteration,revision,interactive,writeArtifacts)
            value = struct( ...
                "interface_name",string(interfaceName), ...
                "production_function",string(productionFunction), ...
                "input_artifact",string(inputArtifact), ...
                "input_sha256", ...
                    rkkt.model.validation.ValidationSupport.sha256( ...
                    inputArtifact,projectRoot), ...
                "git_commit", ...
                    rkkt.model.validation.ValidationSupport.gitCommit( ...
                    projectRoot), ...
                "stage_id","stage_A4", ...
                "day",14:20, ...
                "hour",1:24, ...
                "iteration",iteration, ...
                "revision",revision, ...
                "matlab_version",string(version), ...
                "generated_at", ...
                    rkkt.model.validation.ValidationSupport.nowText(), ...
                "contract_version",rkkt.contracts.version(), ...
                "module_name",string(moduleName), ...
                "output_file",string(outputFile), ...
                "interactive_figures",interactive, ...
                "artifacts_requested",writeArtifacts);
        end

        function writeTable17(value,destination)
            if ~istable(value)
                error("rkkt:model:validation:ExpectedTable", ...
                    "CSV output requires a table; actual class=%s.", ...
                    class(value));
            end
            nRows = height(value);
            nColumns = width(value);
            cells = strings(nRows,nColumns);
            names = string(value.Properties.VariableNames);
            for columnIndex = 1:nColumns
                column = value.(value.Properties.VariableNames{columnIndex});
                if size(column,2) ~= 1
                    error("rkkt:model:validation:WideTableVariable", ...
                        "CSV variable '%s' must have one column.", ...
                        names(columnIndex));
                end
                cells(:,columnIndex) = ...
                    rkkt.model.validation.ValidationSupport. ...
                    columnToCsv(column);
            end
            header = rkkt.model.validation.ValidationSupport. ...
                csvEscape(names);
            lines = [strjoin(header,",");join(cells,",",2)];
            rkkt.model.validation.ValidationSupport.writeText( ...
                destination, ...
                strjoin(lines,newline)+newline);
        end

        function saveFigurePair(fig,figPath,pngPath)
            savefig(fig,figPath);
            exportgraphics(fig,pngPath,"Resolution",200);
        end

        function saveResult(outputFile,moduleResult)
            save(outputFile,"moduleResult","-v7.3");
        end
    end

    methods (Static, Access=private)
        function value = columnToCsv(column)
            if isnumeric(column)
                value = compose("%.17g",double(column));
            elseif islogical(column)
                value = lower(string(column));
            elseif isstring(column) || iscell(column) || ...
                    iscategorical(column)
                value = string(column);
                if any(ismissing(value))
                    error("rkkt:model:validation:MissingCsvText", ...
                        "Text CSV columns must not contain missing values.");
                end
                value = rkkt.model.validation.ValidationSupport. ...
                    csvEscape(value);
            else
                error("rkkt:model:validation:UnsupportedCsvType", ...
                    "Unsupported CSV column class: %s.",class(column));
            end
            value = reshape(value,[],1);
        end

        function value = csvEscape(value)
            value = replace(string(value),"""","""""");
            value = """"+value+"""";
        end

        function writeText(destination,textValue)
            [fileId,message] = fopen(destination,"wb","n","UTF-8");
            if fileId < 0
                error("rkkt:model:validation:TextOpen","%s",message);
            end
            fileGuard = onCleanup(@() ...
                rkkt.model.validation.ValidationSupport. ...
                closeFile(fileId));
            bytes = unicode2native(char(textValue),"UTF-8");
            count = fwrite(fileId,bytes,"uint8");
            if count ~= numel(bytes)
                error("rkkt:model:validation:TextWrite", ...
                    "Incomplete UTF-8 write for %s.",destination);
            end
            status = fclose(fileId);
            clear fileGuard
            if status ~= 0
                error("rkkt:model:validation:TextClose", ...
                    "Could not close output file %s.",destination);
            end
        end

        function closeFile(fileId)
            try
                if ischar(fopen(fileId))
                    fclose(fileId);
                end
            catch
            end
        end

        function value = samePath(left,right)
            left = replace(string(left),"/","\");
            right = replace(string(right),"/","\");
            if ispc
                value = strcmpi(left,right);
            else
                value = strcmp(left,right);
            end
        end
    end
end
