function write_stage_a4_checkpoint_manifest_atomic(filePath,dataTable)
%WRITE_STAGE_A4_CHECKPOINT_MANIFEST_ATOMIC Publish the manifest atomically.

assert(ischar(filePath)||(isstring(filePath)&&isscalar(filePath)), ...
    "stageA4:checkpoint:AtomicManifestPath", ...
    "Checkpoint manifest path must be a text scalar.");
filePath = char(string(filePath));
rkkt.artifacts.ensure_parent_directory(filePath);
parent = fileparts(filePath);
temporaryPath = [tempname(parent),'.csv.tmp'];
cleanupGuard = onCleanup(@()rkkt.artifacts.delete_file_if_exists(temporaryPath));
rkkt.artifacts.write_table_csv_17g(temporaryPath,dataTable);
[moved,message] = movefile(temporaryPath,filePath,"f");
assert(moved,"stageA4:checkpoint:AtomicManifestMove", ...
    "Could not atomically publish %s: %s",filePath,message);
clear cleanupGuard
end
