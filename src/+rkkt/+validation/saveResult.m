function saveResult(outputFile,moduleResult)
%SAVERESULT Save one fixed moduleResult MAT artifact.

arguments
    outputFile (1,1) string
    moduleResult (1,1) struct
end

rkkt.artifacts.save_mat_artifact(outputFile, ...
    struct("moduleResult",moduleResult));
end
