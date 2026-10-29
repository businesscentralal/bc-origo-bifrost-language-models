# Alpaca reports HttpStatusCode 422 as "Status Code UnprocessableEntity".
# Business Central names the incoming version first and the published version second.
# A lost request can land on the server; the retry then sees the same package ID.
function global:Get-BifrostPublishRetryDecision {
    param(
        [Parameter(Mandatory)][string] $ErrorMessage,
        [Parameter(Mandatory)][int] $Tries,
        [Parameter(Mandatory)][int] $MaxTries
    )
    $is422 = $ErrorMessage -match '(?i)Status Code\s+(?:422|UnprocessableEntity)\b'
    $isDuplicate = $ErrorMessage -match 'duplicate package ID'
    if ($is422 -and $isDuplicate) {
        $versions = [regex]::Matches($ErrorMessage, "version:\s*'([^']*)'")
        if ($versions.Count -ge 2) {
            $incoming = $versions[0].Groups[1].Value
            $existing = $versions[1].Groups[1].Value
            if (-not [string]::IsNullOrWhiteSpace($incoming) -and ($incoming -ceq $existing)) {
                return 'Success'
            }
        }
    }
    if (($Tries + 1) -ge $MaxTries) { return 'Fail' }
    return 'Retry'
}

function Update-BifrostAlpacaPublishRetry {
    param([string] $ScriptsPath)
    $publishModule = Join-Path $ScriptsPath 'Modules/Publish-AlpacaBcApp.psm1'
    if (-not (Test-Path -LiteralPath $publishModule)) {
        throw 'Alpaca publish module is missing: cannot adapt the publish retry.'
    }
    $publishSource = [IO.File]::ReadAllText($publishModule)
    $newline = if ($publishSource.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalized = $publishSource.Replace("`r`n", "`n").Replace("`r", "`n")
    $marker = 'Get-BifrostPublishRetryDecision'
    $markerCount = [regex]::Matches($normalized, [regex]::Escape($marker)).Count
    if ($markerCount -gt 1) { throw 'Alpaca publish retry adaptation is present more than once.' }
    if ($markerCount -eq 1) { return }
    $anchor = @'
        catch {
            $errorMessage = "Error Publishing App '$appName'`n$_"

            $tries = $tries + 1
            if ($tries -ge $maxTries) {
                Write-AlpacaError $errorMessage
                throw "Error Publishing App '$appName'"
            }
            else {
                Write-AlpacaError $errorMessage -WithoutGitHubAnnotation
                Write-AlpacaOutput "Failed to publish app, retry after 15 sec"
                Start-Sleep 15
            }
        }
'@
    $replacement = @'
        catch {
            $errorMessage = "Error Publishing App '$appName'`n$_"
            $publishRetry = Get-BifrostPublishRetryDecision -ErrorMessage $errorMessage -Tries $tries -MaxTries $maxTries
            if ($publishRetry -eq 'Success') {
                Write-AlpacaOutput 'Already published: 422 duplicate package ID for the same version. Stopping retries.'
                Write-AlpacaOutput $errorMessage
                $success = $true
            }
            elseif ($publishRetry -eq 'Fail') {
                Write-AlpacaError $errorMessage
                throw "Error Publishing App '$appName'"
            }
            else {
                $tries = $tries + 1
                Write-AlpacaError $errorMessage -WithoutGitHubAnnotation
                Write-AlpacaOutput "Failed to publish app, retry after 15 sec"
                Start-Sleep 15
            }
        }
'@
    $anchor = $anchor.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
    $replacement = $replacement.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
    if ([regex]::Matches($normalized, [regex]::Escape($anchor)).Count -ne 1) {
        throw 'Alpaca publish retry changed: cannot safely treat a same-version duplicate package ID as success.'
    }
    $updated = $normalized.Replace($anchor, $replacement)
    if ($newline -eq "`r`n") { $updated = $updated.Replace("`n", "`r`n") }
    [IO.File]::WriteAllText($publishModule, $updated, [Text.UTF8Encoding]::new($false))
}

# Adapt container selection and the Alpaca publish retry. _buildMode/BuildMode, settings,
# dependency downloads, compilation and artifact names remain mode-specific.
# Called after downloading Alpaca v2.11.
function Initialize-BifrostSharedContainer {
    param([string] $OverridePath, [string] $ScriptsPath, [string] $BackendUrl)
    if ($env:_buildMode -notin @('Default', 'Test')) { throw 'Unsupported shared-container build mode.' }
    $env:ALPACA_BACKEND_URL = $BackendUrl
    # Patch the publish module before the first import. Alpaca imports it without -Force.
    Update-BifrostAlpacaPublishRetry -ScriptsPath $ScriptsPath
    Import-Module (Join-Path $ScriptsPath 'Modules/Alpaca.psd1') -Scope Global -DisableNameChecking
    $containers = @(Get-AlpacaContainer -Project $env:_project -Token $env:_token -BuildMode Default)
    if ($containers.Count -ne 1) { throw "Expected exactly one shared Default container; found $($containers.Count). Rerun all jobs to recreate the pair." }
    if ($env:_buildMode -eq 'Test' -and (!$env:BIFROST_EXPECTED_CONTAINER_ID -or $containers[0].Id -ne $env:BIFROST_EXPECTED_CONTAINER_ID)) {
        throw 'Test must reuse the physical container reported by Default. Rerun all jobs if it has been removed.'
    }
    $source = Get-Content -LiteralPath $OverridePath -Raw
    $assignment = '$buildMode = $env:_buildMode'
    if ([regex]::Matches($source, [regex]::Escape($assignment)).Count -ne 1) {
        throw 'Alpaca initialization changed: cannot safely adapt container selection.'
    }
    # This local variable is used only by the container lookup/creation in v2.11.
    # Dependency downloads read _buildMode separately and must continue to use Test.
    $source.Replace($assignment, '$buildMode = ''Default'' # Bifrost shared container') |
        Set-Content -LiteralPath $OverridePath -Encoding utf8
    $env:BIFROST_CONTAINER_ID = [string] $containers[0].Id
    $env:BIFROST_TEST_APP_PUBLISHED = ''
    if ($env:GITHUB_ENV) { Add-Content -Path $env:GITHUB_ENV -Value "BIFROST_CONTAINER_ID=$($env:BIFROST_CONTAINER_ID)" }
    Write-Host "Bifrost shared container: phase=$($env:_buildMode), id=$($env:BIFROST_CONTAINER_ID), container mode=Default."
}

function Read-BifrostCompiledManifest {
    param([string] $Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = -1
    for ($i = 0; $i -lt [Math]::Min($bytes.Length - 4, 65536); $i++) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i+1] -eq 0x4B -and $bytes[$i+2] -eq 3 -and $bytes[$i+3] -eq 4) { $offset = $i; break }
    }
    if ($offset -lt 0) { throw 'Compiled app has no readable NAVX archive.' }
    $stream = [IO.MemoryStream]::new($bytes, $offset, $bytes.Length - $offset, $false)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
    try {
        $entry = $zip.GetEntry('NavxManifest.xml')
        if (!$entry) { throw 'Compiled app has no NavxManifest.xml.' }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { return [xml] $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $zip.Dispose(); $stream.Dispose() }
}

