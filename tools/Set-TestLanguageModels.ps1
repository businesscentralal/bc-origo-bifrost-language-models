<#
.SYNOPSIS
    Sets up the test language models (one per provider) on a development container and, optionally, runs one chat
    turn against each of them - without any API key passing through a file in a repository, a command line or a chat.

.DESCRIPTION
    The model definitions live in a JSON file OUTSIDE every repository (default
    %USERPROFILE%\.bifrost\test-language-models.json). It holds no key, only where to find it:

        [
          { "code": "BIFT-OPENAI", "chatProvider": "OpenAI", "model": "gpt-4.1-mini",
            "contextTokens": 128000, "apiKey": { "secret": "bifrost-test-openai" } },
          { "code": "BIFT-CLAUDE", "chatProvider": "Anthropic", "model": "claude-sonnet-4-6",
            "apiKey": { "env": "BIFROST_TEST_ANTHROPIC_KEY" } },
          { "code": "BIFT-LOCAL", "chatProvider": "Custom LLM", "baseUrl": "https://llm.example.invalid",
            "chatPath": "/v1/chat/completions", "model": "qwen3", "contextTokens": 32000,
            "apiKey": { "secret": "bifrost-test-local" } },
          { "code": "BIFT-COPILOT", "chatProvider": "Copilot" }
        ]

    Every other property of an entry (description, baseUrl, chatPath, modelsPath, timeoutSeconds, maxTokens,
    contextTokens, default, skill) is passed on to the test message type Test.LanguageModel.Set as it is.
    "apiKey" is resolved on this machine and sent as "sharedApiKey" (add "keyScope": "personal" to send it as
    "personalApiKey" instead):

      { "secret": "<name>" }  - a secret in the default PowerShell SecretManagement vault (recommended:
                                Microsoft.PowerShell.SecretStore, encrypted at rest). Store it once with
                                Set-Secret -Name <name>   (the value is prompted for, not typed on the command line).
      { "env": "<NAME>" }     - a user-level environment variable, set once with
                                [Environment]::SetEnvironmentVariable('<NAME>', (Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText), 'User')

    The request goes straight from this machine to the container's Bifrost task API over HTTPS. The test type
    redacts the request in the message queue before storing the key in Foundation's secret store, and answers only
    whether each key is stored. This script never prints a key.

    With -ChatOnly, the models are not set up and no key is read (the vault is not opened): only the chat turns run.

    With -Chat, Test.LanguageModel.Chat runs one turn (tool calls included) against every model in the file and prints
    the provider, the number of tool rounds, the tools called and the reply.

    The container connection comes from app/.vscode/launch.json (git-ignored) and the credential from the user-level
    environment variables BC28IS_USER / BC28IS_PASSWORD, like tools in bc-origo-bifrost-core.

.EXAMPLE
    ./tools/Set-TestLanguageModels.ps1 -LaunchConfiguration 'launch: bc28-is'
    ./tools/Set-TestLanguageModels.ps1 -LaunchConfiguration 'launch: bc28-w1' -Chat -Prompt 'How many customers are there?'
    ./tools/Set-TestLanguageModels.ps1 -Remove
#>
[CmdletBinding()]
param(
    [string]$ConfigFile = (Join-Path $env:USERPROFILE '.bifrost\test-language-models.json'),
    [string]$LaunchJson = (Join-Path $PSScriptRoot '..\app\.vscode\launch.json'),
    [string]$LaunchConfiguration = 'launch: bc28-w1',
    [string]$CompanyName,
    [switch]$Chat,
    [switch]$ChatOnly,
    [string]$Prompt = 'How many customers are there, and what is the balance of the first one? Use the tools.',
    [switch]$Remove,
    [string]$UserVariable = 'BC28IS_USER',
    [string]$PasswordVariable = 'BC28IS_PASSWORD'
)

$ErrorActionPreference = 'Stop'

function Get-UserEnv([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value) { $value = [Environment]::GetEnvironmentVariable($Name, 'User') }
    return $value
}

function Resolve-ApiKey($ApiKey, [string]$ModelCode) {
    # A key that is not there yet is skipped with a warning, so keys can be added one provider at a time.
    if ($ApiKey.secret) {
        if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
            throw "$ModelCode : apiKey.secret needs the Microsoft.PowerShell.SecretManagement module (Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore)."
        }
        $value = Get-Secret -Name $ApiKey.secret -AsPlainText -ErrorAction SilentlyContinue
        if (-not $value) { Write-Warning "$ModelCode : no secret '$($ApiKey.secret)' in the vault; the key is left as it is." }
        return $value
    }
    if ($ApiKey.env) {
        $value = Get-UserEnv $ApiKey.env
        if (-not $value) { Write-Warning "$ModelCode : the environment variable $($ApiKey.env) is not set; the key is left as it is." }
        return $value
    }
    throw "$ModelCode : apiKey needs 'secret' or 'env'."
}

