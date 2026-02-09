# Claude Code Provider Switch (macOS + Linux + Windows)

## Türkçe

### Amaç
Bu araçlar, Claude Code için sağlayıcı (Anthropic / GLM / MiniMax) ayarlarını macOS, Linux ve Windows üzerinde kolayca yönetmenizi sağlar. API anahtarlarını güvenli şekilde saklar ve Claude’un settings.json dosyasındaki env değerlerini güvenli şekilde günceller.

### Kurulum
macOS:
- macOS ve bash gereklidir.
- macOS Keychain (security) ve JSON düzenlemek için plutil kullanır.

Kurulum adımları:
1) Scripti çalıştırılabilir yapın:
   chmod +x macos-provider-switch.sh
2) Scripti çalıştırın:
   ./macos-provider-switch.sh

Windows:
- PowerShell 5.1+ gereklidir.
- Windows Credential Manager kullanır.

Çalıştırma:
1) PowerShell açın.
2) Gerekirse sadece o oturum için:
   Set-ExecutionPolicy -Scope Process Bypass -Force
3) Scripti çalıştırın:
   .\windows-provider-switch.ps1

Linux:
- bash ve python3 gereklidir.
- Varsa `secret-tool` (GNOME Keyring/libsecret) kullanır.
- `secret-tool` kullanılamıyorsa `~/.claude/provider-secrets.json` dosyasına (chmod 600) fallback yapar.

Çalıştırma:
1) Scripti çalıştırılabilir yapın:
   chmod +x linux-provider-switch.sh
2) Scripti çalıştırın:
   ./linux-provider-switch.sh

### Kullanım
Script açıldığında menü üzerinden:
- GLM veya MiniMax API anahtarını ekleyebilir/güncelleyebilirsiniz.
- Sağlayıcıyı aktif edebilirsiniz.
- Anthropic ayarlarını yedekleyip geri yükleyebilirsiniz.
- Ortam değişkeni çakışmalarını kontrol edebilirsiniz.
- Basit bir curl ping testi yapabilirsiniz.
- Dil seçimini değiştirebilirsiniz (menü 9).

Notlar:
- Default dil English’tir; menüden değiştirirseniz seçim kalıcıdır.
- Dil ve MiniMax auth header ayarı `provider-config.json` içinde saklanır.
- Linux scriptinde secret backend zorlamak için `CLAUDE_PROVIDER_SECRET_BACKEND=file` veya `CLAUDE_PROVIDER_SECRET_BACKEND=secret-tool` kullanılabilir.
- MiniMax base URL sadece international: `https://api.minimax.io/anthropic`.
- MiniMax için default auth header `x-api-key`’dir; 401 alırsanız `Authorization` + `Bearer` seçebilirsiniz.
- Anthropic’e dönüş: yedek varsa restore edilir, yoksa provider override temizlenir.
- GLM’de “Unknown Model” görürseniz, `ANTHROPIC_*MODEL` override’larını temizleyin veya GLM’i yeniden aktif edin (script bunları temizler).

### Örnek Çalıştırma
1) Scripti açın:
   Linux: ./linux-provider-switch.sh
   macOS: ./macos-provider-switch.sh
2) Menüden 2’yi seçip MiniMax API anahtarınızı kaydedin.
3) Menüden 3’ü seçip MiniMax’i aktif edin.

Not: Ortam değişkenleri (ANTHROPIC_AUTH_TOKEN / ANTHROPIC_BASE_URL) varsa settings.json ayarlarını override eder.

---

## English

### Purpose
These tools help you manage Claude Code provider settings (Anthropic / GLM / MiniMax) on macOS, Linux, and Windows. They store API keys securely and update env values in Claude’s settings.json safely.

### Installation
macOS:
- Requires macOS and bash.
- Uses macOS Keychain command (security) and plutil for JSON edits.

Steps:
1) Make the script executable:
   chmod +x macos-provider-switch.sh
2) Run the script:
   ./macos-provider-switch.sh

Windows:
- Requires PowerShell 5.1+.
- Uses Windows Credential Manager.

Run:
1) Open PowerShell.
2) If needed for this session:
   Set-ExecutionPolicy -Scope Process Bypass -Force
3) Run the script:
   .\windows-provider-switch.ps1

Linux:
- Requires bash and python3.
- Uses `secret-tool` (GNOME Keyring/libsecret) when available.
- Falls back to `~/.claude/provider-secrets.json` (chmod 600) when `secret-tool` is unavailable/unusable.

Run:
1) Make the script executable:
   chmod +x linux-provider-switch.sh
2) Run the script:
   ./linux-provider-switch.sh

### Usage
From the menu you can:
- Add/update GLM or MiniMax API keys.
- Activate a provider.
- Backup/restore Anthropic settings.
- Check environment variable conflicts.
- Run a simple curl ping test.
- Change language (menu 9).

Notes:
- Default language is English; changes are persisted.
- Language and MiniMax auth header are stored in `provider-config.json`.
- You can force Linux secret backend with `CLAUDE_PROVIDER_SECRET_BACKEND=file` or `CLAUDE_PROVIDER_SECRET_BACKEND=secret-tool`.
- MiniMax base URL is international only: `https://api.minimax.io/anthropic`.
- MiniMax default auth header is `x-api-key`; switch to `Authorization` + `Bearer` if you see 401.
- Anthropic restore: uses backup if present, otherwise clears provider overrides.
- If you see “Unknown Model” on GLM, clear `ANTHROPIC_*MODEL` overrides or re-activate GLM (this script now clears them).

### Example Run
1) Start the script:
   Linux: ./linux-provider-switch.sh
   macOS: ./macos-provider-switch.sh
2) Choose option 2 to save a MiniMax API key.
3) Choose option 3 to activate MiniMax.

Note: Environment variables (ANTHROPIC_AUTH_TOKEN / ANTHROPIC_BASE_URL) override settings.json values.
