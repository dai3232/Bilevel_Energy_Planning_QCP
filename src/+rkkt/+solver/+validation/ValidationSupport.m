classdef (Sealed) ValidationSupport
    %VALIDATIONSUPPORT Shared helpers for fixed PKG-6 manual validation.
    %   This class performs only artifact I/O, production-entry lookup, and
    %   small diagnostic formatting. It does not implement solver algebra.

    methods (Static)
        function value = repositoryRoot()
            validationDirectory = string(fileparts(mfilename("fullpath")));
            solverPackageDirectory = string(fileparts(validationDirectory));
            rkktDirectory = string(fileparts(solverPackageDirectory));
            sourceDirectory = string(fileparts(rkktDirectory));
            value = string(fileparts(sourceDirectory));
        end

        function value = outputDirectory()
            value = string(fileparts(mfilename("fullpath")));
        end

        function value = solverArtifact(fileName)
            value = fullfile( ...
                rkkt.solver.validation.ValidationSupport.outputDirectory(), ...
                string(fileName));
        end

        function value = modelArtifact(fileName)
            root = rkkt.solver.validation.ValidationSupport.repositoryRoot();
            value = fullfile(root,"src","+rkkt","+model","+validation", ...
                string(fileName));
        end

        function result = loadResult(inputArtifact,context,expectedInterface)
            result = rkkt.model.validation.ValidationSupport.loadResult( ...
                inputArtifact,context);
            if nargin >= 3 && strlength(string(expectedInterface)) > 0 && ...
                    string(result.meta.interface_name) ~= ...
                    string(expectedInterface)
                error("rkkt:solver:validation:UpstreamInterface", ...
                    "[%s] expected interface '%s'; actual '%s'.", ...
                    context,expectedInterface,result.meta.interface_name);
            end
        end

        function value = artifactReference( ...
                inputArtifact,identity,interfaceName)
            root = rkkt.solver.validation.ValidationSupport.repositoryRoot();
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
            root = rkkt.solver.validation.ValidationSupport.repositoryRoot();
            value = rkkt.model.validation.ValidationSupport.metadata( ...
                interfaceName,productionFunction,primaryArtifact,root, ...
                outputFile,moduleName,iteration,revision,interactive, ...
                writeArtifacts);
        end

        function value = callProduction(functionName,varargin)
            functionName = string(functionName);
            root = rkkt.solver.validation.ValidationSupport.repositoryRoot();
            directory = fullfile(root,"src","solver");
            productionFile = fullfile(directory,functionName+".m");
            if ~isfile(productionFile)
                error("rkkt:solver:validation:ProductionFileMissing", ...
                    "Production solver file is missing: %s",productionFile);
            end
            originalPath = path;
            pathGuard = onCleanup(@() path(originalPath));
            addpath(directory,"-begin");
            resolved = string(which(functionName));
            if ~rkkt.solver.validation.ValidationSupport.samePath( ...
                    resolved,productionFile)
                error("rkkt:solver:validation:ProductionFunctionShadowed", ...
                    "Expected '%s'; MATLAB resolved '%s'.", ...
                    productionFile,resolved);
            end
            productionFunction = str2func(functionName);
            value = productionFunction(varargin{:});
            clear pathGuard
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
                "Position",[100,100,920,720]);
        end

        function value = smallDense(matrixValue,maximumDimension)
            if any(size(matrixValue) > maximumDimension)
                error("rkkt:solver:validation:SmallMatrixLimit", ...
                    "Diagnostic dense conversion is limited to %d-by-%d.", ...
                    maximumDimension,maximumDimension);
            end
            value = zeros(size(matrixValue));
            [rows,columns,entries] = find(matrixValue);
            if ~isempty(entries)
                indices = sub2ind(size(value),rows,columns);
                value(indices) = entries;
            end
        end

        function value = matrixTable(matrixValue,rowVariableName)
            dense = rkkt.solver.validation.ValidationSupport. ...
                smallDense(matrixValue,16);
            rowIndex = (1:size(dense,1)).';
            names = [string(rowVariableName), ...
                compose("column_%02d",1:size(dense,2))];
            value = array2table([rowIndex,dense], ...
                "VariableNames",cellstr(names));
        end

        function [outputFile,tableFiles,figureFiles,figureIndex] = ...
                outputPaths(outputDirectory,matName,tableNames, ...
                figureName,writeArtifacts)
            if writeArtifacts
                outputFile = fullfile(outputDirectory,string(matName));
                tableFiles = fullfile(outputDirectory, ...
                    reshape(string(tableNames),[],1));
                figPath = fullfile(outputDirectory,string(figureName)+".fig");
                pngPath = fullfile(outputDirectory,string(figureName)+".png");
                figureFiles = [figPath;pngPath];
            else
                outputFile = "";
                tableFiles = strings(0,1);
                figPath = "";
                pngPath = "";
                figureFiles = strings(0,1);
            end
            outputFile = string(outputFile);
            tableFiles = reshape(string(tableFiles),[],1);
            figureFiles = reshape(string(figureFiles),[],1);
            figureIndex = struct( ...
                "figPath",string(figPath),"pngPath",string(pngPath));
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
