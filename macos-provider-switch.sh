#!/usr/bin/env bash
set -euo pipefail

SERVICE="claude-provider-shell"
CLAUDE_HOME="${HOME}/.claude"
SETTINGS="${CLAUDE_HOME}/settings.json"
BACKUP="${CLAUDE_HOME}/anthropic.backup.json"
CONFIG="${CLAUDE_HOME}/provider-config.json"
LANG_CHOICE=""
GLM_MODEL_KEYS=(
  ANTHROPIC_MODEL
  ANTHROPIC_SMALL_FAST_MODEL
  ANTHROPIC_DEFAULT_SONNET_MODEL
  ANTHROPIC_DEFAULT_OPUS_MODEL
  ANTHROPIC_DEFAULT_HAIKU_MODEL
)

mkdir -p "$CLAUDE_HOME"

store_secret() {
  local account="$1" value="$2"
  security add-generic-password -a "$account" -s "$SERVICE" -w "$value" -U >/dev/null
}

read_secret() {
  local account="$1"
  # Strip yeni satır ve boşlukları temizle; anahtarlar tipik olarak boşluk içermez
  local raw
  raw=$(security find-generic-password -a "$account" -s "$SERVICE" -w 2>/dev/null || true)
  # Eğer hex encoded dönmüşse (uzun string), xxd ile decode et
  if [[ ${#raw} -gt 100 && "$raw" =~ ^[0-9a-fA-F]+$ ]]; then
    if command -v xxd >/dev/null 2>&1; then
      echo -n "$raw" | xxd -r -p
      return
    fi
  fi
  # tüm whitespace'i at; whitespace varsa key yok sayılır
  echo -n "$raw" | tr -d '[:space:]'
}

sanitize_token() {
  local raw="$1"
  # Trim whitespace
  raw=$(printf "%s" "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # Strip Bearer prefix if present
  raw=$(printf "%s" "$raw" | sed -E 's/^[Bb]earer[[:space:]]+//')
  # Validate ASCII + no whitespace
  if printf "%s" "$raw" | LC_ALL=C grep -q '[^ -~]'; then
    return 1
  fi
  if printf "%s" "$raw" | grep -q '[[:space:]]'; then
    return 1
  fi
  printf "%s" "$raw"
}

save_minimax_config() {
  local auth_header="$1" language="$2"
  cat >"$CONFIG" <<EOF
{
  "minimax_auth_header": "${auth_header}",
  "language": "${language}"
}
EOF
}

save_auth_header() {
  local auth_header="$1"
  local language
  language=$(load_language)
  if [[ -z "$language" ]]; then
    language="tr"
  fi
  save_minimax_config "$auth_header" "$language"
}

load_auth_header() {
  if [[ -f "$CONFIG" ]]; then
    local value
    value=$(sed -n 's/.*"minimax_auth_header"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | head -n1)
    if [[ -n "$value" ]]; then
      echo "$value"
      return
    fi
  fi
  echo ""
}

load_language() {
  if [[ -f "$CONFIG" ]]; then
    local value
    value=$(sed -n 's/.*"language"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | head -n1)
    if [[ -n "$value" ]]; then
      echo "$value"
      return
    fi
  fi
  echo ""
}

save_language() {
  local language="$1"
  local auth_header
  auth_header=$(load_auth_header)
  if [[ -z "$auth_header" ]]; then
    auth_header="x-api-key"
  fi
  save_minimax_config "$auth_header" "$language"
}

select_language() {
  local choice default_label
  default_label="en"
  if [[ "${LANG_CHOICE:-}" == "tr" ]]; then
    default_label="tr"
  fi
  while true; do
    printf "%s\n" "Dil / Language secimi (en/tr):" >&2
    printf "%s\n" "1) Turkce (tr)" >&2
    printf "%s\n" "2) English (en)" >&2
    read -rp "Dil / Language secimi [${default_label}]: " choice
    choice=$(printf "%s" "$choice" | tr '[:upper:]' '[:lower:]')
    case "$choice" in
      "") echo "$default_label"; return ;;
      1|tr|turkce|turkish) echo "tr"; return ;;
      2|en|english) echo "en"; return ;;
      *) printf "%s\n" "Gecersiz secim / Invalid choice. 1/2 or tr/en." >&2 ;;
    esac
  done
}

t() {
  local key="$1"
  case "$LANG_CHOICE" in
    en)
      case "$key" in
        SETTINGS_WRITTEN) echo "settings.json written -> %s" ;;
        SETTINGS_UPDATED) echo "settings.json updated -> %s" ;;
        ENV_OVERRIDE_NOTE) echo "Note: Environment variables (ANTHROPIC_AUTH_TOKEN/BASE_URL) override settings.json." ;;
        ACTIVE_BASE) echo "Active base_url: %s" ;;
        ACTIVE_TOKEN) echo "Active token: %s" ;;
        ACTIVE_TOKEN_NONE) echo "Active token: none" ;;
        PROMPT_MINIMAX_AUTH_HEADER) echo "MiniMax auth header (x-api-key/Authorization) [%s]: " ;;
        PROMPT_MINIMAX_KEY_REQUIRED) echo "MiniMax API key (required): " ;;
        PROMPT_MINIMAX_KEY) echo "MiniMax API key: " ;;
        PROMPT_GLM_KEY_REQUIRED) echo "GLM API key (required): " ;;
        PROMPT_GLM_KEY) echo "GLM API key: " ;;
        MSG_EXISTING_MINIMAX) echo "Existing MiniMax key found (leave blank to keep)." ;;
        MSG_EXISTING_GLM) echo "Existing GLM key found (leave blank to keep)." ;;
        MSG_EMPTY_KEY) echo "Empty key entered, not saved." ;;
        MSG_INVALID_MINIMAX) echo "MiniMax API key invalid (non-ASCII or whitespace). Please re-enter." ;;
        MSG_INVALID_GLM) echo "GLM API key invalid (non-ASCII or whitespace). Please re-enter." ;;
        MSG_MINIMAX_KEY_NOT_FOUND) echo "MiniMax API key not found. Add it via menu 2 first." ;;
        MSG_GLM_KEY_NOT_FOUND) echo "GLM API key not found. Add it via menu 1 first." ;;
        MSG_BACKUP_TAKEN) echo "Anthropic backup saved -> %s" ;;
        MSG_BACKUP_RESTORED) echo "Anthropic backup restored -> %s" ;;
        MSG_SETTINGS_MISSING) echo "settings.json not found, backup not taken." ;;
        MSG_BACKUP_NOT_FOUND) echo "Backup not found: %s" ;;
        MSG_OVERRIDE_CLEARED) echo "Provider overrides cleared for Anthropic." ;;
        MSG_LIST_TITLE) echo "Stored secrets (keychain):" ;;
        MSG_LIST_GLM) echo "- glm (api key)" ;;
        MSG_LIST_MINIMAX) echo "- minimax (api key)" ;;
        MSG_LIST_ANTHROPIC) echo "- anthropic (token)" ;;
        MSG_MINIMAX_AUTH_HEADER) echo "MiniMax auth header: %s" ;;
        MSG_DOCTOR_CONFLICT) echo "Warning: Environment variables override settings.json: %s" ;;
        MSG_DOCTOR_NO_CONFLICT) echo "No env conflicts." ;;
        MSG_SETTINGS_EXISTS) echo "settings.json present: %s" ;;
        MSG_SETTINGS_NOT_EXISTS) echo "settings.json missing." ;;
        MSG_TEST_NO_SETTINGS) echo "settings.json missing, select a provider first." ;;
        MSG_TEST_BASE_FALLBACK) echo "Base URL not found (Anthropic default may apply, trying anyway)." ;;
        MSG_TEST_NO_TOKEN) echo "Token missing, cannot test." ;;
        MSG_TEST_PING) echo "Ping: %s" ;;
        MSG_TEST_HTTP) echo "HTTP code: %s (401/403 key error, 404 may be OK, 000/curl_error connection issue)" ;;
        MENU_TITLE) echo "Claude Code Provider Menu (macOS)" ;;
        MENU1) echo "1) Add/update GLM API key" ;;
        MENU2) echo "2) Add/update MiniMax API key" ;;
        MENU3) echo "3) Activate provider (Anthropic/GLM/MiniMax)" ;;
        MENU4) echo "4) Backup Anthropic" ;;
        MENU5) echo "5) Restore Anthropic backup" ;;
        MENU6) echo "6) List providers" ;;
        MENU7) echo "7) Doctor (env check)" ;;
        MENU8) echo "8) Test (curl ping)" ;;
        MENU9) echo "9) Change language" ;;
        MENU0) echo "0) Exit" ;;
        PROMPT_CHOICE) echo "Choice: " ;;
        PROVIDER_ANTHROPIC) echo "1) Anthropic" ;;
        PROVIDER_GLM) echo "2) GLM" ;;
        PROVIDER_MINIMAX) echo "3) MiniMax" ;;
        INVALID_CHOICE) echo "Invalid choice" ;;
        MSG_LANGUAGE_SET) echo "Language set: %s" ;;
      esac
      ;;
    *)
      case "$key" in
        SETTINGS_WRITTEN) echo "settings.json yazıldı -> %s" ;;
        SETTINGS_UPDATED) echo "settings.json güncellendi -> %s" ;;
        ENV_OVERRIDE_NOTE) echo "Not: Ortam değişkenleri (ANTHROPIC_AUTH_TOKEN/BASE_URL) varsa settings.json'ı override eder." ;;
        ACTIVE_BASE) echo "Aktif base_url: %s" ;;
        ACTIVE_TOKEN) echo "Aktif token: %s" ;;
        ACTIVE_TOKEN_NONE) echo "Aktif token: yok" ;;
        PROMPT_MINIMAX_AUTH_HEADER) echo "MiniMax auth header (x-api-key/Authorization) [%s]: " ;;
        PROMPT_MINIMAX_KEY_REQUIRED) echo "MiniMax API key (zorunlu): " ;;
        PROMPT_MINIMAX_KEY) echo "MiniMax API key: " ;;
        PROMPT_GLM_KEY_REQUIRED) echo "GLM API key (zorunlu): " ;;
        PROMPT_GLM_KEY) echo "GLM API key: " ;;
        MSG_EXISTING_MINIMAX) echo "Mevcut MiniMax key bulundu (boş geçersen aynısı korunur)." ;;
        MSG_EXISTING_GLM) echo "Mevcut GLM key bulundu (boş geçersen aynısı korunur)." ;;
        MSG_EMPTY_KEY) echo "Boş key girildi, yazılmadı." ;;
        MSG_INVALID_MINIMAX) echo "MiniMax API key geçersiz (ASCII olmayan karakter veya boşluk var). Lütfen yeniden girin." ;;
        MSG_INVALID_GLM) echo "GLM API key geçersiz (ASCII olmayan karakter veya boşluk var). Lütfen yeniden girin." ;;
        MSG_MINIMAX_KEY_NOT_FOUND) echo "MiniMax API key bulunamadı. Önce menü 2 ile key ekleyin." ;;
        MSG_GLM_KEY_NOT_FOUND) echo "GLM API key bulunamadı. Önce menü 1 ile key ekleyin." ;;
        MSG_BACKUP_TAKEN) echo "Anthropic yedeği alındı -> %s" ;;
        MSG_BACKUP_RESTORED) echo "Anthropic yedeği geri yüklendi -> %s" ;;
        MSG_SETTINGS_MISSING) echo "settings.json bulunamadı, yedek alınamadı." ;;
        MSG_BACKUP_NOT_FOUND) echo "Yedek bulunamadı: %s" ;;
        MSG_OVERRIDE_CLEARED) echo "Anthropic için provider override temizlendi." ;;
        MSG_LIST_TITLE) echo "Kayıtlı sırlar (keychain):" ;;
        MSG_LIST_GLM) echo "- glm (api key)" ;;
        MSG_LIST_MINIMAX) echo "- minimax (api key)" ;;
        MSG_LIST_ANTHROPIC) echo "- anthropic (token)" ;;
        MSG_MINIMAX_AUTH_HEADER) echo "MiniMax auth header: %s" ;;
        MSG_DOCTOR_CONFLICT) echo "Uyarı: Ortam değişkenleri settings.json'ı override eder: %s" ;;
        MSG_DOCTOR_NO_CONFLICT) echo "Env çakışması yok." ;;
        MSG_SETTINGS_EXISTS) echo "settings.json mevcut: %s" ;;
        MSG_SETTINGS_NOT_EXISTS) echo "settings.json yok." ;;
        MSG_TEST_NO_SETTINGS) echo "settings.json yok, önce provider seç." ;;
        MSG_TEST_BASE_FALLBACK) echo "Base URL bulunamadı (Anthropic default olabilir, yine de deneyelim)." ;;
        MSG_TEST_NO_TOKEN) echo "Token yok, test yapılamıyor." ;;
        MSG_TEST_PING) echo "Ping: %s" ;;
        MSG_TEST_HTTP) echo "HTTP kodu: %s (401/403 ise key hatası, 404 olabilir, 000/curl_error bağlantı sorunu)" ;;
        MENU_TITLE) echo "Claude Code Sağlayıcı Menüsü (macOS)" ;;
        MENU1) echo "1) GLM API key ekle/güncelle" ;;
        MENU2) echo "2) MiniMax API key ekle/güncelle" ;;
        MENU3) echo "3) Sağlayıcıyı aktif et (Anthropic/GLM/MiniMax)" ;;
        MENU4) echo "4) Anthropic yedek al" ;;
        MENU5) echo "5) Anthropic yedeğini geri yükle" ;;
        MENU6) echo "6) Sağlayıcıları listele" ;;
        MENU7) echo "7) Doctor (env kontrol)" ;;
        MENU8) echo "8) Test (curl ping)" ;;
        MENU9) echo "9) Dil degistir" ;;
        MENU0) echo "0) Çıkış" ;;
        PROMPT_CHOICE) echo "Seçim: " ;;
        PROVIDER_ANTHROPIC) echo "1) Anthropic" ;;
        PROVIDER_GLM) echo "2) GLM" ;;
        PROVIDER_MINIMAX) echo "3) MiniMax" ;;
        INVALID_CHOICE) echo "Geçersiz seçim" ;;
        MSG_LANGUAGE_SET) echo "Dil ayarlandi: %s" ;;
      esac
      ;;
  esac
}