function Invoke-BifrostSharedPublish {
    param([hashtable] $Parameters, [scriptblock] $Publisher)
    if ($env:_buildMode -ne 'Test') { Invoke-Command -ScriptBlock $Publisher -ArgumentList $Parameters; return }
    $mainAppId = 'f1722684-0c24-4022-a2e0-0f63154aca76'
    $testId = '9c452c6e-df9b-4eb0-9a54-7ea8f32483ec'
    # AL-Go calls this for dependencies, previous releases and compiled outputs.
    # Only the freshly compiled MainApp can authorize deploying our test app.
    $requested = @(GetAppInfo -AppFiles $Parameters.appFile -compilerFolder (GetCompilerFolder))
    $compiled = @($apps | Where-Object { $_ } | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
    $mainApp = @($requested | Where-Object { $_.Id -eq $mainAppId -and (Resolve-Path -LiteralPath $_.Path).Path -in $compiled })
    $containsTest = @($requested | Where-Object Id -EQ $testId).Count -gt 0
    if ($containsTest -and !$env:BIFROST_TEST_APP_PUBLISHED -and $mainApp.Count -eq 0) {
        throw 'Cannot publish the test app before republishing the freshly compiled Test MainApp.'
    }
    # Publish MainApp separately even if it shares a batch with the test app.
    foreach ($app in $mainApp) {
        $manifest = Read-BifrostCompiledManifest -Path $app.Path
        $grants = @($manifest.SelectNodes("//*[local-name()='InternalsVisibleTo']/*") | ForEach-Object { $_.GetAttribute('Id') })
        if ($testId -notin $grants) { throw 'Test MainApp is missing the compiled internalsVisibleTo grant.' }
        $mainAppParameters = $Parameters.Clone()
        $mainAppParameters.appFile = @($app.Path)
        $mainAppParameters.checkAlreadyInstalled = $false
        $mainAppParameters.ignoreIfAppExists = $false
        Write-Host "Bifrost: republishing Test MainApp $($app.Version) on shared container $($env:ALPACA_CONTAINER_ID), SHA256=$((Get-FileHash -LiteralPath $app.Path -Algorithm SHA256).Hash)."
        Invoke-Command -ScriptBlock $Publisher -ArgumentList $mainAppParameters
        $installed = @(Get-AlpacaAppInfo -Token $env:_token -ContainerName $env:ALPACA_CONTAINER_ID | Where-Object { $_.Id -eq $mainAppId -and [version] $_.Version -eq [version] $app.Version })
        if ($installed.Count -eq 0) { throw 'MainApp was not reported by the container after Test republish.' }
        $env:BIFROST_TEST_APP_PUBLISHED = $env:ALPACA_CONTAINER_ID
        Write-Host 'Bifrost: Test MainApp republish completed; the test app may now be deployed.'
    }
    if ($containsTest -and $env:BIFROST_TEST_APP_PUBLISHED -ne $env:ALPACA_CONTAINER_ID) { throw 'Test MainApp was republished on a different container.' }
    # Alpaca publishes output apps even at the same version via the developer endpoint.
    # Do not send MainApp twice when we have already published it above.
    $remaining = @($requested | Where-Object { $_ -notin $mainApp } | ForEach-Object Path)
    if ($remaining.Count -gt 0) {
        $remainingParameters = $Parameters.Clone()
        $remainingParameters.appFile = $remaining
        Invoke-Command -ScriptBlock $Publisher -ArgumentList $remainingParameters
    }
}
