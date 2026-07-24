param(
    [string]$ImplementationCommit = "7bbecd32449739ebd04133c661b602b18b7bd4e1"
)

$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..")).Path
$safeRoot = $projectRoot.Replace("\", "/")
$toolingCommit = (& git -c "safe.directory=$safeRoot" -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $toolingCommit.Length -ne 40) {
    throw "Unable to determine the stable-evidence tooling commit."
}
$trackedStatus = & git -c "safe.directory=$safeRoot" -C $projectRoot status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($trackedStatus -join ""))) {
    throw "Tracked worktree changes are not allowed while exporting stable-v2 evidence."
}
& git -c "safe.directory=$safeRoot" -C $projectRoot merge-base --is-ancestor $ImplementationCommit HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Implementation commit $ImplementationCommit is not an ancestor of tooling HEAD."
}

$outputDirectory = Join-Path $projectRoot "tests\fixtures\stage_A4_RNS_1_stable_v2"
if (Test-Path -LiteralPath $outputDirectory) {
    throw "Refusing to overwrite stable-v2 evidence: $outputDirectory"
}
$escapedRoot = $projectRoot.Replace("'", "''")
$escapedOutput = $outputDirectory.Replace("'", "''")
$batch = "addpath(genpath('$escapedRoot\src'));" +
    "result=export_stage_a4_rns1_stable_v2_evidence(" +
    "'$escapedRoot','$escapedOutput'," +
    "ImplementationCommit='$ImplementationCommit'," +
    "ToolingCommit='$toolingCommit');assert(result.all_pass);"

try {
    & matlab -batch $batch
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB stable-v2 evidence export failed."
    }
}
finally {
    $stagingDirectory = "$outputDirectory.building"
    if (Test-Path -LiteralPath $stagingDirectory) {
        $fixtureParent = [System.IO.Path]::GetFullPath(
            (Split-Path -Parent $outputDirectory)
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
}

Write-Output "A4-RNS-1 stable-v2 evidence: $outputDirectory"