write_env_json() {
  local json="$1"
  printf "%b\n" "$json" >"$SETTINGS"
  printf "$(t SETTINGS_WRITTEN)\n" "$SETTINGS"
  printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
}

have_plutil() {
  command -v /usr/bin/plutil >/dev/null 2>&1
}

ensure_settings_json() {
  if [[ ! -f "$SETTINGS" ]]; then
    printf "{\n  \"env\": {}\n}\n" >"$SETTINGS"
  fi
}

settings_can_merge() {
  have_plutil || return 1
  ensure_settings_json
  /usr/bin/plutil -lint "$SETTINGS" >/dev/null 2>&1
}

set_env_string() {
  /usr/bin/plutil -replace "env.$1" -string "$2" "$SETTINGS" >/dev/null 2>&1
}

set_env_int() {
  /usr/bin/plutil -replace "env.$1" -integer "$2" "$SETTINGS" >/dev/null 2>&1
}

remove_env_key() {
  /usr/bin/plutil -remove "env.$1" "$SETTINGS" >/dev/null 2>&1 || true
}

clear_provider_overrides() {
  if [[ ! -f "$SETTINGS" ]]; then
    return
  fi
  if ! have_plutil; then
    rm -f "$SETTINGS"
    return
  fi
  if ! /usr/bin/plutil -lint "$SETTINGS" >/dev/null 2>&1; then
    rm -f "$SETTINGS"
    return
  fi
  for key in \
    ANTHROPIC_BASE_URL \
    ANTHROPIC_AUTH_TOKEN \
    ANTHROPIC_AUTH_HEADER \
    API_TIMEOUT_MS \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
    ANTHROPIC_MODEL \
    ANTHROPIC_SMALL_FAST_MODEL \
    ANTHROPIC_DEFAULT_SONNET_MODEL \
    ANTHROPIC_DEFAULT_OPUS_MODEL \
    ANTHROPIC_DEFAULT_HAIKU_MODEL; do
    remove_env_key "$key"
  done
}

