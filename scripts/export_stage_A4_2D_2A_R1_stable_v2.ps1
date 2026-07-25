param(
    [Parameter(Mandatory = $true)]
    [string]$SourceCommit
)

$ErrorActionPreference = "Stop"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDirectory "..")).Path
$safeRoot = $projectRoot.Replace("\", "/")
$toolingCommit = (& git -c "safe.directory=$safeRoot" -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $toolingCommit.Length -ne 40) {
    throw "Unable to determine the R1 tooling commit."
}
if ($SourceCommit -ne $toolingCommit) {
    throw "R1 source commit must equal the clean tooling HEAD."
}
$trackedStatus = & git -c "safe.directory=$safeRoot" -C $projectRoot status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($trackedStatus -join ""))) {
    throw "Tracked worktree changes are not allowed while exporting R1 evidence."
}

$outputDirectory = Join-Path $projectRoot "tests\fixtures\stage_A4_2D_2A_R1_stable_v2"
if (Test-Path -LiteralPath $outputDirectory) {
    throw "Refusing to overwrite R1 stable-v2 evidence: $outputDirectory"
}
$escapedRoot = $projectRoot.Replace("'", "''")
$escapedOutput = $outputDirectory.Replace("'", "''")
$batch = "addpath('$escapedRoot');" +
    "addpath('$escapedRoot\tests');" +
    "addpath(genpath('$escapedRoot\src'));" +
    "r1Result=main_stage_A4_2D_2A_R1();" +
    "r1Tests=run_stage_A4_2D_2A_R1_tests(PrecomputedResult=r1Result);" +
    "evidence=export_stage_a4_2d_2a_r1_stable_v2_evidence(" +
    "'$escapedRoot','$escapedOutput',Result=r1Result," +
    "TestEvidence=r1Tests,SourceCommit='$SourceCommit'," +
    "ToolingCommit='$toolingCommit');" +
    "assert(evidence.all_pass);"

try {
    & matlab -batch $batch
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB R1 stable-v2 evidence export failed."
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

Write-Output "A4-2D-2A-R1 stable-v2 evidence: $outputDirectory"
