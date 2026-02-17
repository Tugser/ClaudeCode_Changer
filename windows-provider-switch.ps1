#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$SERVICE = 'claude-provider-shell'
$CLAUDE_HOME = Join-Path $env:USERPROFILE '.claude'
$SettingsPath = Join-Path $CLAUDE_HOME 'settings.json'
$BACKUP = Join-Path $CLAUDE_HOME 'anthropic.backup.json'
$CONFIG = Join-Path $CLAUDE_HOME 'provider-config.json'

if (-not (Test-Path $CLAUDE_HOME)) {
  New-Item -ItemType Directory -Path $CLAUDE_HOME | Out-Null
}

if (-not ('CredMan' -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class CredMan
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, uint type, uint reservedFlag, out IntPtr credentialPtr);

    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredWrite([In] ref CREDENTIAL userCredential, [In] uint flags);

    [DllImport("Advapi32.dll", SetLastError = true)]
    public static extern bool CredFree([In] IntPtr cred);

    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredDelete(string target, uint type, uint flags);
}
"@
}

$CRED_TYPE_GENERIC = 1
$CRED_PERSIST_LOCAL_MACHINE = 2

$GLM_MODEL_KEYS = @(
  'ANTHROPIC_MODEL',
  'ANTHROPIC_SMALL_FAST_MODEL',
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL'
)