maybe_backup_anthropic() {
  if [[ -f "$BACKUP" || ! -f "$SETTINGS" ]]; then
    return
  fi
  local base
  base=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_BASE_URL" get_env_value)
  if [[ -z "$base" || "$base" == "https://api.anthropic.com" ]]; then
    cp "$SETTINGS" "$BACKUP"
    printf "$(t MSG_BACKUP_TAKEN)\n" "$BACKUP"
  fi
}

get_env_value() {
  # Key önceliği: argüman > KEY env
  key="${1:-${KEY-}}"
  if [[ -z "$key" || ! -f "$SETTINGS" ]]; then
    return
  fi
  if have_plutil; then
    /usr/bin/plutil -extract "env.$key" raw -o - "$SETTINGS" 2>/dev/null || true
    return
  fi
  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$SETTINGS" | head -n1
}

current_summary() {
  local base auth
  base=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_BASE_URL" get_env_value)
  auth=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_TOKEN" get_env_value)
  printf "$(t ACTIVE_BASE)\n" "${base:-(yok)}"
  if [[ -n "$auth" ]]; then
    printf "$(t ACTIVE_TOKEN)\n" "$(echo "$auth" | sed 's/./*/g')"
  else
    printf "%s\n" "$(t ACTIVE_TOKEN_NONE)"
  fi
}

