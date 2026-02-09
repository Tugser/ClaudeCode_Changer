#!/usr/bin/env bash
set -euo pipefail

SERVICE="claude-provider-shell"
CLAUDE_HOME="${HOME}/.claude"
SETTINGS="${CLAUDE_HOME}/settings.json"
BACKUP="${CLAUDE_HOME}/anthropic.backup.json"
CONFIG="${CLAUDE_HOME}/provider-config.json"
SECRETS_FILE="${CLAUDE_HOME}/provider-secrets.json"
LANG_CHOICE=""
SECRET_BACKEND=""

GLM_MODEL_KEYS=(
  ANTHROPIC_MODEL
  ANTHROPIC_SMALL_FAST_MODEL
  ANTHROPIC_DEFAULT_SONNET_MODEL
  ANTHROPIC_DEFAULT_OPUS_MODEL
  ANTHROPIC_DEFAULT_HAIKU_MODEL
)

mkdir -p "$CLAUDE_HOME"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run this script." >&2
  exit 1
fi

t() {
  local key="$1"
  case "$LANG_CHOICE" in
    en)
      case "$key" in
        SETTINGS_WRITTEN) echo "settings.json written -> %s" ;;
        SETTINGS_UPDATED) echo "settings.json updated -> %s" ;;
        ENV_OVERRIDE_NOTE) echo "Note: Environment variables (ANTHROPIC_AUTH_TOKEN/BASE_URL) override settings.json." ;;
        ACTIVE_BASE) echo "Active base_url: %s" ;;
        ACTIVE_BASE_NONE) echo "none" ;;
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
        MSG_LIST_TITLE) echo "Stored secrets:" ;;
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
        MSG_SECRET_BACKEND_KEYRING) echo "Secret backend: secret-tool (system keyring)." ;;
        MSG_SECRET_BACKEND_FILE) echo "Secret backend: local file fallback (%s)." ;;
        MENU_TITLE) echo "Claude Code Provider Menu (Linux)" ;;
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
        *) echo "$key" ;;
      esac
      ;;
    *)
      case "$key" in
        SETTINGS_WRITTEN) echo "settings.json yazildi -> %s" ;;
        SETTINGS_UPDATED) echo "settings.json guncellendi -> %s" ;;
        ENV_OVERRIDE_NOTE) echo "Not: Ortam degiskenleri (ANTHROPIC_AUTH_TOKEN/BASE_URL) varsa settings.json'i override eder." ;;
        ACTIVE_BASE) echo "Aktif base_url: %s" ;;
        ACTIVE_BASE_NONE) echo "yok" ;;
        ACTIVE_TOKEN) echo "Aktif token: %s" ;;
        ACTIVE_TOKEN_NONE) echo "Aktif token: yok" ;;
        PROMPT_MINIMAX_AUTH_HEADER) echo "MiniMax auth header (x-api-key/Authorization) [%s]: " ;;
        PROMPT_MINIMAX_KEY_REQUIRED) echo "MiniMax API key (zorunlu): " ;;
        PROMPT_MINIMAX_KEY) echo "MiniMax API key: " ;;
        PROMPT_GLM_KEY_REQUIRED) echo "GLM API key (zorunlu): " ;;
        PROMPT_GLM_KEY) echo "GLM API key: " ;;
        MSG_EXISTING_MINIMAX) echo "Mevcut MiniMax key bulundu (bos gecersen aynisi korunur)." ;;
        MSG_EXISTING_GLM) echo "Mevcut GLM key bulundu (bos gecersen aynisi korunur)." ;;
        MSG_EMPTY_KEY) echo "Bos key girildi, yazilmadi." ;;
        MSG_INVALID_MINIMAX) echo "MiniMax API key gecersiz (ASCII olmayan karakter veya bosluk var). Lutfen yeniden girin." ;;
        MSG_INVALID_GLM) echo "GLM API key gecersiz (ASCII olmayan karakter veya bosluk var). Lutfen yeniden girin." ;;
        MSG_MINIMAX_KEY_NOT_FOUND) echo "MiniMax API key bulunamadi. Once menu 2 ile key ekleyin." ;;
        MSG_GLM_KEY_NOT_FOUND) echo "GLM API key bulunamadi. Once menu 1 ile key ekleyin." ;;
        MSG_BACKUP_TAKEN) echo "Anthropic yedegi alindi -> %s" ;;
        MSG_BACKUP_RESTORED) echo "Anthropic yedegi geri yuklendi -> %s" ;;
        MSG_SETTINGS_MISSING) echo "settings.json bulunamadi, yedek alinmadi." ;;
        MSG_BACKUP_NOT_FOUND) echo "Yedek bulunamadi: %s" ;;
        MSG_OVERRIDE_CLEARED) echo "Anthropic icin provider override temizlendi." ;;
        MSG_LIST_TITLE) echo "Kayitli sirlar:" ;;
        MSG_LIST_GLM) echo "- glm (api key)" ;;
        MSG_LIST_MINIMAX) echo "- minimax (api key)" ;;
        MSG_LIST_ANTHROPIC) echo "- anthropic (token)" ;;
        MSG_MINIMAX_AUTH_HEADER) echo "MiniMax auth header: %s" ;;
        MSG_DOCTOR_CONFLICT) echo "Uyari: Ortam degiskenleri settings.json'i override eder: %s" ;;
        MSG_DOCTOR_NO_CONFLICT) echo "Env cakismasi yok." ;;
        MSG_SETTINGS_EXISTS) echo "settings.json mevcut: %s" ;;
        MSG_SETTINGS_NOT_EXISTS) echo "settings.json yok." ;;
        MSG_TEST_NO_SETTINGS) echo "settings.json yok, once provider sec." ;;
        MSG_TEST_BASE_FALLBACK) echo "Base URL bulunamadi (Anthropic default olabilir, yine de deneyelim)." ;;
        MSG_TEST_NO_TOKEN) echo "Token yok, test yapilamiyor." ;;
        MSG_TEST_PING) echo "Ping: %s" ;;
        MSG_TEST_HTTP) echo "HTTP kodu: %s (401/403 ise key hatasi, 404 olabilir, 000/curl_error baglanti sorunu)" ;;
        MSG_SECRET_BACKEND_KEYRING) echo "Secret backend: secret-tool (sistem keyring)." ;;
        MSG_SECRET_BACKEND_FILE) echo "Secret backend: local file fallback (%s)." ;;
        MENU_TITLE) echo "Claude Code Saglayici Menusu (Linux)" ;;
        MENU1) echo "1) GLM API key ekle/guncelle" ;;
        MENU2) echo "2) MiniMax API key ekle/guncelle" ;;
        MENU3) echo "3) Saglayiciyi aktif et (Anthropic/GLM/MiniMax)" ;;
        MENU4) echo "4) Anthropic yedek al" ;;
        MENU5) echo "5) Anthropic yedegini geri yukle" ;;
        MENU6) echo "6) Saglayicilari listele" ;;
        MENU7) echo "7) Doctor (env kontrol)" ;;
        MENU8) echo "8) Test (curl ping)" ;;
        MENU9) echo "9) Dil degistir" ;;
        MENU0) echo "0) Cikis" ;;
        PROMPT_CHOICE) echo "Secim: " ;;
        PROVIDER_ANTHROPIC) echo "1) Anthropic" ;;
        PROVIDER_GLM) echo "2) GLM" ;;
        PROVIDER_MINIMAX) echo "3) MiniMax" ;;
        INVALID_CHOICE) echo "Gecersiz secim" ;;
        MSG_LANGUAGE_SET) echo "Dil ayarlandi: %s" ;;
        *) echo "$key" ;;
      esac
      ;;
  esac
}

