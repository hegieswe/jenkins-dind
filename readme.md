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

## 🔐 Konfigurasi Kredensial Pipeline (Wajib)

Sebelum Anda menjalankan tahapan *Build* (CI) dan *Deploy* (CD), Anda diwajibkan untuk mendaftarkan "Kunci Keamanan" di dalam dasbor **Manage Jenkins > Credentials > System > Global credentials**.

Pastikan ID dari setiap kredensial *(ID field)* diketik persis sesuai dengan yang diminta oleh `Jenkinsfile` aplikasi Anda. Rinciannya sebagai berikut:

| Nama / ID Kredensial | Tipe Kredensial (*Kind*) | Kegunaan | Isi Minimal |
| :--- | :--- | :--- | :--- |
| **`dockerhub-username`** | `Secret text` | Username login Dockerhub untuk `ci.sh` | Username Docker Hub Anda |
| **`dockerhub-password`** | `Secret text` | Password login Dockerhub (Atau Access Token) | Akses Token Docker Hub Anda |
| **`k8s-kubeconfig-file`** | `Secret file` | Mengizinkan jenkins agent berbicara dengan API server k3d | File `~/.kube/config` lokal Anda |
| **`github-credentials`** | `Username with password` | Agar Jenkins diizinkan men-*commit* & mem-*push* file Kustomize GitOps | **Username:** Akun Github <br> **Password:** Github PAT / Token SSH |

---

## ☸️ Catatan Tambahan: Koneksi ke Local Kubernetes (K3d)
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

---

## 4. Prasyarat Repositori Aplikasi

Berkat arsitektur *Jenkins DinD*, Anda **TIDAK PERLU LAGI** menyimpan `ci.sh` atau `cd.sh` di dalam repositori Anda! Kedua skrip komando itu sudah tertanam abadi (*Global Command*) di dalam mesin Jenkins.
Satu-satunya syarat untuk di-\`push\` hanyalah file \`Jenkinsfile\` ke repositori (*root*) aplikasi Anda:

```bash
# Pastikan file ci.sh dan cd.sh SUDAH DIHAPUS dari folder lokal jika masih ada!
rm -f ci.sh cd.sh

git add Jenkinsfile
git commit -m "feat: Add Jenkinsfile for GitOps Pipeline automation"
git push origin main
```

---

## 5. Membuat Tugas Jenkins Pipeline (Eksekusi ��)
Sesuai standar penamaan GitOps profesional, nama *Job* Jenkins **WAJIB** persis sama dengan nama *Repository* Git aplikasinya.

1. Di Dashboard Jenkins Anda, klik tombol menu **New Item**.
2. Ketik nama repositori persis (misal: **`golang-gitops-project`**), centang ikon **Pipeline**, lalu klik **OK**.
3. *Scroll* turun ke konfigurasi kelompok **Pipeline**.
   - **Definition**: Ganti menjadi `Pipeline script from SCM`.
   - **SCM**: Pilih `Git`.
   - **Repository URL**: Masukkan URL repositori aplikasi (Contoh: `https://github.com/hegieswe/golang-gitops-project.git`).
   - Masukkan **Credentials**: Pilih \`github-credentials\` yang Anda persiapkan tadi untuk mengunci *Source Code*.
   - **Branch Specifier**: `*/main`
   - **Script Path**: `Jenkinsfile`
4. Klik tombol **Save**.
5. Jalankan pemicu kompilasi dengan mengklik menu: **Build Now**!

**Selesai!** Pipeline Anda sekarang akan otomatis mengambil kode, *build* Docker Image via instruksi `ci.sh`, mendorongnya ke Docker Hub, membobol `k8s-manifest` Anda, mengedit *Template* dengan revisi citra yang baru, dan mendedikasikan panggung *Deployment*-nya seutuhnya kepada **ArgoCD**!
