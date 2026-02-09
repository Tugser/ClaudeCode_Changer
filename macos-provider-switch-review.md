# macos-provider-switch.sh Kod İnceleme ve Refactoring Raporu

## Genel Bakış

Bu rapor, `macos-provider-switch.sh` dosyasının uzman yazılım mühendisi bakış açısıyla yapılan kod incelemesi ve refactoring önerilerini içermektedir. Script, Claude Code için provider (Anthropic / GLM / MiniMax) anahtar ve ayar yönetimini macOS üzerinde kolaylaştırmak amacıyla yazılmıştır.

Not: Bu belge 2026-02-09 tarihinde doğrulama sonrası güncellenmiştir.

---

## 1. Kritik: Büyük Kod Tekrarı (DRY İhlali)

**Sorun:**
- `write_minimax()` ve `activate_minimax()` fonksiyonları neredeyse aynı.
- `write_glm()` ve `activate_glm()` de benzer şekilde tekrar içeriyor.
- MiniMax ayarları 4 farklı blokta tekrar yazılıyor (merge + fallback yollarında).

**Öneri:**
- Provider-specific konfigürasyonlar veri olarak tanımlanmalı ve tek bir `apply_provider_settings()` fonksiyonu ile yönetilmeli.

---

## 2. Kritik: `save_minimax_config()` Parametre Hatası [DÜZELTİLDİ]

- Fonksiyon iki parametre bekliyor, bazı çağrılarda sadece bir parametre gönderiliyor.
- Bu, config dosyasında `"language": ""` gibi hatalı bir değer oluşmasına neden oluyor.

---

## 3. Güvenlik: Token Maskeleme Yetersiz [DÜZELTİLDİ]

- Token maskelenirken uzunluğu ifşa ediliyor (`****` yerine gerçek uzunlukta yıldız).
- Sabit uzunlukta maskeleme önerilir.

---

## 4. Format String Dayanıklılığı (Injection Değil)

- `t()` fonksiyonundan dönen stringler doğrudan `printf` ile format olarak kullanılıyor.
- Bu, mevcut kodda doğrudan bir injection vektörü değil; temel risk bakım ve hata görünürlüğü.
- Bilinmeyen key durumunda fallback eklenmeli (sessiz boş çıktı yerine).

---

## 5. JSON Manipülasyonu: İki Yol, Tutarsız Davranış

- plutil varsa merge, yoksa tüm dosya baştan yazılıyor.
- Fallback path'te mevcut settings.json'daki diğer ayarlar siliniyor.
- Uyarı eklenmeli.

---

## 6. `get_env_value()` Global Değişken Sızıntısı [DÜZELTİLDİ]

- Fonksiyon içinde `local` tanımı eksik, global scope'a sızıyor.

---

## 7. `t()` Fonksiyonu — i18n Mimarisi Zayıf

- İç içe case yapısı bakımı zorlaştırıyor.
- Associative array veya ayrı dosya ile yönetim önerilir.

---

## 8. `clear_provider_overrides()` vs `GLM_MODEL_KEYS`

- Burada doğrudan bir uyumsuzluk bug'ı yok; `clear_provider_overrides()` daha geniş (superset) temizlik yapıyor.
- Yine de bakım maliyeti için tek kaynak (single source of truth) önerilir.

---

## 9. `read_secret()` Hex Decode Edge Case

- Uzun hex-only API key'ler yanlışlıkla decode edilebilir.
- Threshold (100) keyfi ve tehlikeli.

---

## 10. Küçük Sorunlar

- Fallback JSON'da auth_header her zaman Authorization yazıyor. [DÜZELTİLDİ]
- `select_language()` fonksiyonu t() kullanmıyor, yorum eklenmeli.
- `save_auth_header()` fonksiyonu kullanılmıyor (dead code).
- `write_glm()` sanitize_token kullanmıyor, tutarsız. [DÜZELTİLDİ]
- `main "$@"` argümanları kullanılmıyor. [DÜZELTİLDİ]
- Script trap/cleanup tanımlamıyor.

Ek not:
- `current_summary()` içinde dil bağımsız `(yok)` fallback'i vardı; i18n uyumlu hale getirildi.

---

## Refactoring Mimarisi Önerisi

```
macos-provider-switch.sh
├── Sabitler & Konfigürasyon
│   ├── Provider tanımları (URL, model, auth header) -> associative array veya struct
│   └── Tüm env key listesi (tek kaynak)
├── Altyapı Fonksiyonları
│   ├── keychain (store/read)
│   ├── json (get/set/remove — plutil wrapper)
│   └── config (load/save — provider-config.json)
├── i18n
│   └── Dil string'leri ayrı dosya veya array
├── İş Mantığı (refactored)
│   ├── prompt_api_key(provider)        — tekil key alma
│   ├── apply_provider(provider_name)   — tekil settings yazma
│   └── backup/restore/doctor/test
└── UI
    └── menu + main loop
```

---

## Öncelik Matrisi — Refactoring Etkisi

```mermaid
quadrantChart
    title Refactoring Öncelik Matrisi
    x-axis Düşük Etki --> Yüksek Etki
    y-axis Düşük Effort --> Yüksek Effort
    quadrant-1 Planla
    quadrant-2 Hemen Yap
    quadrant-3 Atla
    quadrant-4 Hızlı Kazan
    save_minimax_config bug: [0.85, 0.15]
    get_env_value local fix: [0.45, 0.10]
    dead code temizliği: [0.25, 0.10]
    sanitize_token tutarlılık: [0.60, 0.15]
    fallback JSON auth_header fix: [0.70, 0.15]
    token maskeleme: [0.50, 0.20]
    DRY - provider apply: [0.90, 0.65]
    i18n refactor: [0.55, 0.85]
    clear_provider_overrides sync: [0.65, 0.25]
    hex decode threshold: [0.35, 0.30]
    t() fallback key: [0.40, 0.12]
```

---

## Özet ve Aksiyon Sırası

1. "Hızlı Kazan" kadranındaki bug fix'leri uygulayın (5-10 dk)
2. DRY refactoring (orta effort, büyük etki)
3. i18n mimarisi ve mimari iyileştirmeler (daha yüksek effort)

Sorularınız veya önceliklendirme tercihiniz varsa belirtiniz.