detect_secret_backend() {
  if [[ -n "$SECRET_BACKEND" ]]; then
    printf "%s" "$SECRET_BACKEND"
    return
  fi

  case "${CLAUDE_PROVIDER_SECRET_BACKEND:-}" in
    secret-tool|file)
      SECRET_BACKEND="${CLAUDE_PROVIDER_SECRET_BACKEND}"
      ;;
    *)
      if command -v secret-tool >/dev/null 2>&1; then
        SECRET_BACKEND="secret-tool"
      else
        SECRET_BACKEND="file"
      fi
      ;;
  esac

  printf "%s" "$SECRET_BACKEND"
}

announce_secret_backend() {
  local backend
  backend=$(detect_secret_backend)
  if [[ "$backend" == "secret-tool" ]]; then
    printf "%s\n" "$(t MSG_SECRET_BACKEND_KEYRING)"
    return
  fi
  printf "$(t MSG_SECRET_BACKEND_FILE)\n" "$SECRETS_FILE"
}

store_file_secret() {
  local account="$1" value="$2"
  python3 - "$SECRETS_FILE" "$account" "$value" <<'PY'
import fcntl
import json
import os
import sys
import tempfile

path = sys.argv[1]
account = sys.argv[2]
value = sys.argv[3]
data = {}
parent = os.path.dirname(path) or "."
os.makedirs(parent, exist_ok=True)
lock_path = f"{path}.lock"

with open(lock_path, "w", encoding="utf-8") as lock_fh:
  fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX)
  if os.path.exists(path):
    try:
      with open(path, "r", encoding="utf-8") as fh:
        loaded = json.load(fh)
      if isinstance(loaded, dict):
        data = {str(k): str(v) for k, v in loaded.items()}
    except Exception:
      data = {}

  data[account] = value
  fd, tmp = tempfile.mkstemp(prefix=".provider-secrets.", dir=parent)
  try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
      json.dump(data, fh, ensure_ascii=False, indent=2)
      fh.write("\n")
    os.replace(tmp, path)
  finally:
    if os.path.exists(tmp):
      os.unlink(tmp)
  fcntl.flock(lock_fh.fileno(), fcntl.LOCK_UN)
