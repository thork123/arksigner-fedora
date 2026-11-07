# ArkSigner Fedora RPM Paketi ve Üniversal Derleme Aracı

Bu depo, Debian, Ubuntu ve Pardus için dağıtılan ArkSigner `.deb` paketlerini **Fedora Linux** (Fedora 40, 41, 42, 43, 44+) standartlarında yerel bir RPM paketine (`.rpm`) dönüştürmek ve derlemek için hazırlanmış üniversal otomasyon araçlarını içerir.

Artık herhangi bir sürüm numarasına veya dosya adına bağlı kalmaksızın, ArkSigner'ın **mevcut veya gelecekteki tüm `.deb` sürümleri** otomatik olarak algılanır ve Fedora uyumlu RPM paketi üretilir.

---

## 🛠️ Üniversal RPM Nasıl Üretilir?

1. ArkSigner resmi sitesinden veya kurumunuzdan indirdiğiniz herhangi bir `.deb` paketini (örneğin `arksigner_amd64.deb`, `arksigner.deb` veya `arksigner_3.0.12_pardus25.11_amd64.deb`) bu proje dizinine (`build-rpm.sh` dosyasının yanına) koyun.
2. Terminalden derleme betiğini çalıştırın:

```bash
./build-rpm.sh
```

*(İsteğe bağlı olarak dosya adını parametre olarak da verebilirsiniz: `./build-rpm.sh paket_adi.deb`)*

### 🔍 Betik Ne Yapar?
* Dizin içindeki `.deb` paketini otomatik tespit eder.
* Paketin içindeki `control` dosyasını okuyarak uygulamanın gerçek sürüm numarasını otomatik olarak çözer.
* Fedora'nın resmi bağımlılık standartlarına (`qt5-qtbase-gui`, `qt5-qtsvg`, `poppler-qt5`, `pcsc-lite`, `pcsc-lite-ccid`, `nss-tools`, `python3`) göre `.spec` dosyasını dinamik olarak yapılandırır.
* Sisteminizde `rpmbuild` yüklü olmasa bile yerel Python `librpmbuild` arabirimi üzerinden sorunsuz derleme yapar.
* Çıktı olarak ana dizine `arksigner-<sürüm>-1.fc44.x86_64.rpm` paketini bırakır.

---

## 🚀 Fedora Üzerinde Kurulum

Oluşturulan RPM paketini doğrudan `dnf` ile kurabilirsiniz. Eksik olan tüm sistem kütüphaneleri Fedora resmi depolarından otomatik kurulacaktır:

```bash
sudo dnf install ./arksigner-*.rpm
```

---

## 🔑 Akıllı Kart (E-İmza) Servisinin Kontrolü

ArkSigner, takılan e-imza / akıllı kart okuyucuları algılamak için Linux PC/SC (`pcscd`) servisini kullanır.

Kurulum scriptleti bu servisi otomatik tetikler. Durumunu kontrol etmek için:

```bash
sudo systemctl enable --now pcscd.socket
sudo systemctl status pcscd.socket
```

Kart okuyucunuzun tanınıp tanınmadığını kontrol etmek için:
```bash
pcsc_scan
```
*(Eğer `pcsc_scan` komutu sisteminizde yoksa `sudo dnf install pcsc-tools` ile yükleyebilirsiniz).*

---

## 🌐 Tarayıcı Entegrasyonu

Paket, aşağıdaki tarayıcılar için Native Messaging Host yapılandırmasını otomatik olarak kurar:
* **Google Chrome:** `/etc/opt/chrome/native-messaging-hosts/com.ark.pw.websigner.json`
* **Microsoft Edge:** `/etc/opt/edge/native-messaging-hosts/com.ark.pw.websigner.json`
* **Chromium:** `/etc/chromium/native-messaging-hosts/com.ark.pw.websigner.json`
* **Mozilla Firefox:** `/usr/lib64/mozilla/native-messaging-hosts/com.ark.pw.websigner.json` ve `/usr/lib/mozilla/...`

Tarayıcınızı yeniden başlattığınızda ArkSigner eklentisi ve yerel servisi otomatik olarak bağlanacaktır.

---

## 🗑️ Paketi Kaldırma

ArkSigner'ı sistemden tamamen kaldırmak için:

```bash
sudo dnf remove arksigner
```
Kaldırma işlemi sırasında çalışan ArkSigner arka plan servisleri sonlandırılır ve tarayıcı ilkeleri otomatik olarak temizlenir.
