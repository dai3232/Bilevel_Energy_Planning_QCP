function value = artifactReference(inputArtifact,identity,interfaceName)
%ARTIFACTREFERENCE Build a compact upstream-artifact reference.

arguments
    inputArtifact (1,1) string
    identity (1,1) string
    interfaceName (1,1) string
end

value = struct( ...
    "path",inputArtifact, ...
    "sha256",rkkt.validation.sha256(inputArtifact), ...
    "identity",identity, ...
    "interface_name",interfaceName);
end