write_minimax() {
  local token existing base_url auth_value auth_header input_header
  auth_header=$(load_auth_header)
  if [[ -z "$auth_header" ]]; then
    auth_header="x-api-key"
  fi
  local prompt
  prompt=$(printf "$(t PROMPT_MINIMAX_AUTH_HEADER)" "$auth_header")
  read -rp "$prompt" input_header
  if [[ -n "$input_header" ]]; then
    auth_header="$input_header"
  fi
  case "$(printf "%s" "$auth_header" | tr '[:upper:]' '[:lower:]')" in
    authorization|auth|bearer) auth_header="Authorization" ;;
    x-api-key|xapikey|x-api|x_api_key) auth_header="x-api-key" ;;
    *) auth_header="x-api-key" ;;
  esac
  existing=$(read_secret "minimax-api-key")
  if [[ -z "$existing" ]]; then
    read -rsp "$(t PROMPT_MINIMAX_KEY_REQUIRED)" token
    echo
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)" && return 1
    fi
  else
    printf "%s\n" "$(t MSG_EXISTING_MINIMAX)"
    read -rsp "$(t PROMPT_MINIMAX_KEY)" token
    echo
    if [[ -z "$token" ]]; then
      token="$existing"
    fi
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)" && return 1
    fi
  fi
  token=$(sanitize_token "$token") || {
    printf "%s\n" "$(t MSG_INVALID_MINIMAX)"; return 1; }
  store_secret "minimax-api-key" "$token"
  base_url="https://api.minimax.io/anthropic"
  save_minimax_config "$auth_header"
  if [[ "$auth_header" == "Authorization" ]]; then
    auth_value="Bearer $token"
  else
    auth_value="$token"
  fi
  maybe_backup_anthropic
  if settings_can_merge; then
    set_env_string "ANTHROPIC_BASE_URL" "$base_url"
    set_env_string "ANTHROPIC_AUTH_TOKEN" "$auth_value"
    if [[ "$auth_header" == "Authorization" ]]; then
      set_env_string "ANTHROPIC_AUTH_HEADER" "Authorization"
    else
      remove_env_key "ANTHROPIC_AUTH_HEADER"
    fi
    set_env_string "API_TIMEOUT_MS" "3000000"
    set_env_int "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" 1
    set_env_string "ANTHROPIC_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_SMALL_FAST_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_SONNET_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_OPUS_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_HAIKU_MODEL" "MiniMax-M2.1"
    printf "$(t SETTINGS_UPDATED)\n" "$SETTINGS"
    printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
  else
    write_env_json "{\n  \"env\": {\n    \"ANTHROPIC_BASE_URL\": \"$base_url\",\n    \"ANTHROPIC_AUTH_TOKEN\": \"$auth_value\",\n    \"ANTHROPIC_AUTH_HEADER\": \"Authorization\",\n    \"API_TIMEOUT_MS\": \"3000000\",\n    \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": 1,\n    \"ANTHROPIC_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_SMALL_FAST_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"MiniMax-M2.1\"\n  }\n}"
  fi
  current_summary
}

