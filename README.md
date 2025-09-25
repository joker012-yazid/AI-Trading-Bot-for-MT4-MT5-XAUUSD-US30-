# ai-trading-bot-spec1

Repositori ini menyediakan scaffold seni bina untuk bot dagangan AI MetaTrader 5 fokus simbol XAUUSD dan US30 dengan penekanan pada Isyarat EMA/ATR, pengurusan risiko konservatif, serta tumpukan Docker Compose bersepadu.

## Struktur Direktori

```
ROOT
├─ docker-compose.yml
├─ .env.example
├─ README.md
├─ botdata/
│  ├─ logs/.gitkeep
│  ├─ presets/.gitkeep
│  ├─ reports/.gitkeep
│  └─ tester/
│     ├─ mt5_tester.tpl.ini
│     └─ secrets.env.example
├─ docker/
│  ├─ mt5/
│  ├─ dashboard/
│  └─ nginx/
├─ app/
├─ MQL5/
└─ tools/
```

> Direktori `botdata/` menyimpan konfigurasi, log, dan keluaran operasi. Fail `.gitkeep` mengekalkan folder kosong dalam kawalan versi agar struktur konsisten.

## Keperluan

* Docker dan Docker Compose v2
* Git (untuk klon repo)
* Python 3.11 (untuk skrip utiliti tempatan)

## Konfigurasi

1. Salin `.env.example` kepada `.env` dan kemas kini pembolehubah asas seperti `BASE_EQUITY` dan `DAILY_LOSS_LIMIT` jika perlu.
2. Tambah maklumat akaun MT5 dalam `botdata/tester/secrets.env` berdasarkan templat `secrets.env.example`.
3. Masukkan tetapan penguji Strategi MT5 ke dalam `botdata/tester/mt5_tester.tpl.ini` dengan menggantikan placeholder yang disediakan.

## Quick Start
1. `mkdir -p botdata/{logs,presets,reports,tester}` jika belum wujud dan salin `.env.example` ke `.env`.
2. Salin `botdata/tester/secrets.env.example` ke `botdata/tester/secrets.env` dan jalankan `chmod 600 botdata/tester/secrets.env`.
3. Mulakan perkhidmatan dengan `docker compose build && docker compose up -d`.
4. Akses dashboard di http://localhost:8080 atau http://localhost/ dan noVNC di http://localhost:6080/vnc.html atau http://localhost/novnc/.
5. Letakkan preset `.set` dalam `botdata/presets/`, `control.json` dalam `botdata/`, dan `news.csv` dalam `botdata/`.
6. Jalankan `bash scripts/run_backtests.sh` kemudian semak laporan HTML dalam `botdata/reports/`.

## Keselamatan

* Fail `botdata/tester/secrets.env` menyimpan kelayakan akaun MetaTrader 5. Simpan fail ini secara lokal sahaja, tetapkan keizinan ketat `chmod 600 botdata/tester/secrets.env`, dan jangan komit ke repositori awam.
* Repositori ini membekalkan peraturan `.gitignore` untuk menghalang `secrets.env`, log, serta laporan automatik daripada tersalur ke kawalan versi. Semak sebelum melakukan `git add` bagi mengelakkan kebocoran data.
* Gunakan `envsubst` untuk menyuntik kelayakan secara selamat ketika menjana fail konfigurasi penguji. Contohnya:
  ```bash
  set -a
  source botdata/tester/secrets.env
  set +a
  envsubst < botdata/tester/mt5_tester.tpl.ini > /tmp/mt5_tester.ini
  ```
  Kaedah ini membolehkan skrip automasi membaca pembolehubah persekitaran tanpa menulis maklumat sulit ke dalam repositori.

## Batch Backtest

Untuk menjalankan backtest berkumpulan yang konsisten dengan Seni bina bot, sediakan fail `botdata/tester/secrets.env` berdasarkan templat `secrets.env.example` (fail ini mesti mempunyai keizinan `600`) dan pastikan preset `.set` disimpan dalam `botdata/presets/`.

Kemudian jalankan skrip automasi:

```bash
bash scripts/run_backtests.sh
```

Skrip ini akan:

* Menghasilkan konfigurasi penguji strategi daripada templat `botdata/tester/mt5_tester.tpl.ini` dengan menggantikan placeholder `{PRESET_PATH}`, `{SYMBOL}`, dan `{REPORT_PATH}`.
* Mengisi maklumat akaun daripada `botdata/tester/secrets.env` menggunakan `envsubst` sebelum memulakan MetaTrader 5 melalui Wine (`DISPLAY=:99`).
* Menjalankan backtest untuk setiap preset sasaran (`XAUUSD_M15_Conservative.set`, `US30_M15_Conservative.set`, `XAUUSD_M15_Reserve.set`, `US30_M15_Reserve.set`) dan menyimpan laporan HTML ke dalam `botdata/reports/`.
* Menjalankan `tools/validate_logs.py` selepas selesai dan memaparkan `OK` atau `FAILED` bergantung kepada keputusan validasi log.

## KPI Penerimaan

Untuk meluluskan kemas kini strategi, pastikan metrik utama berikut dipenuhi (dikira pada tempoh ujian intraday konservatif 15:00–01:00 MYT):

* **Profit Factor** ≥ 1.3
* **Max Drawdown** ≤ 10%
* **Win Rate** ≥ 45%

## Nyahaktif & Pembersihan

Matikan perkhidmatan dengan:

```bash
docker compose down
```

Buang imej binaan jika perlu:

```bash
docker image prune -f
```

## Lesen

Projek ini diterbitkan untuk tujuan dalaman dan demonstrasi. Sesuaikan mengikut keperluan organisasi anda sebelum pengeluaran sebenar.
