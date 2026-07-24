param(
    [string]$SourceCommit = "58b2b3645b79c71460ff0de1a03033c319829cd6",
    [string]$ExpectedToolingCommit = ""
)

$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..")).Path
$safeRoot = $projectRoot.Replace("\", "/")
$toolingCommit = (& git -c "safe.directory=$safeRoot" -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $toolingCommit.Length -ne 40) {
    throw "Unable to determine the tooling commit."
}
if ([string]::IsNullOrWhiteSpace($ExpectedToolingCommit)) {
    $ExpectedToolingCommit = $toolingCommit
}
if ($toolingCommit -ne $ExpectedToolingCommit) {
    throw "Tooling HEAD $toolingCommit differs from expected $ExpectedToolingCommit."
}
$toolingPaths = @(
    "scripts/generate_stage_A4_RNS_1_fixture.ps1",
    "src/diagnostics/generate_stage_a4_rns1_stress_fixture.m",
    "src/diagnostics/compute_stage_a4_rns1_fingerprint.m"
)
& git -c "safe.directory=$safeRoot" -C $projectRoot diff --quiet HEAD -- $toolingPaths
if ($LASTEXITCODE -ne 0) {
    throw "The replay tooling has uncommitted working-tree changes."
}
& git -c "safe.directory=$safeRoot" -C $projectRoot diff --cached --quiet HEAD -- $toolingPaths
if ($LASTEXITCODE -ne 0) {
    throw "The replay tooling has staged changes not present in tooling HEAD."
}

$fixtureDirectory = Join-Path $projectRoot "tests\fixtures\stage_A4_RNS_1_authority_v1"
if (Test-Path -LiteralPath $fixtureDirectory) {
    throw "Refusing to overwrite the authority fixture: $fixtureDirectory"
}

$tempParent = [System.IO.Path]::GetTempPath()
$tempName = "Hourly_Recursive_KKT_A4_RNS_1_" + [Guid]::NewGuid().ToString("N")
$sourceWorktree = Join-Path $tempParent $tempName
$worktreeAdded = $false
$stagingDirectory = "$fixtureDirectory.building"

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
}
finally {
    if (Test-Path -LiteralPath $stagingDirectory) {
        $fixtureParent = [System.IO.Path]::GetFullPath(
            (Split-Path -Parent $fixtureDirectory)
        )
        $resolvedStaging = [System.IO.Path]::GetFullPath($stagingDirectory)
        $requiredPrefix = $fixtureParent.TrimEnd("\") + "\"
        if (-not $resolvedStaging.StartsWith(
                $requiredPrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -or -not $resolvedStaging.EndsWith(".building")) {
            throw "Refusing to clean an unsafe staging path: $resolvedStaging"
        }
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
    if ($worktreeAdded) {
        & git -c "safe.directory=$safeRoot" -C $projectRoot worktree remove --force $sourceWorktree
        if ($LASTEXITCODE -ne 0) {
            throw "The detached authority worktree could not be removed: $sourceWorktree"
        }
    }
}

Write-Output "A4-RNS-1 authority fixture: $fixtureDirectory"