write_glm() {
  local token existing
  existing=$(read_secret "glm-api-key")
  if [[ -z "$existing" ]]; then
    read -rsp "$(t PROMPT_GLM_KEY_REQUIRED)" token
    echo
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)" && return 1
    fi
  else
    printf "%s\n" "$(t MSG_EXISTING_GLM)"
    read -rsp "$(t PROMPT_GLM_KEY)" token
    echo
    if [[ -z "$token" ]]; then
      token="$existing"
    fi
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)" && return 1
    fi
  fi
  store_secret "glm-api-key" "$token"
  maybe_backup_anthropic
  if settings_can_merge; then
    set_env_string "ANTHROPIC_AUTH_TOKEN" "$token"
    set_env_string "ANTHROPIC_BASE_URL" "https://api.z.ai/api/anthropic"
    set_env_string "API_TIMEOUT_MS" "3000000"
    remove_env_key "ANTHROPIC_AUTH_HEADER"
    remove_env_key "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    for key in "${GLM_MODEL_KEYS[@]}"; do
      remove_env_key "$key"
    done
    printf "$(t SETTINGS_UPDATED)\n" "$SETTINGS"
    printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
  else
    write_env_json "{\n  \"env\": {\n    \"ANTHROPIC_AUTH_TOKEN\": \"$token\",\n    \"ANTHROPIC_BASE_URL\": \"https://api.z.ai/api/anthropic\",\n    \"API_TIMEOUT_MS\": \"3000000\"\n  }\n}"
  fi
  current_summary
}

