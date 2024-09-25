[CmdletBinding()]
param()

$PrevDir = Get-Location
Set-Location $PSScriptRoot

function LogInfo($Message)  { Write-Host ' INFO '  -Back Blue    -Fore Black -NoN; Write-Host " $Message" }
function LogDebug($Message) {
    if ($DebugPreference -eq 'SilentlyContinue') { return }
    Write-Host ' DEBUG ' -Back Green   -Fore Black -NoN; Write-Host " $Message"
}
function LogWarn($Message)  { Write-Host ' WARN '  -Back Yellow  -Fore Black -NoN; Write-Host " $Message" }
function LogError($Message) { Write-Host ' ERROR ' -Back Red     -Fore Black -NoN; Write-Host " $Message" }
function LogFatal($Message) { Write-Host ' FATAL ' -Back DarkRed -Fore Black -NoN; Write-Host " $Message" }

if ($null -eq (Get-Command 'curl' -ErrorAction SilentlyContinue)) {
    LogFatal('curl not found in PATH.')
}

LogInfo('Template Expansion Script')
LogInfo('-------------------------')
LogInfo('I have been summmoned to replace Ayame template variables in "./template/**" -- Stand by.')

LogInfo('Fetching Ayame definitions JSON.')
$AyameJsonPath = 'https://raw.githubusercontent.com/AyameTheme/Ayame/refs/heads/master/build/out/ayame.json'
$Response = curl -i $AyameJsonPath

if (-not $Response[0].Contains('200')) {
    LogFatal("Failed to load page: $Uri")
}
LogDebug("Response: $($Response[0])")
LogInfo('Fetch complete.')

$Response[0]  = ' '
$AyameJsonRaw = ($Response -join "`n").Trim()
$AyameJson    = ConvertFrom-Json $AyameJsonRaw.Substring($AyameJsonRaw.IndexOf('{')) -AsHashtable

LogDebug("Loaded ($($AyameJson.colors.Count)) colors.")

$DefAyame = @{
    ayame = $AyameJson
}

$Pattern = [regex] '\[{2}(ayame):(\w+(?:\.\w+)*)\]{2}'

$PathSource = Convert-Path '.\template'
$PathOutput = Convert-Path '.\'
$Templates  = Get-ChildItem -Path $PathSource -Recurse -Filter '*.ayame-template*'

LogInfo("Found ($($Templates.Count)) templates in '$PathSource'.")

foreach ($Template in $Templates) {
    $PathChild   = ($Template.FullName.Substring($PathSource.ToString().Length).Replace('.ayame-template', ''))
    $Destination = Join-Path $PathOutput $PathChild

    if ($Template.PSIsContainer) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    else {
        [int] $CountExpansions = 0
        $Content = Get-Content $Template.FullName
        for ($i = 0; $i -lt $Content.Length; $i++) {
            $Content[$i] = $Pattern.Replace($Content[$i], {
                param($Match)
                $Json   = $Match.Groups[1].Value
                $Key    = $Match.Groups[2].Value
                $Object = $DefAyame.$Json
                foreach ($SubKey in $Key.Split('.')) {
                    $Object = $Object.$SubKey
                }
                $Script:CountExpansions += 1
                if ($Object) {
                    LogDebug("'$PathChild' (Ln$($i + 1)): Expanding '$($Match.Groups[0].Value)' to '$Object'.")
                }
                else {
                    LogError("'$PathChild' (Ln$($i + 1)): Key not found: '$($Match.Groups[0].Value)'")
                }
                $Object
            })
        }
        New-Item (Split-Path $Destination -Parent) -ItemType Directory -Force | Out-Null
        $Content > $Destination
        LogInfo("Expanded ($CountExpansions) variables in '$Destination'.")
    }
}

Set-Location $PrevDir