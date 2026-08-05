function environment = inspect_stage_b2a_environment()
%INSPECT_STAGE_B2A_ENVIRONMENT Record capabilities used by B-2A assembly.
% No factorization, KKT solve, parallel pool, IPM, or optimization is run.

rows = repmat(empty_row(),0,1);
checked = now_text();
release = string(version("-release"));
rows(end+1) = make_row("MATLAB_RELEASE","MATLAB R2024a",true, ...
    "2024a",release,release=="2024a",checked,computer("arch"));
 sparseAvailable = exist("sparse","builtin")>0 || exist("sparse","file")>0;
rows(end+1) = make_row("SPARSE_ASSEMBLY","sparse/spdiags",true, ...
    "available",string(sparseAvailable),sparseAvailable,checked, ...
    "Structure construction only; no solve.");
 excelAvailable = exist("readcell","file")>0 || exist("readcell","builtin")>0;
rows(end+1) = make_row("EXCEL_IO","controlled input reader",true, ...
    "available",string(excelAvailable),excelAvailable,checked, ...
    "Input is loaded through the frozen label/header reader.");
rows(end+1) = make_row("FULL_KKT_ASSEMBLY","sparse 18948 structure",true, ...
    "assemble_only","assemble_only",true,checked, ...
    "The full KKT is assembled and audited, never solved.");
rows(end+1) = make_row("FULL_KKT_SOLVE","full KKT solve",true, ...
    "not executed","not executed",true,checked, ...
    "B-2A boundary.");
rows(end+1) = make_row("RECURSIVE_DIRECTION","recursive/Newton direction",true, ...
    "not executed","not executed",true,checked, ...
    "B-2A boundary.");
rows(end+1) = make_row("IPM_OPTIMIZATION","IPM/optimization/state update",true, ...
    "not executed","not executed",true,checked, ...
    "B-2A boundary.");
rows(end+1) = make_row("PARALLEL_EXECUTION","parpool/parfor",true, ...
    "off","off",true,checked, ...
    "No parallel execution is permitted.");
environment = struct2table(rows);
end

function row = empty_row()
row = struct("check_id","","component","","blocking",true, ...
    "expected","","actual","","status","FAIL","available",false, ...
    "checked_at","","details","");
end

function row = make_row(id,component,blocking,expected,actual,available,checked,details)
row = empty_row();
row.check_id = char(id);
row.component = char(component);
row.blocking = logical(blocking);
row.expected = char(expected);
row.actual = char(actual);
row.available = logical(available);
row.checked_at = char(checked);
row.details = char(details);
if row.available
    row.status = "PASS";
end
end

function value = now_text()
value = string(datetime("now","TimeZone","Asia/Shanghai", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end
