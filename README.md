
# 🖥️ System Health Diagnostic Tool (PowerShell)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/OS-Windows-lightgrey?logo=windows)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## 🔍 Overview

This **PowerShell script** provides a **comprehensive system health report** for Windows PCs.  
It gathers key metrics, checks for potential issues, and presents results in a **color-coded, easy-to-read console output**.  

The tool is **read-only**, making it safe for audits, IT administration, and system monitoring. The project was created
with **SAPIEN Powershell Studio 2026**.

<img width="942" height="703" alt="image" src="https://github.com/user-attachments/assets/80108c06-a194-4e39-9717-b5d5d9e5f245" />

---

## ⚡ Features

- 🖥️ **System Information**
  - 🏷️ Computer Name  
  - 🪟 Windows Version & Build (e.g., 23H2)  
  - 💻 Model & Manufacturer  
  - 🔑 Serial Number  
  - 📡 MAC Addresses  

- 💡 **System Health Overview**
  - ⏱️ PC Uptime & Last Boot  
  - 🔝 Top CPU-consuming processes  
  - 💾 Disk usage & low-space warnings  
  - 🛠️ Driver issues detection  
  - 🌐 Network connectivity & DNS  

- 🛡️ **Security Posture**
  - 🔑 Windows Activation Status  
  - 🔥 Firewall Status  
  - 🛡️ Windows Defender Status  
  - ⚠️ UAC Status  

- 📰 **Event Logs**
  - 📝 Critical & Error events (last 72 hours)

- 🔄 **Windows Updates**
  - ⏳ Pending updates (read-only)  
  - 🔔 Reboot required notifications  

- 🔧 **Reboot Detection**
  - 🛑 System reboot pending check

- 🎨 **ANSI Color Support**
  - Works in **Windows Terminal**, **VS Code PowerShell terminal**, or fallback to default colors.

---

## ⚙️ Requirements

- Windows 10 / 11 or Server 2016+  
- PowerShell 5.1 or later  
- Run **as Administrator** for full results  
- Optional: Windows Defender module (`Get-MpComputerStatus`)

---

## 📥 Installation

1. Clone the repository:

```powershell
git clone https://github.com/yourusername/SystemHealthDiagnosticTool.git
