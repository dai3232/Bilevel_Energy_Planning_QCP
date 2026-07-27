function names = requiredFields(contractName)
%REQUIREDFIELDS Return the ordered required fields for a named contract.

arguments
    contractName (1,1) string
end

switch contractName
    case "moduleResult"
        names = ["meta";"input";"output";"intermediate";"diagnostics"; ...
            "indexDescription";"tableFiles";"figureFiles"];
    case "moduleMetadata"
        names = ["interface_name";"production_function"; ...
            "input_artifact";"input_sha256";"git_commit";"stage_id"; ...
            "day";"hour";"iteration";"revision";"matlab_version"; ...
            "generated_at";"contract_version"];
    otherwise
        error("rkkt:contracts:UnknownContract", ...
            "Contract '%s' is not registered. Expected moduleResult or moduleMetadata.", ...
            contractName);
end
end