$Translations = @{
  tr = @{
    LangSelectTitle = 'Dil secin / Choose language:'
    LangOption1 = '1) Turkce'
    LangOption2 = '2) English'
    LangPrompt = 'Secim / Choice'

    MenuTitle = 'Claude Code Saglayici Menusu (Windows)'
    Menu1 = '1) GLM API key ekle/guncelle'
    Menu2 = '2) MiniMax API key ekle/guncelle'
    Menu3 = '3) Saglayiciyi aktif et (Anthropic/GLM/MiniMax)'
    Menu4 = '4) Anthropic yedek al'
    Menu5 = '5) Anthropic yedegini geri yukle'
    Menu6 = '6) Saglayicilari listele'
    Menu7 = '7) Doctor (env kontrol)'
    Menu8 = '8) Test (curl ping)'
    Menu9 = '9) Dil degistir'
    Menu0 = '0) Cikis'
    PromptChoice = 'Secim'

    PromptMinimaxAuthHeader = 'MiniMax auth header (x-api-key/Authorization) [{0}]'
    PromptMinimaxApiKeyRequired = 'MiniMax API key (zorunlu)'
    PromptMinimaxApiKey = 'MiniMax API key'
    PromptGlmApiKeyRequired = 'GLM API key (zorunlu)'
    PromptGlmApiKey = 'GLM API key'

    MsgExistingMinimax = 'Mevcut MiniMax key bulundu (bos gecersen aynisi korunur).'
    MsgExistingGlm = 'Mevcut GLM key bulundu (bos gecersen aynisi korunur).'
    MsgEmptyKey = 'Bos key girildi, yazilmadi.'
    MsgInvalidMinimax = 'MiniMax API key gecersiz (ASCII olmayan karakter veya bosluk var). Lutfen yeniden girin.'
    MsgInvalidGlm = 'GLM API key gecersiz (ASCII olmayan karakter veya bosluk var). Lutfen yeniden girin.'
    MsgInvalidDetail = 'Detay: {0}'

    MsgSettingsWritten = 'settings.json yazildi -> {0}'
    MsgSettingsUpdated = 'settings.json guncellendi -> {0}'
    MsgEnvOverrideNote = 'Not: Ortam degiskenleri (ANTHROPIC_AUTH_TOKEN/BASE_URL) varsa settings.json''i override eder.'

    MsgActiveBase = 'Aktif base_url: {0}'
    MsgActiveToken = 'Aktif token: {0}'
    MsgActiveTokenNone = 'Aktif token: yok'

    MsgMinimaxKeyNotFound = 'MiniMax API key bulunamadi. Once menu 2 ile key ekleyin.'
    MsgGlmKeyNotFound = 'GLM API key bulunamadi. Once menu 1 ile key ekleyin.'

    MsgAnthropicBackupTaken = 'Anthropic yedegi alindi -> {0}'
    MsgAnthropicRestored = 'Anthropic yedegi geri yuklendi -> {0}'
    MsgSettingsMissing = 'settings.json bulunamadi, yedek alinmadi.'
    MsgBackupNotFound = 'Yedek bulunamadi: {0}'
    MsgAnthropicOverrideCleared = 'Anthropic icin provider override temizlendi.'

    MsgListTitle = 'Kayitli sirlar (Credential Manager):'
    MsgListGlm = '- glm (api key)'
    MsgListMinimax = '- minimax (api key)'
    MsgListAnthropic = '- anthropic (token)'
    MsgMinimaxAuthHeader = 'MiniMax auth header: {0}'

    MsgDoctorConflict = 'Uyari: Ortam degiskenleri settings.json''i override eder: {0}'
    MsgDoctorNoConflict = 'Env cakismasi yok.'
    MsgSettingsExists = 'settings.json mevcut: {0}'
    MsgSettingsNotExists = 'settings.json yok.'

    MsgTestNoSettings = 'settings.json yok, once provider sec.'
    MsgTestNoToken = 'Token yok, test yapilamiyor.'
    MsgTestPing = 'Ping: {0}'
    MsgTestHttp = 'HTTP kodu: {0} (401/403 ise key hatasi, 404 olabilir, 000/curl_error baglanti sorunu)'
    MsgTestBaseFallback = 'Base URL bulunamadi (Anthropic default olabilir, yine de deneyelim).'
    MsgLanguageSet = 'Dil ayarlandi: {0}'

    ProviderPrompt = 'Secim'
    ProviderAnthropic = '1) Anthropic'
    ProviderGlm = '2) GLM'
    ProviderMinimax = '3) MiniMax'
  }
  en = @{
    LangSelectTitle = 'Dil secin / Choose language:'
    LangOption1 = '1) Turkce'
    LangOption2 = '2) English'
    LangPrompt = 'Secim / Choice'

    MenuTitle = 'Claude Code Provider Menu (Windows)'
    Menu1 = '1) Add/update GLM API key'
    Menu2 = '2) Add/update MiniMax API key'
    Menu3 = '3) Activate provider (Anthropic/GLM/MiniMax)'
    Menu4 = '4) Backup Anthropic'
    Menu5 = '5) Restore Anthropic backup'
    Menu6 = '6) List providers'
    Menu7 = '7) Doctor (env check)'
    Menu8 = '8) Test (curl ping)'
    Menu9 = '9) Change language'
    Menu0 = '0) Exit'
    PromptChoice = 'Choice'

    PromptMinimaxAuthHeader = 'MiniMax auth header (x-api-key/Authorization) [{0}]'
    PromptMinimaxApiKeyRequired = 'MiniMax API key (required)'
    PromptMinimaxApiKey = 'MiniMax API key'
    PromptGlmApiKeyRequired = 'GLM API key (required)'
    PromptGlmApiKey = 'GLM API key'

    MsgExistingMinimax = 'Existing MiniMax key found (leave blank to keep).'
    MsgExistingGlm = 'Existing GLM key found (leave blank to keep).'
    MsgEmptyKey = 'Empty key entered, not saved.'
    MsgInvalidMinimax = 'MiniMax API key invalid (non-ASCII or whitespace). Please re-enter.'
    MsgInvalidGlm = 'GLM API key invalid (non-ASCII or whitespace). Please re-enter.'
    MsgInvalidDetail = 'Detail: {0}'

    MsgSettingsWritten = 'settings.json written -> {0}'
    MsgSettingsUpdated = 'settings.json updated -> {0}'
    MsgEnvOverrideNote = 'Note: Environment variables (ANTHROPIC_AUTH_TOKEN/BASE_URL) override settings.json.'

    MsgActiveBase = 'Active base_url: {0}'
    MsgActiveToken = 'Active token: {0}'
    MsgActiveTokenNone = 'Active token: none'

    MsgMinimaxKeyNotFound = 'MiniMax API key not found. Add it via menu 2 first.'
    MsgGlmKeyNotFound = 'GLM API key not found. Add it via menu 1 first.'

    MsgAnthropicBackupTaken = 'Anthropic backup saved -> {0}'
    MsgAnthropicRestored = 'Anthropic backup restored -> {0}'
    MsgSettingsMissing = 'settings.json not found, backup not taken.'
    MsgBackupNotFound = 'Backup not found: {0}'
    MsgAnthropicOverrideCleared = 'Provider overrides cleared for Anthropic.'

    MsgListTitle = 'Stored secrets (Credential Manager):'
    MsgListGlm = '- glm (api key)'
    MsgListMinimax = '- minimax (api key)'
    MsgListAnthropic = '- anthropic (token)'
    MsgMinimaxAuthHeader = 'MiniMax auth header: {0}'

    MsgDoctorConflict = 'Warning: Environment variables override settings.json: {0}'
    MsgDoctorNoConflict = 'No env conflicts.'
    MsgSettingsExists = 'settings.json present: {0}'
    MsgSettingsNotExists = 'settings.json missing.'

    MsgTestNoSettings = 'settings.json missing, select a provider first.'
    MsgTestNoToken = 'Token missing, cannot test.'
    MsgTestPing = 'Ping: {0}'
    MsgTestHttp = 'HTTP code: {0} (401/403 key error, 404 may be OK, 000/curl_error connection issue)'
    MsgTestBaseFallback = 'Base URL not found (Anthropic default may apply, trying anyway).'
    MsgLanguageSet = 'Language set: {0}'

    ProviderPrompt = 'Choice'
    ProviderAnthropic = '1) Anthropic'
    ProviderGlm = '2) GLM'
    ProviderMinimax = '3) MiniMax'
  }
}

