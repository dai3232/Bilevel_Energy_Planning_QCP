function write_table_csv_17g_atomic(filePath,dataTable)
%WRITE_TABLE_CSV_17G_ATOMIC Replace a task-owned CSV through a temp file.
%
% This helper is for cumulative evidence files inside a newly created run.
% It never follows symlinks or writes outside the requested parent.

arguments
    filePath (1,1) string
    dataTable table
end
parent = string(fileparts(filePath));
assert(isfolder(parent),"stageA4:a43:AtomicCsvParent", ...
    "The CSV parent directory does not exist: %s",parent);
temporary = string(tempname(parent))+".csv";
guard = onCleanup(@()delete_if_exists(temporary));
rkkt.artifacts.write_table_csv_17g(temporary,dataTable);
[moved,message] = movefile(temporary,filePath,"f");
assert(moved,"stageA4:a43:AtomicCsvMove","%s",message);
clear guard
end

function delete_if_exists(pathValue)
if isfile(pathValue)
    delete(pathValue);
end
end
