function environment = inspect_stage0_environment()
%INSPECT_STAGE0_ENVIRONMENT Record real MATLAB, sparse, and PCT evidence.

rows = repmat(empty_row(),0,1);
checkedAt = string(datetime('now','TimeZone','Asia/Shanghai', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));

releaseName = string(version('-release'));
versionName = string(version);
rows(end+1) = make_row("MATLAB_RELEASE","MATLAB", ...
    "R2024a",sprintf("%s (%s)",versionName,releaseName), ...
    releaseName == "2024a",checkedAt, ...
    sprintf("arch=%s",computer('arch'))); %#ok<AGROW>

try
    mainDiagonal = 4*ones(3,1);
    offDiagonal = -ones(3,1);
    sparseMatrix = spdiags([offDiagonal,mainDiagonal,offDiagonal],[-1,0,1],3,3);
    rhs = [1;2;3];
    solution = sparseMatrix \ rhs;
    relativeResidual = norm(sparseMatrix*solution-rhs,2)/max(1,norm(rhs,2));
    sparsePass = issparse(sparseMatrix) && isfinite(relativeResidual) && ...
        relativeResidual <= 1e-12;
    rows(end+1) = make_row("SPARSE_MLDIVIDE","稀疏线性代数", ...
        "sparse=true; relative residual <= 1e-12", ...
        sprintf("sparse=%d; nnz=%d; relative_residual=%.17g", ...
        issparse(sparseMatrix),nnz(sparseMatrix),relativeResidual), ...
        sparsePass,checkedAt,"deterministic tridiagonal system"); %#ok<AGROW>

    [factorL,factorD,permutation] = ldl(sparseMatrix,'vector');
    reconstruction = factorL*factorD*factorL';
    ldlResidual = norm(sparseMatrix(permutation,permutation)-reconstruction,'fro') / ...
        max(1,norm(sparseMatrix,'fro'));
    ldlPass = issparse(factorL) && isfinite(ldlResidual) && ldlResidual <= 1e-12;
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL", ...
        "sparse factor; reconstruction residual <= 1e-12", ...
        sprintf("L_sparse=%d; relative_residual=%.17g", ...
        issparse(factorL),ldlResidual),ldlPass,checkedAt, ...
        "single deterministic factorization"); %#ok<AGROW>
catch ME
    rows(end+1) = make_row("SPARSE_MLDIVIDE","稀疏线性代数", ...
        "available","error",false,checkedAt,string(ME.message)); %#ok<AGROW>
    rows(end+1) = make_row("SPARSE_LDL","稀疏 LDL", ...
        "available","error",false,checkedAt,string(ME.message)); %#ok<AGROW>
end

parallelInfo = ver('parallel');
parallelInstalled = ~isempty(parallelInfo);
if parallelInstalled
    parallelActual = sprintf("%s %s (%s)",parallelInfo.Name, ...
        parallelInfo.Version,parallelInfo.Release);
else
    parallelActual = "not installed";
end
rows(end+1) = make_row("PCT_INSTALLED","Parallel Computing Toolbox", ...
    "installed",parallelActual,parallelInstalled,checkedAt, ...
    "ver('parallel')"); %#ok<AGROW>

try
    licenseAvailable = logical(license('test','Distrib_Computing_Toolbox'));
    licenseActual = sprintf("license_test=%d",licenseAvailable);
catch ME
    licenseAvailable = false;
    licenseActual = "license test error";
    licenseDetails = string(ME.message);
end
if ~exist('licenseDetails','var')
    licenseDetails = "license('test','Distrib_Computing_Toolbox')";
end
rows(end+1) = make_row("PCT_LICENSE","Parallel Computing Toolbox 许可证", ...
    "available",licenseActual,licenseAvailable,checkedAt,licenseDetails); %#ok<AGROW>

workerAvailable = false;
workerActual = "not run";
workerDetails = "";
if parallelInstalled && licenseAvailable
    pool = [];
    createdPool = false;
    try
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('Processes',1);
            createdPool = true;
        end
        cleanupPool = onCleanup(@() close_created_pool(pool,createdPool)); %#ok<NASGU>
        future = parfeval(pool,@plus,1,20,22);
        workerResult = fetchOutputs(future);
        workerAvailable = isequal(workerResult,42);
        workerActual = sprintf("worker_result=%g; workers=%d",workerResult,pool.NumWorkers);
        workerDetails = "Processes pool and parfeval completed";
    catch ME
        workerActual = "execution error";
        workerDetails = string(ME.message);
    end
else
    workerDetails = "toolbox or license unavailable";
end
rows(end+1) = make_row("PCT_WORKER","并行 worker 实测", ...
    "parfeval result = 42",workerActual,workerAvailable,checkedAt,workerDetails); %#ok<AGROW>

environment = struct2table(rows);
end

function row = empty_row()
row = struct("check_id","","component","","expected","","actual","", ...
    "status","FAIL","available",false,"checked_at","","details","");
end

function row = make_row(id,component,expected,actual,available,checkedAt,details)
row = empty_row(); row.check_id = char(id); row.component = char(component);
row.expected = char(expected); row.actual = char(actual);
row.available = logical(available); row.checked_at = char(checkedAt);
row.details = char(details);
if row.available
    row.status = 'PASS';
end
end

function close_created_pool(pool,createdPool)
if createdPool && ~isempty(pool) && isvalid(pool)
    delete(pool);
end
end
