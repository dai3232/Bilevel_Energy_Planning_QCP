classdef (Sealed) ValidationSupport
    %VALIDATIONSUPPORT Shared fixed-artifact helpers for PKG-7.

    methods (Static)
        function value = repositoryRoot()
            validationDirectory = string(fileparts(mfilename("fullpath")));
            ipmPackageDirectory = string(fileparts(validationDirectory));
            rkktDirectory = string(fileparts(ipmPackageDirectory));
            sourceDirectory = string(fileparts(rkktDirectory));
            value = string(fileparts(sourceDirectory));
        end

        function value = outputDirectory()
            value = string(fileparts(mfilename("fullpath")));
        end

        function value = packageArtifact(packageName,fileName)
            root = rkkt.ipm.validation.ValidationSupport.repositoryRoot();
            value = fullfile(root,"src","+rkkt","+"+string(packageName), ...
                "+validation",string(fileName));
        end

        function result = loadResult(inputArtifact,context,expectedInterface)
            result = rkkt.model.validation.ValidationSupport.loadResult( ...
                inputArtifact,context);
            if nargin>=3 && strlength(string(expectedInterface))>0 && ...
                    string(result.meta.interface_name)~= ...
                    string(expectedInterface)
                error("rkkt:ipm:validation:UpstreamInterface", ...
                    "[%s] expected '%s'; actual '%s'.", ...
                    context,expectedInterface,result.meta.interface_name);
            end
        end

        function value = artifactReference( ...
                inputArtifact,identity,interfaceName)
            root = rkkt.ipm.validation.ValidationSupport.repositoryRoot();
            value = struct( ...
                "path",string(inputArtifact), ...
                "sha256", ...
                    rkkt.model.validation.ValidationSupport.sha256( ...
                    inputArtifact,root), ...
                "identity",string(identity), ...
                "interface_name",string(interfaceName));
        end

        function value = metadata(interfaceName,productionFunction, ...
                primaryArtifact,outputFile,moduleName,iteration,revision, ...
                interactive,writeArtifacts)
            root = rkkt.ipm.validation.ValidationSupport.repositoryRoot();
            value = rkkt.model.validation.ValidationSupport.metadata( ...
                interfaceName,productionFunction,primaryArtifact,root, ...
                outputFile,moduleName,iteration,revision,interactive, ...
                writeArtifacts);
        end

        function value = callProduction(folder,functionName,varargin)
            root = rkkt.ipm.validation.ValidationSupport.repositoryRoot();
            directory = fullfile(root,"src",string(folder));
            productionFile = fullfile(directory,string(functionName)+".m");
            if ~isfile(productionFile)
                error("rkkt:ipm:validation:ProductionFileMissing", ...
                    "Production file is missing: %s",productionFile);
            end
            originalPath = path;
            pathGuard = onCleanup(@() path(originalPath));
            addpath(directory,"-begin");
            resolved = string(which(string(functionName)));
            if ~rkkt.ipm.validation.ValidationSupport.samePath( ...
                    resolved,productionFile)
                error("rkkt:ipm:validation:ProductionFunctionShadowed", ...
                    "Expected '%s'; MATLAB resolved '%s'.", ...
                    productionFile,resolved);
            end
            callable = str2func(string(functionName));
            value = callable(varargin{:});
            clear pathGuard
        end

        function value = deterministicEqual(left,right)
            value = isequaln( ...
                rkkt.ipm.validation.ValidationSupport.withoutTiming(left), ...
                rkkt.ipm.validation.ValidationSupport.withoutTiming(right));
        end

        function value = withoutTiming(input)
            value = input;
            if isstruct(value) && isscalar(value) && ...
                    isfield(value,"timing")
                value = rmfield(value,"timing");
            end
        end

        function value = timingValid(timing)
            values = struct2cell(timing);
            value = all(cellfun(@(item)isnumeric(item) && isscalar(item) && ...
                isfinite(item) && item>=0,values));
        end

        function value = stateFingerprint(state)
            value = ...
                rkkt.ipm.validation.ValidationSupport.callProduction( ...
                "artifacts","compute_stage_a4_checkpoint_state_fingerprint", ...
                state);
        end

        function requireOutputDirectory(directory,writeArtifacts)
            rkkt.model.validation.ValidationSupport. ...
                requireOutputDirectory(directory,writeArtifacts);
        end

        function writeTable17(value,destination)
            rkkt.model.validation.ValidationSupport.writeTable17( ...
                value,destination);
        end

        function saveFigurePair(fig,figPath,pngPath)
            rkkt.model.validation.ValidationSupport.saveFigurePair( ...
                fig,figPath,pngPath);
        end

        function saveResult(outputFile,moduleResult)
            rkkt.model.validation.ValidationSupport.saveResult( ...
                outputFile,moduleResult);
        end

        function fig = newFigure(name,interactive)
            visibility = "off";
            if interactive
                visibility = "on";
            end
            fig = figure("Name",string(name),"NumberTitle","off", ...
                "Color","w","Visible",visibility, ...
                "Position",[100,100,980,720]);
        end

        function [outputFile,tableFiles,figureFiles,index] = ...
                outputPaths(outputDirectory,matName,tableNames, ...
                figureName,writeArtifacts)
            if writeArtifacts
                outputFile = fullfile(outputDirectory,string(matName));
                tableFiles = fullfile(outputDirectory, ...
                    reshape(string(tableNames),[],1));
                index = struct( ...
                    "figPath",fullfile(outputDirectory, ...
                        string(figureName)+".fig"), ...
                    "pngPath",fullfile(outputDirectory, ...
                        string(figureName)+".png"));
                figureFiles = [string(index.figPath); ...
                    string(index.pngPath)];
            else
                outputFile = "";
                tableFiles = strings(0,1);
                figureFiles = strings(0,1);
                index = struct("figPath","","pngPath","");
            end
            outputFile = string(outputFile);
            tableFiles = reshape(string(tableFiles),[],1);
            figureFiles = reshape(string(figureFiles),[],1);
        end
    end

    methods (Static, Access=private)
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
