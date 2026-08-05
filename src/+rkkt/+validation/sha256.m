function value = sha256(inputArtifact)
%SHA256 Compute an artifact SHA256 with the package implementation.

arguments
    inputArtifact (1,1) string
end

value = rkkt.data.compute_sha256_file(inputArtifact);
end
