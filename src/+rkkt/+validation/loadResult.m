function result = loadResult(inputArtifact,context,expectedInterface)
%LOADRESULT Load and validate one moduleResult artifact.

arguments
    inputArtifact (1,1) string
    context (1,1) string
    expectedInterface (1,1) string = ""
end

assert(isfile(inputArtifact),"rkkt:validation:InputArtifactMissing", ...
    "[%s] input artifact is missing: %s",context,inputArtifact);
loaded = load(inputArtifact,"moduleResult");
assert(isfield(loaded,"moduleResult"), ...
    "rkkt:validation:ModuleResultMissing", ...
    "[%s] input artifact has no moduleResult: %s",context,inputArtifact);
result = loaded.moduleResult;
rkkt.contracts.validateModuleResult(result);
if strlength(expectedInterface)>0
    assert(string(result.meta.interface_name)==expectedInterface, ...
        "rkkt:validation:UpstreamInterface", ...
        "[%s] expected interface '%s'; actual '%s'.", ...
        context,expectedInterface,result.meta.interface_name);
end
end