# --- connection -------------------------------------------------------------------------------------------------
if (-not (Test-Path $LaunchJson)) { throw "launch.json not found: $LaunchJson" }
$cfg = ((Get-Content $LaunchJson -Raw) -replace '(?m)^\s*//.*$', '' | ConvertFrom-Json).configurations |
    Where-Object { $_.request -eq 'launch' -and $_.name -eq $LaunchConfiguration } | Select-Object -First 1
if (-not $cfg) { throw "No launch configuration named '$LaunchConfiguration' in $LaunchJson." }
$instance = $cfg.serverInstance -replace 'dev$', 'rest'
$base = "$($cfg.server.TrimEnd('/'))/$instance"
$user = Get-UserEnv $UserVariable
$pass = Get-UserEnv $PasswordVariable
if (-not $user -or -not $pass) { throw "Set the user-level environment variables $UserVariable and $PasswordVariable first." }
$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$user`:$pass")) }

$companies = (Invoke-RestMethod -Uri "$base/api/microsoft/automation/v2.0/companies?tenant=default" -Headers $headers).value
$company = if ($CompanyName) { $companies | Where-Object name -eq $CompanyName | Select-Object -First 1 } else { $companies | Select-Object -First 1 }
if (-not $company) { throw "Company '$CompanyName' not found on $LaunchConfiguration." }
$api = "$base/api/origo/bifrost/v1.0/companies($($company.id))"
Write-Host "Target: $LaunchConfiguration ($($company.name))"

function Invoke-BifrostType([string]$Type, $Data) {
    $id = [guid]::NewGuid().ToString()
    $envelope = @{
        specversion     = '1.0'
        type            = $Type
        source          = 'Set-TestLanguageModels'
        id              = $id
        datacontenttype = 'application/json'
        data            = ($Data | ConvertTo-Json -Depth 20 -Compress)
    } | ConvertTo-Json -Compress
    $null = Invoke-RestMethod -Method Post -Uri "$api/tasks?tenant=default" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($envelope))
    $answer = Invoke-WebRequest -Uri "$api/responses($id)/data?tenant=default" -Headers $headers
    return ([Text.Encoding]::UTF8.GetString($answer.RawContentStream.ToArray()) | ConvertFrom-Json)
}

# --- models -----------------------------------------------------------------------------------------------------
if (-not (Test-Path $ConfigFile)) { throw "Config file not found: $ConfigFile (see Get-Help $PSCommandPath -Full)." }
$entries = @(Get-Content $ConfigFile -Raw | ConvertFrom-Json)

if ($Remove) {
    $answer = Invoke-BifrostType 'Test.LanguageModel.Delete' @{ codes = @($entries | ForEach-Object code) }
    Write-Host "Deleted: $($answer.deleted -join ', ')   Not found: $($answer.notFound -join ', ')"
    return
}

if ($ChatOnly) { $Chat = $true }
$models = if ($ChatOnly) { @() } else { foreach ($entry in $entries) {
    $model = [ordered]@{}
    foreach ($p in $entry.PSObject.Properties) {
        if ($p.Name -notin 'apiKey', 'keyScope') { $model[$p.Name] = $p.Value }
    }
    if ($entry.apiKey) {
        $keyName = if ($entry.keyScope -eq 'personal') { 'personalApiKey' } else { 'sharedApiKey' }
        $keyValue = Resolve-ApiKey $entry.apiKey $entry.code
        if ($keyValue) { $model[$keyName] = $keyValue }
        $keyValue = $null
    }
    $model
} }
if (-not $ChatOnly) {
    $answer = Invoke-BifrostType 'Test.LanguageModel.Set' @{ models = @($models) }
    $models = $null
    if ($answer.status -ne 'Success') { throw "Test.LanguageModel.Set: $($answer.error) $($answer.errors | ConvertTo-Json -Compress)" }
    $answer.models | Select-Object code, chatProvider, model, effectiveContextTokens, sharedKeyStored, personalKeyStored | Format-Table -AutoSize | Out-Host
}

# --- chat -------------------------------------------------------------------------------------------------------
if ($Chat) {
    foreach ($entry in $entries) {
        $result = Invoke-BifrostType 'Test.LanguageModel.Chat' @{ code = $entry.code; prompt = $Prompt }
        Write-Host "== $($entry.code)"
        if ($result.status -ne 'Success') {
            Write-Host "   ERROR [$($result.code)] $($result.error)"
            continue
        }
        $tools = @($result.toolCalls | ForEach-Object { if ($_.isError) { "$($_.name)!" } else { $_.name } })
        if ($result.providerToolTrace) { $tools += @($result.providerToolTrace | ForEach-Object { $_.name }) }
        Write-Host "   provider $($result.chatProvider), tool rounds $($result.rounds), tools: $($tools -join ', ')"
        Write-Host "   reply: $($result.reply)"
    }
}