function T {
  param(
    [string]$key,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$fmtArgs
  )
  $lang = $script:Lang
  if ([string]::IsNullOrEmpty($lang)) { $lang = 'tr' }
  $msg = $Translations[$lang][$key]
  if ($null -ne $fmtArgs -and $fmtArgs.Count -gt 0) {
    return ($msg -f $fmtArgs)
  }
  return $msg
}

function Select-Language {
  while ($true) {
    Write-Host 'Dil / Language secimi (en/tr):'
    Write-Host '1) Turkce (tr)'
    Write-Host '2) English (en)'
    $choice = Read-Host 'Dil / Language secimi [tr]'
    if ([string]::IsNullOrEmpty($choice)) { return 'tr' }
    $c = $choice.ToLowerInvariant()
    switch ($c) {
      '1' { return 'tr' }
      'tr' { return 'tr' }
      'turkce' { return 'tr' }
      'turkish' { return 'tr' }
      '2' { return 'en' }
      'en' { return 'en' }
      'english' { return 'en' }
      default { Write-Host 'Gecersiz secim / Invalid choice. 1/2 or tr/en.' }
    }
  }
}

function Get-CredTarget([string]$account) {
  return "${SERVICE}:$account"
}

function Store-Secret([string]$account, [string]$value) {
  $target = Get-CredTarget $account
  $bytes = [Text.Encoding]::Unicode.GetBytes($value)
  $cred = New-Object CredMan+CREDENTIAL
  $cred.Type = $CRED_TYPE_GENERIC
  $cred.TargetName = $target
  $cred.CredentialBlobSize = $bytes.Length
  $cred.Persist = $CRED_PERSIST_LOCAL_MACHINE
  $cred.CredentialBlob = [Runtime.InteropServices.Marshal]::AllocCoTaskMem($bytes.Length)
  try {
    [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $cred.CredentialBlob, $bytes.Length)
    if (-not [CredMan]::CredWrite([ref]$cred, 0)) {
      throw "CredWrite failed"
    }
  } finally {
    if ($cred.CredentialBlob -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::FreeCoTaskMem($cred.CredentialBlob)
    }
  }
}

