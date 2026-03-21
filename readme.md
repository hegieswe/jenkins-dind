# Jenkins Docker-in-Docker (DinD) Setup

Repositori ini berisi konfigurasi untuk membangun server Jenkins CI/CD di dalam Docker, yang memiliki akses penuh ke agen Docker *host* Anda, serta dilengkapi dengan utilitas Kubernetes (`kubectl`) dan *script* otomatisasi CI/CD tingkat lanjut.

## Fitur Utama
- **Docker-in-Docker (DinD)**: Mampu melakukan *build* dan *push* Docker Image langsung dari dalam pipeline Jenkins dengan memanfaatkan mounting `/var/run/docker.sock`.
- **Utilitas Terintegrasi**: Mengemas CLI `docker`, `docker-buildx-plugin`, `kubectl`, dan `python3` langsung di dalam *image* agen Jenkins.
- **Global CI/CD Scripts**: Menyuntikkan _Script_ `ci.sh` (Continuous Integration) dan `cd.sh` (Continuous Deployment) ke `/usr/local/bin`. Developer tidak perlu lagi menyimpan skrip teknis ini di setiap repositori gits mereka, sehingga *repository* lebih rapi.
- **Persistent Storage**: Data pipeline, plugin, dan user tidak akan hilang saat container dihancurkan berkat *volume* `jenkins_data`.

## Cara Menggunakan

### Prasyarat
- Docker Desktop / Orbstack
- Docker Compose
- Utilitas `make` (Opsional, bawaan Mac/Linux)

### 1. Menjalankan Jenkins Server
Gunakan perintah berikut di dalam direktori ini untuk menjalankan Jenkins:
```bash
make up

# Alternatif manual:
# docker-compose up -d --build
```
Proses ini akan memakan waktu sejenak saat pertama kali karena membangun ulang *image* Debian kustom.

### 2. Membuka Jenkins & Password Awal
Buka browser dan navigasikan ke: **`http://localhost:8080`**

Untuk melewati halaman awalan, Jenkins meminta *Initial Admin Password*. Dapatkan password-nya dengan perintah:
```bash
make password

# Alternatif manual:
# docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Mematikan Jenkins
Untuk mematikan container:
```bash
make down
```

## Catatan Penting: Koneksi ke Local Kubernetes (K3d)
Karena Jenkins ini berjalan **di dalam Docker container terisolasi**, ia memerlukan trik khusus untuk "berbicara" dengan cluster Kubernetes lokal Anda (seperti `k3d` di komuter Mac Anda):

1. **API Port 0.0.0.0**: Pastikan cluster k3d Anda menerima koneksi dari semua network interface lokal (bukan hanya localhost 127.0.0.1), dengan menambah argumen: `--api-port 0.0.0.0:6443`.
2. **Kubeconfig Modifikasi**: Saat mengunggah `kubeconfig` ke menu *Credentials* Jenkins, **ubah** alamat IP-nya menjadi _Host Virtual LAN Docker_:
   ```yaml
   # Ubah baris ini:
   # server: https://127.0.0.1:6443 / 0.0.0.0:6443
   
   # Menjadi ini:
   server: https://host.docker.internal:6443
   insecure-skip-tls-verify: true  # (Wajib ditambahkan jika menggunakan local cluster)
   ```