PY
  chmod 600 "$SECRETS_FILE"
}

read_file_secret() {
  local account="$1"
  python3 - "$SECRETS_FILE" "$account" <<'PY'
import json
import os
import sys

path = sys.argv[1]
account = sys.argv[2]
if not os.path.exists(path):
  sys.exit(0)

try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(0)

if isinstance(loaded, dict):
  value = loaded.get(account, "")
  if value:
    print(str(value), end="")
PY
}

file_secret_exists() {
  local account="$1"
  python3 - "$SECRETS_FILE" "$account" <<'PY'
import json
import os
import sys

path = sys.argv[1]
account = sys.argv[2]
if not os.path.exists(path):
  sys.exit(1)

try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(1)

if isinstance(loaded, dict) and loaded.get(account):
  sys.exit(0)
sys.exit(1)
PY
}

store_secret() {
  local account="$1" value="$2"
  local backend
  backend=$(detect_secret_backend)

  if [[ "$backend" == "secret-tool" ]]; then
    if printf "%s" "$value" | secret-tool store --label="Claude Provider ($account)" service "$SERVICE" account "$account" >/dev/null 2>&1; then
      return 0
    fi
    SECRET_BACKEND="file"
  fi

  store_file_secret "$account" "$value"
}

read_secret() {
  local account="$1"
  local backend raw=""
  backend=$(detect_secret_backend)

  if [[ "$backend" == "secret-tool" ]]; then
    raw=$(secret-tool lookup service "$SERVICE" account "$account" 2>/dev/null || true)
    raw=$(printf "%s" "$raw" | tr -d '[:space:]')
    if [[ -n "$raw" ]]; then
      printf "%s" "$raw"
      return
    fi
  fi

  read_file_secret "$account" | tr -d '[:space:]'
}

secret_exists() {
  local account="$1"
  local backend raw=""
  backend=$(detect_secret_backend)

  if [[ "$backend" == "secret-tool" ]]; then
    raw=$(secret-tool lookup service "$SERVICE" account "$account" 2>/dev/null || true)
    raw=$(printf "%s" "$raw" | tr -d '[:space:]')
    if [[ -n "$raw" ]]; then
      return 0
    fi
  fi

  file_secret_exists "$account"
}

