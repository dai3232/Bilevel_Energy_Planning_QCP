param(
    [string]$SourceCommit = "58b2b3645b79c71460ff0de1a03033c319829cd6"
)

$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..")).Path
$safeRoot = $projectRoot.Replace("\", "/")
$toolingCommit = (& git -c "safe.directory=$safeRoot" -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $toolingCommit.Length -ne 40) {
    throw "Unable to determine the tooling commit."
}

$fixtureDirectory = Join-Path $projectRoot "tests\fixtures\stage_A4_RNS_1_authority_v1"
if (Test-Path -LiteralPath $fixtureDirectory) {
    throw "Refusing to overwrite the authority fixture: $fixtureDirectory"
}

$tempParent = [System.IO.Path]::GetTempPath()
$tempName = "Hourly_Recursive_KKT_A4_RNS_1_" + [Guid]::NewGuid().ToString("N")
$sourceWorktree = Join-Path $tempParent $tempName
$worktreeAdded = $false
$generationSucceeded = $false

try {
    & git -c "safe.directory=$safeRoot" -C $projectRoot worktree add --detach $sourceWorktree $SourceCommit
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create the detached authority worktree."
    }
    $worktreeAdded = $true

    $generatorDirectory = Join-Path $projectRoot "src\diagnostics"
    $escapedGenerator = $generatorDirectory.Replace("'", "''")
    $escapedSource = $sourceWorktree.Replace("'", "''")
    $escapedOutput = $fixtureDirectory.Replace("'", "''")
    $batch = "addpath('$escapedGenerator'); result=generate_stage_a4_rns1_stress_fixture(" +
        "'$escapedSource','$escapedOutput',SourceCommit='$SourceCommit'," +
        "ToolingCommit='$toolingCommit'); assert(result.all_pass);"
    & matlab -batch $batch
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB authority fixture generation failed."
    }
    $generationSucceeded = $true
}
finally {
    if ($worktreeAdded -and $generationSucceeded) {
        & git -c "safe.directory=$safeRoot" -C $projectRoot worktree remove $sourceWorktree
        if ($LASTEXITCODE -ne 0) {
            throw "Fixture succeeded, but the detached worktree could not be removed: $sourceWorktree"
        }
    }
    elseif ($worktreeAdded) {
        Write-Warning "Generation failed; detached authority worktree retained at $sourceWorktree"
    }
}

Write-Output "A4-RNS-1 authority fixture: $fixtureDirectory"
