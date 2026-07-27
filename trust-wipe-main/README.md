# TrustWipe (Secure Data Sanitization Platform)

**TrustWipe** is a high-grade, secure desktop data-destruction tool designed to permanently erase files, directories, or entire storage partitions according to secure sanitization principles. Built with a responsive Flutter desktop frontend and a high-performance Windows PowerShell systems backend, TrustWipe guarantees unrecoverable data erasure complying with modern cybersecurity standards.

---

## ✨ Features

- **Drive Sanitization**: Wipes non-OS mounted partitions, including a multi-pass secure overwrite of free space to clear unallocated sectors.
- **Targeted File & Folder Shredder**: Recursively overwrites files in-place, truncates data streams, randomizes filesystem metadata, and unlinks records.
- **Wiping Standards Compliance**: Configurable algorithms:
  - **NIST SP 800-88 Rev 1 (Clear)**: Single-pass zero-fill with full read verification (Default).
  - **DoD 5220.22-M (3-Pass)**: Sequential Zero, One (0xFF), and Random overwrite passes.
  - **Single Pass Zero Fill** & **Single Pass Random Fill**.
- **Real-Time Telemetry**: Real-time throughput speed (MB/s), elapsed time, progress bar, file counters, and console log output.
- **Safety Safeguards**: 
  - Prevents accidental OS drive (`C:`) or system directory (`C:\Windows`, `C:\Program Files`, etc.) wipes.
  - Requires typed string validation (`CONFIRM`) before any destructive action.
- **Sanitization Certificates**: Generates a tamper-evident PDF report containing target metadata, execution duration, a QR verification code, and a SHA-256 cryptographic signature.

---

## 🛠️ Requirements & Installation

1. **Flutter SDK**: Ensure you have Flutter installed and configured for Windows desktop targets. Verify using:
   ```bash
   flutter doctor
   ```
2. **Windows OS**: Target platform is Windows 10 or 11.
3. **Administrative Privileges**: Because low-level partition writes and system handle locks require elevation, **TrustWipe must be run as Administrator**.

---

## 🚀 How to Run the Application

Follow these steps to run TrustWipe in your development environment:

### Step 1: Install Dependencies
Open your terminal at the project root and download package dependencies:
```bash
flutter pub get
```

### Step 2: Run in Development Mode
Execute the Flutter project targeting the Windows platform. Ensure your terminal shell is running with **Administrator privileges**:
```powershell
flutter run -d windows
```

### Step 3: Compile a Release Build
To package a standalone executable build:
```bash
flutter build windows
```
The compiled assets and `.exe` binaries will be output to:
`build\windows\x64\runner\Release\`

---

## 🔒 Security & Conformance

- **NIST SP 800-88 Rev 1**: Logical sanitization overwrites are verified by executing a full read-pass confirming only null patterns exist.
- **Metadata Destruction**: Files are renamed to random string signatures using `[System.IO.Path]::GetRandomFileName()` prior to deletion, removing filenames from Master File Tables (MFT).
- **IPC Safety**: Uses secure newline-delimited JSON messages between the PowerShell subprocess and Flutter to prevent injection vulnerabilities.