sanitize_token() {
  local raw="$1"
  raw=$(printf "%s" "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  raw=$(printf "%s" "$raw" | sed -E 's/^[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+//')
  if [[ "$raw" == *$'\n'* || "$raw" == *$'\r'* ]]; then
    return 1
  fi
  if [[ -z "$raw" || ${#raw} -lt 8 ]]; then
    return 1
  fi
  if printf "%s" "$raw" | LC_ALL=C grep -q '[^ -~]'; then
    return 1
  fi
  if printf "%s" "$raw" | grep -q '[[:space:]]'; then
    return 1
  fi
  if ! printf "%s" "$raw" | LC_ALL=C grep -Eq '^[A-Za-z0-9._:@%+=!-]+$'; then
    return 1
  fi
  printf "%s" "$raw"
}

save_minimax_config() {
  local auth_header="$1" language="$2"
  python3 - "$CONFIG" "$auth_header" "$language" <<'PY'
import json
import os
import sys

path = sys.argv[1]
auth_header = sys.argv[2]
language = sys.argv[3]
payload = {
  "minimax_auth_header": auth_header,
  "language": language,
}
tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
  json.dump(payload, fh, ensure_ascii=False, indent=2)
  fh.write("\n")
os.replace(tmp, path)
PY
}

load_config_value() {
  local key="$1"
  if [[ ! -f "$CONFIG" ]]; then
    echo ""
    return
  fi
  python3 - "$CONFIG" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]
try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  loaded = {}

if isinstance(loaded, dict):
  value = loaded.get(key, "")
  if value:
    print(str(value))
PY
}

load_auth_header() {
  load_config_value "minimax_auth_header"
}

load_language() {
  load_config_value "language"
}

save_language() {
  local language="$1" auth_header
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

write_env_json() {
  local json="$1"
  printf "%b\n" "$json" >"$SETTINGS"
  printf "$(t SETTINGS_WRITTEN)\n" "$SETTINGS"
  printf "%s\n" "$(t ENV_OVERRIDE_NOTE)"
}

ensure_settings_json() {
  if [[ ! -f "$SETTINGS" ]]; then
    printf "{\n  \"env\": {}\n}\n" >"$SETTINGS"
  fi
}

settings_can_merge() {
  ensure_settings_json
  python3 - "$SETTINGS" <<'PY'
import json
import sys

path = sys.argv[1]
try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(1)

if not isinstance(loaded, dict):
  sys.exit(1)
env = loaded.get("env")
if env is None:
  loaded["env"] = {}
elif not isinstance(env, dict):
  sys.exit(1)
sys.exit(0)
PY
}

settings_edit_env() {
  local op="$1" key="$2" value="${3:-}"
  python3 - "$SETTINGS" "$op" "$key" "$value" <<'PY'
import json
import os
import sys

path = sys.argv[1]
op = sys.argv[2]
key = sys.argv[3]
value = sys.argv[4] if len(sys.argv) > 4 else ""

data = {}
if os.path.exists(path):
  with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
if not isinstance(data, dict):
  data = {}

env = data.get("env")
if not isinstance(env, dict):
  env = {}
data["env"] = env

if op == "set-string":
  env[key] = value
elif op == "set-int":
  env[key] = int(value)
elif op == "remove":
  env.pop(key, None)
else:
  sys.exit(1)

tmp = f"{path}.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
  json.dump(data, fh, ensure_ascii=False, indent=2)
  fh.write("\n")
os.replace(tmp, path)
PY
}

set_env_string() {
  settings_edit_env "set-string" "$1" "$2"
}

set_env_int() {
  settings_edit_env "set-int" "$1" "$2"
}

remove_env_key() {
  settings_edit_env "remove" "$1" || true
}

clear_provider_overrides() {
  if [[ ! -f "$SETTINGS" ]]; then
    return
  fi
  if ! settings_can_merge; then
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

get_env_value() {
  local key="${1:-${KEY-}}"
  if [[ -z "$key" || ! -f "$SETTINGS" ]]; then
    return
  fi
  python3 - "$SETTINGS" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]
try:
  with open(path, "r", encoding="utf-8") as fh:
    loaded = json.load(fh)
except Exception:
  sys.exit(0)

if not isinstance(loaded, dict):
  sys.exit(0)
env = loaded.get("env")
if not isinstance(env, dict):
  sys.exit(0)
value = env.get(key, "")
if value is None:
  sys.exit(0)
if isinstance(value, bool):
  print("1" if value else "0", end="")
elif isinstance(value, (int, float)):
  print(str(int(value)) if float(value).is_integer() else str(value), end="")
else:
  print(str(value), end="")
PY
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

prepare_settings() {
  if settings_can_merge; then
    return
  fi
  printf "{\n  \"env\": {}\n}\n" >"$SETTINGS"
}

current_summary() {
  local base auth base_display
  base=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_BASE_URL" get_env_value)
  auth=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_TOKEN" get_env_value)
  if [[ -n "$base" ]]; then
    base_display="$base"
  else
    base_display=$(t ACTIVE_BASE_NONE)
  fi
  printf "$(t ACTIVE_BASE)\n" "$base_display"
  if [[ -n "$auth" ]]; then
    printf "$(t ACTIVE_TOKEN)\n" "********"
  else
    printf "%s\n" "$(t ACTIVE_TOKEN_NONE)"
  fi
}

apply_minimax_settings() {
  local token="$1" auth_header="$2"
  local base_url auth_value
  base_url="https://api.minimax.io/anthropic"
  if [[ "$auth_header" == "Authorization" ]]; then
    auth_value="Bearer $token"
  else
    auth_value="$token"
  fi

  maybe_backup_anthropic
  prepare_settings
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
  current_summary
}

apply_glm_settings() {
  local token="$1"
  maybe_backup_anthropic
  prepare_settings
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
  current_summary
}

write_minimax() {
  local token existing auth_header input_header prompt language
  auth_header=$(load_auth_header)
  if [[ -z "$auth_header" ]]; then
    auth_header="x-api-key"
  fi
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
      printf "%s\n" "$(t MSG_EMPTY_KEY)"
      return 1
    fi
  else
    printf "%s\n" "$(t MSG_EXISTING_MINIMAX)"
    read -rsp "$(t PROMPT_MINIMAX_KEY)" token
    echo
    if [[ -z "$token" ]]; then
      token="$existing"
    fi
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)"
      return 1
    fi
  fi

  token=$(sanitize_token "$token") || {
    printf "%s\n" "$(t MSG_INVALID_MINIMAX)"
    return 1
  }

  store_secret "minimax-api-key" "$token"
  language="$LANG_CHOICE"
  if [[ "$language" != "tr" && "$language" != "en" ]]; then
    language=$(load_language)
  fi
  if [[ "$language" != "tr" && "$language" != "en" ]]; then
    language="en"
  fi
  save_minimax_config "$auth_header" "$language"
  apply_minimax_settings "$token" "$auth_header"
}

write_glm() {
  local token existing
  existing=$(read_secret "glm-api-key")
  if [[ -z "$existing" ]]; then
    read -rsp "$(t PROMPT_GLM_KEY_REQUIRED)" token
    echo
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)"
      return 1
    fi
  else
    printf "%s\n" "$(t MSG_EXISTING_GLM)"
    read -rsp "$(t PROMPT_GLM_KEY)" token
    echo
    if [[ -z "$token" ]]; then
      token="$existing"
    fi
    if [[ -z "$token" ]]; then
      printf "%s\n" "$(t MSG_EMPTY_KEY)"
      return 1
    fi
  fi

  token=$(sanitize_token "$token") || {
    printf "%s\n" "$(t MSG_INVALID_GLM)"
    return 1
  }

  store_secret "glm-api-key" "$token"
  apply_glm_settings "$token"
}

activate_minimax() {
  local token auth_header
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
    printf "%s\n" "$(t MSG_INVALID_MINIMAX)"
    return 1
  }
  apply_minimax_settings "$token" "$auth_header"
}

activate_glm() {
  local token
  token=$(read_secret "glm-api-key")
  if [[ -z "$token" ]]; then
    printf "%s\n" "$(t MSG_GLM_KEY_NOT_FOUND)"
    return 1
  fi
  token=$(sanitize_token "$token") || {
    printf "%s\n" "$(t MSG_INVALID_GLM)"
    return 1
  }
  apply_glm_settings "$token"
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
  secret_exists "glm-api-key" && printf "%s\n" "$(t MSG_LIST_GLM)" || true
  secret_exists "minimax-api-key" && printf "%s\n" "$(t MSG_LIST_MINIMAX)" || true
  secret_exists "anthropic-token" && printf "%s\n" "$(t MSG_LIST_ANTHROPIC)" || true
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
    printf "%s\n" "$(t MSG_TEST_NO_SETTINGS)"
    return
  fi
  local base token header code
  base=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_BASE_URL" get_env_value)
  token=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_TOKEN" get_env_value)
  header=$(SETTINGS="$SETTINGS" KEY="ANTHROPIC_AUTH_HEADER" get_env_value)
  if [[ -z "$base" ]]; then
    printf "%s\n" "$(t MSG_TEST_BASE_FALLBACK)"
    base="https://api.anthropic.com"
  fi
  if [[ -z "$token" ]]; then
    printf "%s\n" "$(t MSG_TEST_NO_TOKEN)"
    return
  fi
  printf "$(t MSG_TEST_PING)\n" "$base"
  if [[ "$header" == "Authorization" ]]; then
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "Authorization: $token" "$base") || code="curl_error"
  else
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "x-api-key: $token" "$base") || code="curl_error"
  fi
  printf "$(t MSG_TEST_HTTP)\n" "$code"
}

change_language() {
  local new_lang
  new_lang=$(select_language)
  save_language "$new_lang"
  LANG_CHOICE="$new_lang"
  printf "$(t MSG_LANGUAGE_SET)\n" "$LANG_CHOICE"
}

switch_provider() {
  local choice
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

main() {
  announce_secret_backend
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

if [[ "${BASH_SOURCE[0]-$0}" == "$0" ]]; then
  main
fi
