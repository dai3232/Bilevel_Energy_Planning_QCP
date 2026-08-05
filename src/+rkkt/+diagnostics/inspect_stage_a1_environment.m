function environment = inspect_stage_a1_environment()
%INSPECT_STAGE_A1_ENVIRONMENT Record A1 environment evidence without workers.
% The Stage A1 fixture is serial. This probe checks the MATLAB release and
% deterministic sparse linear algebra, records toolbox/license metadata,
% and deliberately performs no parallel computation.

rows = repmat(empty_row(),0,1);
checkedAt = now_text();

releaseName = string(version('-release'));
versionName = string(version);
rows(end+1) = make_row("MATLAB_RELEASE","MATLAB",true, ...
    "R2024a",sprintf("%s (%s)",versionName,releaseName), ...
    releaseName == "2024a",checkedAt,sprintf("arch=%s",computer('arch')));

mainDiagonal = 4*ones(5,1);
offDiagonal = -ones(5,1);
matrix = spdiags([offDiagonal,mainDiagonal,offDiagonal],[-1,0,1],5,5);
rightHandSides = [(1:5)',eye(5,2)];
try
    solution = matrix \ rightHandSides;
    relativeResidual = norm(matrix*solution-rightHandSides,'fro') / ...
        max(1,norm(rightHandSides,'fro'));
    passed = issparse(matrix) && all(isfinite(solution),'all') && ...
        isfinite(relativeResidual) && relativeResidual <= 1e-12;
    rows(end+1) = make_row("SPARSE_MLDIVIDE","稀疏多右端线性求解",true, ...
        "sparse=true; relative residual <= 1e-12", ...
        sprintf("sparse=%d; nrhs=%d; relative_residual=%.17g", ...
        issparse(matrix),size(rightHandSides,2),relativeResidual), ...
        passed,checkedAt,"deterministic sparse multiple-RHS system");

catch exception
    diagnostic = string(exception.identifier)+": "+string(exception.message);
    rows(end+1) = make_row("SPARSE_MLDIVIDE","稀疏多右端线性求解",true, ...
        "available","error",false,checkedAt,diagnostic);
end

try
    [factorL,factorD,permutation] = ldl(matrix,'vector');
    reconstruction = factorL*factorD*factorL';
    ldlResidual = norm(matrix(permutation,permutation)-reconstruction,'fro') / ...
        max(1,norm(matrix,'fro'));
    passed = issparse(factorL) && issparse(factorD) && ...
        isfinite(ldlResidual) && ldlResidual <= 1e-12 && ...
        isequal(sort(permutation(:)),(1:size(matrix,1))');
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL",true, ...
        "sparse factors; vector permutation; reconstruction residual <= 1e-12", ...
        sprintf("L_sparse=%d; D_sparse=%d; relative_residual=%.17g", ...
        issparse(factorL),issparse(factorD),ldlResidual), ...
        passed,checkedAt,"single deterministic factorization");
catch exception
    diagnostic = string(exception.identifier)+": "+string(exception.message);
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL",true, ...
        "available","error",false,checkedAt,diagnostic);
end

parallelInfo = ver('parallel');
installed = ~isempty(parallelInfo);
if installed
    actual = sprintf("%s %s (%s)",parallelInfo.Name, ...
        parallelInfo.Version,parallelInfo.Release);
else
    actual = "not installed";
end
rows(end+1) = make_row("PCT_INSTALLED","Parallel Computing Toolbox",false, ...
    "informational for serial A1",actual,installed,checkedAt, ...
    "installation metadata only; Stage 0 is the authoritative availability gate");

try
    licenseAvailable = logical(license('test','Distrib_Computing_Toolbox'));
    licenseActual = sprintf("license_test=%d",licenseAvailable);
    licenseDetails = "license metadata only";
catch exception
    licenseAvailable = false;
    licenseActual = "license test error";
    licenseDetails = string(exception.identifier)+": "+string(exception.message);
end
rows(end+1) = make_row("PCT_LICENSE","Parallel Computing Toolbox 许可证",false, ...
    "informational for serial A1",licenseActual,licenseAvailable,checkedAt, ...
    licenseDetails);

rows(end+1) = make_row("PARALLEL_EXECUTION","A1 并行执行",true, ...
    "not executed","not executed",true,checkedAt, ...
    "Stage A1 performs exactly one serial Newton-direction comparison");

environment = struct2table(rows);
end

function row = empty_row()
row = struct("check_id","","component","","blocking",true, ...
    "expected","","actual","","status","FAIL","available",false, ...
    "checked_at","","details","");
end

function row = make_row(id,component,blocking,expected,actual,available,checkedAt,details)
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
    row.status = 'PASS';
elseif ~row.blocking
    row.status = 'NOT_APPLICABLE';
end
end

function value = now_text()
value = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end