function Read-Secret([string]$account) {
  $target = Get-CredTarget $account
  $ptr = [IntPtr]::Zero
  $ok = [CredMan]::CredRead($target, $CRED_TYPE_GENERIC, 0, [ref]$ptr)
  if (-not $ok) {
    return ''
  }
  try {
    $cred = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][CredMan+CREDENTIAL])
    if ($cred.CredentialBlobSize -le 0 -or $cred.CredentialBlob -eq [IntPtr]::Zero) {
      return ''
    }
    $bytes = New-Object byte[] $cred.CredentialBlobSize
    [Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $bytes, 0, $bytes.Length)
    $secret = [Text.Encoding]::Unicode.GetString($bytes)
    return $secret.TrimEnd([char]0)
  } finally {
    [CredMan]::CredFree($ptr) | Out-Null
  }
}

function Cred-Exists([string]$account) {
  $target = Get-CredTarget $account
  $ptr = [IntPtr]::Zero
  $ok = [CredMan]::CredRead($target, $CRED_TYPE_GENERIC, 0, [ref]$ptr)
  if ($ok) {
    [CredMan]::CredFree($ptr) | Out-Null
    return $true
  }
  return $false
}

function Read-SecretPrompt([string]$prompt) {
  $sec = Read-Host -AsSecureString $prompt
  if ($null -eq $sec) {
    return ''
  }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Sanitize-Token([string]$raw) {
  $script:TokenDiag = $null
  if ($null -eq $raw) {
    $script:TokenDiag = 'null input'
    return $null
  }

  $origLen = $raw.Length
  $raw = $raw.Trim()
  $trimmed = $origLen - $raw.Length

  $bearerRemoved = $false
  if ($raw -match '^(?i)bearer\s+') {
    $bearerRemoved = $true
    $raw = $raw -replace '^(?i)bearer\s+', ''
  }

  # Remove whitespace and hidden format/control chars introduced by copy/paste
  $wsRemoved = ([regex]::Matches($raw, '\s')).Count
  if ($wsRemoved -gt 0) { $raw = $raw -replace '\s+', '' }
  $cfRemoved = ([regex]::Matches($raw, '\p{Cf}')).Count
  if ($cfRemoved -gt 0) { $raw = $raw -replace '\p{Cf}', '' }
  $ccRemoved = ([regex]::Matches($raw, '\p{Cc}')).Count
  if ($ccRemoved -gt 0) { $raw = $raw -replace '\p{Cc}', '' }

  if ([string]::IsNullOrEmpty($raw)) {
    $script:TokenDiag = "empty after strip (trim=$trimmed ws=$wsRemoved cf=$cfRemoved cc=$ccRemoved bearer=$bearerRemoved)"
    return $null
  }

  # Detect any remaining non-ASCII
  $bad = @()
  for ($i = 0; $i -lt $raw.Length; $i++) {
    $code = [int][char]$raw[$i]
    if ($code -lt 0x20 -or $code -gt 0x7E) {
      $bad += $code
    }
  }
  if ($bad.Count -gt 0) {
    $uniq = $bad | Sort-Object -Unique
    $codes = ($uniq | ForEach-Object { 'U+' + $_.ToString('X4') }) -join ', '
    $script:TokenDiag = "non-ascii: $codes (trim=$trimmed ws=$wsRemoved cf=$cfRemoved cc=$ccRemoved bearer=$bearerRemoved)"
    return $null
  }

  return $raw
}

function Show-TokenInvalidDetail {
  if (-not [string]::IsNullOrEmpty($script:TokenDiag)) {
    Write-Host (T 'MsgInvalidDetail' $script:TokenDiag)
  }
}

function Ensure-SettingsJson {
  if (-not (Test-Path $SettingsPath)) {
    $obj = [ordered]@{ env = [ordered]@{} }
    $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath -Encoding UTF8
  }
}

function Load-Settings {
  if (-not (Test-Path $SettingsPath)) { return $null }
  try {
    $raw = Get-Content -Path $SettingsPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-Settings($settings) {
  $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath -Encoding UTF8
}

function Settings-CanMerge {
  Ensure-SettingsJson
  $settings = Load-Settings
  return ($null -ne $settings)
}

function Set-EnvValue($settings, [string]$key, $value) {
  if ($null -eq $settings.env) {
    $settings | Add-Member -MemberType NoteProperty -Name env -Value ([ordered]@{})
  }
  $settings.env | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
}

function Remove-EnvKey($settings, [string]$key) {
  if ($null -eq $settings -or $null -eq $settings.env) { return }
  $settings.env.PSObject.Properties.Remove($key) | Out-Null
}

function Load-Config {
  if (-not (Test-Path $CONFIG)) { return @{} }
  try {
    $cfg = Get-Content -Path $CONFIG -Raw | ConvertFrom-Json
    if ($null -eq $cfg) { return @{} }
    return $cfg
  } catch {
    return @{}
  }
}

function Save-Config($cfg) {
  $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $CONFIG -Encoding UTF8
}

function Load-AuthHeader {
  $cfg = Load-Config
  if ($null -ne $cfg.minimax_auth_header) {
    return [string]$cfg.minimax_auth_header
  }
  return ''
}

function Save-AuthHeader([string]$authHeader) {
  $cfg = Load-Config
  if ($cfg -is [hashtable]) {
    $cfg['minimax_auth_header'] = $authHeader
  } else {
    $cfg | Add-Member -MemberType NoteProperty -Name minimax_auth_header -Value $authHeader -Force
  }
  Save-Config $cfg
}

function Load-Language {
  $cfg = Load-Config
  if ($null -ne $cfg.language) {
    return [string]$cfg.language
  }
  return ''
}

function Save-Language([string]$lang) {
  $cfg = Load-Config
  if ($cfg -is [hashtable]) {
    $cfg['language'] = $lang
  } else {
    $cfg | Add-Member -MemberType NoteProperty -Name language -Value $lang -Force
  }
  Save-Config $cfg
}

$script:Lang = Load-Language
if ($script:Lang -ne 'tr' -and $script:Lang -ne 'en') {
  $script:Lang = 'en'
}

function Get-EnvValue([string]$key) {
  $settings = Load-Settings
  if ($null -eq $settings -or $null -eq $settings.env) { return '' }
  $prop = $settings.env.PSObject.Properties[$key]
  if ($null -eq $prop) { return '' }
  return [string]$prop.Value
}

function Mask-Token([string]$token) {
  if ([string]::IsNullOrEmpty($token)) { return '' }
  return ($token -replace '.', '*')
}

function Current-Summary {
  $base = Get-EnvValue 'ANTHROPIC_BASE_URL'
  $auth = Get-EnvValue 'ANTHROPIC_AUTH_TOKEN'
  if ([string]::IsNullOrEmpty($base)) { $base = '(yok)' }
  Write-Host (T 'MsgActiveBase' $base)
  if (-not [string]::IsNullOrEmpty($auth)) {
    Write-Host (T 'MsgActiveToken' (Mask-Token $auth))
  } else {
    Write-Host (T 'MsgActiveTokenNone')
  }
}

function Maybe-BackupAnthropic {
  if ((Test-Path $BACKUP) -or -not (Test-Path $SettingsPath)) { return }
  $base = Get-EnvValue 'ANTHROPIC_BASE_URL'
  if ([string]::IsNullOrEmpty($base) -or $base -eq 'https://api.anthropic.com') {
    Copy-Item $SettingsPath $BACKUP
    Write-Host (T 'MsgAnthropicBackupTaken' $BACKUP)
  }
}

function Clear-ProviderOverrides {
  if (-not (Test-Path $SettingsPath)) { return }
  $settings = Load-Settings
  if ($null -eq $settings) {
    Remove-Item $SettingsPath -ErrorAction SilentlyContinue
    return
  }
  foreach ($key in @(
    'ANTHROPIC_BASE_URL',
    'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_AUTH_HEADER',
    'API_TIMEOUT_MS',
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
    'ANTHROPIC_MODEL',
    'ANTHROPIC_SMALL_FAST_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'
  )) {
    Remove-EnvKey $settings $key
  }
  Save-Settings $settings
}

function Write-EnvJson([hashtable]$env) {
  $obj = [ordered]@{ env = $env }
  $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath -Encoding UTF8
  Write-Host (T 'MsgSettingsWritten' $SettingsPath)
  Write-Host (T 'MsgEnvOverrideNote')
}

function Update-Settings([hashtable]$env, [string[]]$removeKeys) {
  if (-not (Settings-CanMerge)) {
    Write-EnvJson $env
    return
  }
  $settings = Load-Settings
  if ($null -eq $settings) {
    Write-EnvJson $env
    return
  }
  foreach ($key in $env.Keys) {
    Set-EnvValue $settings $key $env[$key]
  }
  if ($removeKeys) {
    foreach ($key in $removeKeys) {
      Remove-EnvKey $settings $key
    }
  }
  Save-Settings $settings
  Write-Host (T 'MsgSettingsUpdated' $SettingsPath)
  Write-Host (T 'MsgEnvOverrideNote')
}

function Read-TokenLoop([string]$provider, [string]$existing, [string]$promptRequired, [string]$promptOptional, [string]$invalidMsg) {
  while ($true) {
    if (-not [string]::IsNullOrEmpty($existing)) {
      if ($provider -eq 'minimax') { Write-Host (T 'MsgExistingMinimax') } else { Write-Host (T 'MsgExistingGlm') }
      $tokenInput = Read-SecretPrompt $promptOptional
      if ([string]::IsNullOrEmpty($tokenInput)) {
        $tokenInput = $existing
      }
    } else {
      $tokenInput = Read-SecretPrompt $promptRequired
    }

    if ([string]::IsNullOrEmpty($tokenInput)) {
      Write-Host (T 'MsgEmptyKey')
      return $null
    }

    $san = Sanitize-Token $tokenInput
    if ($null -ne $san) {
      return $san
    }

    Write-Host $invalidMsg
    Show-TokenInvalidDetail
    $existing = ''
  }
}

function Write-Minimax {
  $authHeader = Load-AuthHeader
  if ([string]::IsNullOrEmpty($authHeader)) { $authHeader = 'x-api-key' }
  $inputHeader = Read-Host (T 'PromptMinimaxAuthHeader' $authHeader)
  if (-not [string]::IsNullOrEmpty($inputHeader)) { $authHeader = $inputHeader }
  switch ($authHeader.ToLower()) {
    'authorization' { $authHeader = 'Authorization' }
    'auth' { $authHeader = 'Authorization' }
    'bearer' { $authHeader = 'Authorization' }
    'x-api-key' { $authHeader = 'x-api-key' }
    'xapikey' { $authHeader = 'x-api-key' }
    'x-api' { $authHeader = 'x-api-key' }
    'x_api_key' { $authHeader = 'x-api-key' }
    default { $authHeader = 'x-api-key' }
  }

  $existing = Read-Secret 'minimax-api-key'
  $token = Read-TokenLoop 'minimax' $existing (T 'PromptMinimaxApiKeyRequired') (T 'PromptMinimaxApiKey') (T 'MsgInvalidMinimax')
  if ([string]::IsNullOrEmpty($token)) { return }
  Store-Secret 'minimax-api-key' $token
  Save-AuthHeader $authHeader

  $baseUrl = 'https://api.minimax.io/anthropic'
  if ($authHeader -eq 'Authorization') {
    $authValue = "Bearer $token"
  } else {
    $authValue = $token
  }

  Maybe-BackupAnthropic
  $env = [ordered]@{
    ANTHROPIC_BASE_URL = $baseUrl
    ANTHROPIC_AUTH_TOKEN = $authValue
    API_TIMEOUT_MS = '3000000'
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1
    ANTHROPIC_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_SMALL_FAST_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_SONNET_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_OPUS_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_HAIKU_MODEL = 'MiniMax-M2.5'
  }
  if ($authHeader -eq 'Authorization') {
    $env['ANTHROPIC_AUTH_HEADER'] = 'Authorization'
  }
  $removeKeys = @()
  if ($authHeader -ne 'Authorization') { $removeKeys = @('ANTHROPIC_AUTH_HEADER') }
  Update-Settings $env $removeKeys
  Current-Summary
}

function Write-Glm {
  $existing = Read-Secret 'glm-api-key'
  $token = Read-TokenLoop 'glm' $existing (T 'PromptGlmApiKeyRequired') (T 'PromptGlmApiKey') (T 'MsgInvalidGlm')
  if ([string]::IsNullOrEmpty($token)) { return }
  Store-Secret 'glm-api-key' $token

  Maybe-BackupAnthropic
  $env = [ordered]@{
    ANTHROPIC_AUTH_TOKEN = $token
    ANTHROPIC_BASE_URL = 'https://api.z.ai/api/anthropic'
    API_TIMEOUT_MS = '3000000'
  }
  $removeKeys = @('ANTHROPIC_AUTH_HEADER', 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC') + $GLM_MODEL_KEYS
  Update-Settings $env $removeKeys
  Current-Summary
}

function Activate-Minimax {
  $authHeader = Load-AuthHeader
  if ([string]::IsNullOrEmpty($authHeader)) { $authHeader = 'x-api-key' }
  $token = Read-Secret 'minimax-api-key'
  if ([string]::IsNullOrEmpty($token)) {
    Write-Host (T 'MsgMinimaxKeyNotFound')
    return
  }
  $token = Sanitize-Token $token
  if ($null -eq $token) {
    Write-Host (T 'MsgInvalidMinimax')
    Show-TokenInvalidDetail
    return
  }

  $baseUrl = 'https://api.minimax.io/anthropic'
  if ($authHeader -eq 'Authorization') {
    $authValue = "Bearer $token"
  } else {
    $authValue = $token
  }

  Maybe-BackupAnthropic
  $env = [ordered]@{
    ANTHROPIC_BASE_URL = $baseUrl
    ANTHROPIC_AUTH_TOKEN = $authValue
    API_TIMEOUT_MS = '3000000'
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1
    ANTHROPIC_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_SMALL_FAST_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_SONNET_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_OPUS_MODEL = 'MiniMax-M2.5'
    ANTHROPIC_DEFAULT_HAIKU_MODEL = 'MiniMax-M2.5'
  }
  if ($authHeader -eq 'Authorization') {
    $env['ANTHROPIC_AUTH_HEADER'] = 'Authorization'
  }
  $removeKeys = @()
  if ($authHeader -ne 'Authorization') { $removeKeys = @('ANTHROPIC_AUTH_HEADER') }
  Update-Settings $env $removeKeys
  Current-Summary
}

function Activate-Glm {
  $token = Read-Secret 'glm-api-key'
  if ([string]::IsNullOrEmpty($token)) {
    Write-Host (T 'MsgGlmKeyNotFound')
    return
  }
  $token = Sanitize-Token $token
  if ($null -eq $token) {
    Write-Host (T 'MsgInvalidGlm')
    Show-TokenInvalidDetail
    return
  }

  Maybe-BackupAnthropic
  $env = [ordered]@{
    ANTHROPIC_AUTH_TOKEN = $token
    ANTHROPIC_BASE_URL = 'https://api.z.ai/api/anthropic'
    API_TIMEOUT_MS = '3000000'
  }
  $removeKeys = @('ANTHROPIC_AUTH_HEADER', 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC') + $GLM_MODEL_KEYS
  Update-Settings $env $removeKeys
  Current-Summary
}

function Activate-Anthropic {
  if (Test-Path $BACKUP) {
    Copy-Item $BACKUP $SettingsPath
    Write-Host (T 'MsgAnthropicRestored' $SettingsPath)
    Current-Summary
    return
  }
  Clear-ProviderOverrides
  Write-Host (T 'MsgAnthropicOverrideCleared')
  Current-Summary
}

function Backup-Anthropic {
  if (Test-Path $SettingsPath) {
    Copy-Item $SettingsPath $BACKUP
    Write-Host (T 'MsgAnthropicBackupTaken' $BACKUP)
  } else {
    Write-Host (T 'MsgSettingsMissing')
  }
}

function Restore-Anthropic {
  if (Test-Path $BACKUP) {
    Copy-Item $BACKUP $SettingsPath
    Write-Host (T 'MsgAnthropicRestored' $SettingsPath)
  } else {
    Write-Host (T 'MsgBackupNotFound' $BACKUP)
  }
}

function List-Providers {
  Write-Host (T 'MsgListTitle')
  if (Cred-Exists 'glm-api-key') { Write-Host (T 'MsgListGlm') }
  if (Cred-Exists 'minimax-api-key') { Write-Host (T 'MsgListMinimax') }
  if (Cred-Exists 'anthropic-token') { Write-Host (T 'MsgListAnthropic') }
  $authHeader = Load-AuthHeader
  Write-Host (T 'MsgMinimaxAuthHeader' $authHeader)
}

function Doctor {
  $conflicts = @()
  foreach ($var in @('ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL')) {
    $val = [System.Environment]::GetEnvironmentVariable($var)
    if (-not [string]::IsNullOrEmpty($val)) { $conflicts += $var }
  }
  if ($conflicts.Count -gt 0) {
    Write-Host (T 'MsgDoctorConflict' ($conflicts -join ' '))
  } else {
    Write-Host (T 'MsgDoctorNoConflict')
  }
  if (Test-Path $SettingsPath) {
    Write-Host (T 'MsgSettingsExists' $SettingsPath)
  } else {
    Write-Host (T 'MsgSettingsNotExists')
  }
}

function Test-Call {
  if (-not (Test-Path $SettingsPath)) {
    Write-Host (T 'MsgTestNoSettings')
    return
  }
  $base = Get-EnvValue 'ANTHROPIC_BASE_URL'
  $token = Get-EnvValue 'ANTHROPIC_AUTH_TOKEN'
  $header = Get-EnvValue 'ANTHROPIC_AUTH_HEADER'
  if ([string]::IsNullOrEmpty($base)) {
    Write-Host (T 'MsgTestBaseFallback')
    $base = 'https://api.anthropic.com'
  }
  if ([string]::IsNullOrEmpty($token)) {
    Write-Host (T 'MsgTestNoToken')
    return
  }
  Write-Host (T 'MsgTestPing' $base)

  $headers = @{}
  if ($header -eq 'Authorization') {
    $headers['Authorization'] = $token
  } else {
    $headers['x-api-key'] = $token
  }

  $code = 'curl_error'
  try {
    $resp = Invoke-WebRequest -Uri $base -Method Get -Headers $headers -TimeoutSec 8 -UseBasicParsing
    $code = $resp.StatusCode
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $code = $_.Exception.Response.StatusCode.value__
    }
  }
  Write-Host (T 'MsgTestHttp' $code)
}

function Switch-Provider {
  Write-Host (T 'ProviderAnthropic')
  Write-Host (T 'ProviderGlm')
  Write-Host (T 'ProviderMinimax')
  $choice = Read-Host (T 'ProviderPrompt')
  switch ($choice) {
    '1' { Activate-Anthropic }
    '2' { Activate-Glm }
    '3' { Activate-Minimax }
    default { }
  }
}

function Menu {
  Write-Host ''
  Write-Host (T 'MenuTitle')
  Write-Host (T 'Menu1')
  Write-Host (T 'Menu2')
  Write-Host (T 'Menu3')
  Write-Host (T 'Menu4')
  Write-Host (T 'Menu5')
  Write-Host (T 'Menu6')
  Write-Host (T 'Menu7')
  Write-Host (T 'Menu8')
  Write-Host (T 'Menu9')
  Write-Host (T 'Menu0')
}

function Change-Language {
  $newLang = Select-Language
  Save-Language $newLang
  $script:Lang = $newLang
  Write-Host (T 'MsgLanguageSet' $script:Lang)
}

while ($true) {
  Menu
  $sel = Read-Host (T 'PromptChoice')
  switch ($sel) {
    '1' { Write-Glm }
    '2' { Write-Minimax }
    '3' { Switch-Provider }
    '4' { Backup-Anthropic }
    '5' { Restore-Anthropic }
    '6' { List-Providers }
    '7' { Doctor }
    '8' { Test-Call }
    '9' { Change-Language }
    '0' { exit 0 }
    default { }
  }
}