activate_minimax() {
  local token base_url auth_value auth_header
  auth_header=$(load_auth_header)
  if [[ -z "$auth_header" ]]; then
    auth_header="x-api-key"
  fi
  token=$(read_secret "minimax-api-key")
  if [[ -z "$token" ]]; then
    printf "%s\n" "$(t MSG_MINIMAX_KEY_NOT_FOUND)"
    return 1
  fi
  token=$(sanitize_token "$token") || {
    printf "%s\n" "$(t MSG_INVALID_MINIMAX)"; return 1; }
  base_url="https://api.minimax.io/anthropic"
  if [[ "$auth_header" == "Authorization" ]]; then
    auth_value="Bearer $token"
  else
    auth_value="$token"
  fi
  maybe_backup_anthropic
  if settings_can_merge; then
    set_env_string "ANTHROPIC_BASE_URL" "$base_url"
    set_env_string "ANTHROPIC_AUTH_TOKEN" "$auth_value"
    if [[ "$auth_header" == "Authorization" ]]; then
      set_env_string "ANTHROPIC_AUTH_HEADER" "Authorization"
    else
      remove_env_key "ANTHROPIC_AUTH_HEADER"
    fi
    set_env_string "API_TIMEOUT_MS" "3000000"
    set_env_int "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" 1
    set_env_string "ANTHROPIC_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_SMALL_FAST_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_SONNET_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_OPUS_MODEL" "MiniMax-M2.1"
    set_env_string "ANTHROPIC_DEFAULT_HAIKU_MODEL" "MiniMax-M2.1"
    printf "$(t SETTINGS_UPDATED)\n" "$SETTINGS"
    printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
  else
    write_env_json "{\n  \"env\": {\n    \"ANTHROPIC_BASE_URL\": \"$base_url\",\n    \"ANTHROPIC_AUTH_TOKEN\": \"$auth_value\",\n    \"ANTHROPIC_AUTH_HEADER\": \"Authorization\",\n    \"API_TIMEOUT_MS\": \"3000000\",\n    \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": 1,\n    \"ANTHROPIC_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_SMALL_FAST_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"MiniMax-M2.1\",\n    \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"MiniMax-M2.1\"\n  }\n}"
  fi
  current_summary
}

