# 🛡️ System Audit Tool Dashboard

A cross-platform, real-time auditing dashboard for **Windows and Linux** systems. Detects OS, executes security scripts, streams terminal output, and generates downloadable PDF audit reports. Designed to meet **CIS Benchmark** standards with a beautiful dark/light responsive UI.

---

## 🌐 Live Preview

![image](https://github.com/user-attachments/assets/7a61646c-e2ee-46db-bee5-6074762d2477)

![image](https://github.com/user-attachments/assets/0029f652-463e-4e9b-b1ee-beaf54fa32eb)

## 📦 Features

* 🔍 **Automatic OS Detection**
* 📜 **Dynamic Script Loading** based on OS
* ✅ **Modular Audits** using PowerShell and Bash
* 📡 **Real-Time Output Streaming** with SSE (Server-Sent Events)
* 🧾 **PDF Report Generation**
* 🎨 **Elegant Dark & Light Theme Toggle**
* 💡 **CIS-Aligned Recommendations** for each script

---

## 🧰 Technologies Used

| Layer     | Tech Stack                                                |
| --------- | --------------------------------------------------------- |
| Frontend  | HTML, CSS, JS                                             |
| Styling   | CSS3 with CSS Variables, Google Fonts (Inter, Space Mono) |
| Backend   | Flask (Python)                                            |
| Streaming | SSE (Server-Sent Events)                                  |
| Scripting | PowerShell (.ps1), Bash (.sh)                             |
| Reporting | wkhtmltopdf / ReportLab (PDF)                             |

---

## 🗂️ Folder Structure

```
project-root/
├── app.py                      # Flask backend
├── static/
│   └── style.css              # Dark & light theme styles
├── templates/
│   └── index.html            # Frontend dashboard
├── scripts/
│   ├── windows/*.ps1         # Windows audit scripts
│   └── linux/*.sh            # Linux audit scripts
├── reports/                   # Generated PDF audit reports
├── utils.py, config.py        # Utility modules
└── README.md
```

---

## 🚀 Getting Started

### 🖥️ Prerequisites

* Python 3.8+
* pip dependencies:

  ```bash
  pip install flask
  pip install pdfkit
  ```
* (Optional) Install `wkhtmltopdf` for better PDF output.

### 🏃‍♂️ Run Locally

```bash
python app.py
```

Then open your browser at: `http://localhost:5000`

---

## 📋 Audit Scripts

Each script outputs:

* ✅ Status of that component
* 📄 Configuration details
* 🔒 CIS-aligned Recommendations

Example:

```
🔹 Profile: MyHomeWiFi
   SSID           : MyHome
   Authentication : WPA2
   Encryption     : AES
   Conn Mode      : Auto
RECOMMENDATION: Remove unused profiles and avoid open networks.
```

---

## 🎨 Theme Toggle

* Accessible dark/light toggle
* Gold/green glowing buttons and panels
* Modern UI with hover effects, smooth transitions, and responsive design

---

## 📃 Sample Output

```
--- Running: Bluetooth Audit (6.bt.ps1) ---
Connected Bluetooth Device: Logitech MX Master 3
RECOMMENDATION: Disable unused Bluetooth devices to reduce attack surface.
```

---

## 🧠 Project Purpose

Built for final year engineering projects, system admins, and security audits. Combines frontend polish with backend power. Aligns with **CIS Benchmarks** for responsible system hardening.

---

## 📄 License

MIT License

---

> Designed & Developed with 💛 by Sai Hima Snehith Matwada
