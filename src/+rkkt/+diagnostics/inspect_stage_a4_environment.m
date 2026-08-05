function environment = inspect_stage_a4_environment()
%INSPECT_STAGE_A4_ENVIRONMENT Probe the serial formal A4 environment.

rows = repmat(empty_row(),0,1);
checkedAt = now_text();
releaseName = string(version("-release"));
rows(end+1) = make_row("MATLAB_RELEASE","MATLAB",true,"R2024a", ...
    sprintf("%s (%s)",string(version),releaseName), ...
    releaseName=="2024a",checkedAt,sprintf("arch=%s",computer("arch")));

diagonal = 4*ones(5,1);
offDiagonal = -ones(5,1);
matrix = spdiags([offDiagonal,diagonal,offDiagonal],[-1,0,1],5,5);
rhs = [(1:5)',eye(5,2)];
try
    solution = matrix\rhs;
    residual = norm(matrix*solution-rhs,"fro")/max(1,norm(rhs,"fro"));
    rows(end+1) = make_row("SPARSE_MLDIVIDE", ...
        "稀疏多右端线性求解",true, ...
        "sparse=true; relative residual <= 1e-12", ...
        sprintf("sparse=%d; nrhs=%d; relative_residual=%.17g", ...
        issparse(matrix),size(rhs,2),residual), ...
        issparse(matrix)&&all(isfinite(solution),"all")&& ...
        residual<=1e-12,checkedAt, ...
        "deterministic sparse multiple-RHS system");
catch cause
    rows(end+1) = make_row("SPARSE_MLDIVIDE", ...
        "稀疏多右端线性求解",true,"available","error",false, ...
        checkedAt,string(cause.identifier)+": "+string(cause.message));
end

try
    [L,D,p] = ldl(matrix,"vector");
    residual = norm(matrix(p,p)-L*D*L',"fro")/ ...
        max(1,norm(matrix,"fro"));
    passed = issparse(L)&&issparse(D)&&residual<=1e-12&& ...
        isequal(sort(p(:)),(1:size(matrix,1))');
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL",true, ...
        "sparse factors; vector permutation; residual <= 1e-12", ...
        sprintf("L_sparse=%d; D_sparse=%d; relative_residual=%.17g", ...
        issparse(L),issparse(D),residual),passed,checkedAt, ...
        "single deterministic factorization");
catch cause
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL",true, ...
        "available","error",false,checkedAt, ...
        string(cause.identifier)+": "+string(cause.message));
end

parallelInfo = ver("parallel");
installed = ~isempty(parallelInfo);
if installed
    actual = sprintf("%s %s (%s)",parallelInfo.Name, ...
        parallelInfo.Version,parallelInfo.Release);
else
    actual = "not installed";
end
rows(end+1) = make_row("PCT_INSTALLED", ...
    "Parallel Computing Toolbox",false, ...
    "informational for serial A4-3",actual,installed,checkedAt, ...
    "metadata only; no pool is opened");
try
    available = logical(license("test","Distrib_Computing_Toolbox"));
    actual = sprintf("license_test=%d",available);
    details = "license metadata only";
catch cause
    available = false;
    actual = "license test error";
    details = string(cause.identifier)+": "+string(cause.message);
end
rows(end+1) = make_row("PCT_LICENSE", ...
    "Parallel Computing Toolbox 许可证",false, ...
    "informational for serial A4-3",actual,available,checkedAt,details);
rows(end+1) = make_row("PARALLEL_EXECUTION","A4-3 并行执行",true, ...
    "not executed","not executed",true,checkedAt, ...
    "A4-3 evaluates seven days serially");
environment = struct2table(rows);
end

function row = empty_row()
row = struct("check_id","","component","","blocking",true, ...
    "expected","","actual","","status","FAIL","available",false, ...
    "checked_at","","details","");
end

function row = make_row(id,component,blocking,expected,actual, ...
        available,checkedAt,details)
row = empty_row();
row.check_id = char(id);
row.component = char(component);
row.blocking = logical(blocking);
row.expected = char(expected);
row.actual = char(actual);
row.available = logical(available);
row.checked_at = char(checkedAt);
row.details = char(details);
if row.available
    row.status = "PASS";
elseif ~row.blocking
    row.status = "NOT_APPLICABLE";
end
end

function value = now_text()
value = string(datetime("now","TimeZone","Asia/Shanghai", ...
    "Format","yyyy-MM-dd'T'HH:mm:ssXXX"));
end