activate_anthropic() {
  if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$SETTINGS"
    printf "$(t MSG_BACKUP_RESTORED)\n" "$SETTINGS"
    current_summary
    return
  fi
  clear_provider_overrides
  printf "%s\n" "$(t MSG_OVERRIDE_CLEARED)"
  current_summary
}

activate_glm() {
  local token
  token=$(read_secret "glm-api-key")
  if [[ -z "$token" ]]; then
    printf "%s\n" "$(t MSG_GLM_KEY_NOT_FOUND)"
    return 1
  fi
  maybe_backup_anthropic
  if settings_can_merge; then
    set_env_string "ANTHROPIC_AUTH_TOKEN" "$token"
    set_env_string "ANTHROPIC_BASE_URL" "https://api.z.ai/api/anthropic"
    set_env_string "API_TIMEOUT_MS" "3000000"
    remove_env_key "ANTHROPIC_AUTH_HEADER"
    remove_env_key "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    for key in "${GLM_MODEL_KEYS[@]}"; do
      remove_env_key "$key"
    done
    printf "$(t SETTINGS_UPDATED)\n" "$SETTINGS"
    printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
  else
    write_env_json "{\n  \"env\": {\n    \"ANTHROPIC_AUTH_TOKEN\": \"$token\",\n    \"ANTHROPIC_BASE_URL\": \"https://api.z.ai/api/anthropic\",\n    \"API_TIMEOUT_MS\": \"3000000\"\n  }\n}"
  fi
  current_summary
}

backup_anthropic() {
  if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "$BACKUP"
    printf "$(t MSG_BACKUP_TAKEN)\n" "$BACKUP"
  else
    printf "%s\n" "$(t MSG_SETTINGS_MISSING)"
  fi
}

restore_anthropic() {
  if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$SETTINGS"
    printf "$(t MSG_BACKUP_RESTORED)\n" "$SETTINGS"
  else
    printf "$(t MSG_BACKUP_NOT_FOUND)\n" "$BACKUP"
  fi
}

list_providers() {
  printf "%s\n" "$(t MSG_LIST_TITLE)"
  security find-generic-password -s "$SERVICE" -a glm-api-key >/dev/null 2>&1 && printf "%s\n" "$(t MSG_LIST_GLM)" || true
  security find-generic-password -s "$SERVICE" -a minimax-api-key >/dev/null 2>&1 && printf "%s\n" "$(t MSG_LIST_MINIMAX)" || true
  security find-generic-password -s "$SERVICE" -a anthropic-token >/dev/null 2>&1 && printf "%s\n" "$(t MSG_LIST_ANTHROPIC)" || true
  printf "$(t MSG_MINIMAX_AUTH_HEADER)\n" "$(load_auth_header || echo "")"
}

doctor() {
  local conflicts=()
  for var in ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL; do
    if [[ -n "${!var-}" ]]; then
      conflicts+=("$var")
    fi
  done
  if (( ${#conflicts[@]} )); then
    printf "$(t MSG_DOCTOR_CONFLICT)\n" "${conflicts[*]}"
  else
    printf "%s\n" "$(t MSG_DOCTOR_NO_CONFLICT)"
  fi
  if [[ -f "$SETTINGS" ]]; then
    printf "$(t MSG_SETTINGS_EXISTS)\n" "$SETTINGS"
  else
    printf "%s\n" "$(t MSG_SETTINGS_NOT_EXISTS)"
  fi
}

test_call() {
  if [[ ! -f "$SETTINGS" ]]; then
    printf "%s\n" "$(t MSG_TEST_NO_SETTINGS)"; return
  fi
  local base token header
  base=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_BASE_URL" get_env_value)
  token=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_TOKEN" get_env_value)
  header=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_HEADER" get_env_value)
  if [[ -z "$base" ]]; then
    printf "%s\n" "$(t MSG_TEST_BASE_FALLBACK)"
    base="https://api.anthropic.com"
  fi
  if [[ -z "$token" ]]; then
    printf "%s\n" "$(t MSG_TEST_NO_TOKEN)"; return
  fi
  printf "$(t MSG_TEST_PING)\n" "$base"
  local code
  if [[ "$header" == "Authorization" ]]; then
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "Authorization: $token" "$base") || code="curl_error"
  else
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "x-api-key: $token" "$base") || code="curl_error"
  fi
  printf "$(t MSG_TEST_HTTP)\n" "$code"
}

menu() {
  echo ""
  printf "%s\n" "$(t MENU_TITLE)"
  printf "%s\n" "$(t MENU1)"
  printf "%s\n" "$(t MENU2)"
  printf "%s\n" "$(t MENU3)"
  printf "%s\n" "$(t MENU4)"
  printf "%s\n" "$(t MENU5)"
  printf "%s\n" "$(t MENU6)"
  printf "%s\n" "$(t MENU7)"
  printf "%s\n" "$(t MENU8)"
  printf "%s\n" "$(t MENU9)"
  printf "%s\n" "$(t MENU0)"
  printf "%s" "$(t PROMPT_CHOICE)"
}

change_language() {
  local new_lang
  new_lang=$(select_language)
  save_language "$new_lang"
  LANG_CHOICE="$new_lang"
  printf "$(t MSG_LANGUAGE_SET)\n" "$LANG_CHOICE"
}

switch_provider() {
  printf "%s\n" "$(t PROVIDER_ANTHROPIC)"
  printf "%s\n" "$(t PROVIDER_GLM)"
  printf "%s\n" "$(t PROVIDER_MINIMAX)"
  read -rp "$(t PROMPT_CHOICE)" choice
  case "$choice" in
    1) activate_anthropic ;;
    2) activate_glm ;;
    3) activate_minimax ;;
    *) printf "%s\n" "$(t INVALID_CHOICE)" ;;
  esac
}

main() {
  while true; do
    menu
    read -r sel
    case "$sel" in
      1) write_glm ;;
      2) write_minimax ;;
      3) switch_provider ;;
      4) backup_anthropic ;;
      5) restore_anthropic ;;
      6) list_providers ;;
      7) doctor ;;
      8) test_call ;;
      9) change_language ;;
      0) exit 0 ;;
      *) printf "%s\n" "$(t INVALID_CHOICE)" ;;
    esac
  done
}

if [[ -z "$LANG_CHOICE" ]]; then
  LANG_CHOICE=$(load_language)
  if [[ "$LANG_CHOICE" != "tr" && "$LANG_CHOICE" != "en" ]]; then
    LANG_CHOICE="en"
  fi
fi

main "$@"
