# 📱 iPhone-Windows-Seamless-Transfer

> **Easy SMB File Sharing Between iPhone and Windows PC**

A simple Windows batch script that sets up a secure local SMB share for seamless file transfer between your iPhone and Windows PC. The script automatically handles all configuration, permissions, and firewall setup.

---

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [iPhone Connection Guide](#iphone-connection-guide)
- [Guidelines](#guidelines)
- [Troubleshooting](#troubleshooting)
- [Security & Cleanup](#security--cleanup)
- [License](#license)

---

## Prerequisites

- **Windows 10/11** (Home, Pro, or Enterprise Edition)
- **Administrator Privileges** - The script will automatically request elevated permissions
- **iPhone** with iOS 12 or later (with Files app)
- Both devices on the **same network**

---

## Quick Start

1. **Run the script:**
   - Simply double-click `run.bat` from the repository root
   - Click "Yes" when prompted to elevate to Administrator

2. **Follow the interactive prompts:**
   - Enter a username (or press ENTER for default: `AppleUser`)
   - Enter a strong password (required)
   - Specify a folder path (or press ENTER for default: `C:\shared_folder`)

3. **Done!** Your SMB share is now active and ready

---

## Configuration

### Default Settings
| Setting | Value |
|---------|-------|
| **Username** | `AppleUser` |
| **Shared Folder** | `C:\shared_folder` |
| **SMB Port** | TCP 445 |
| **Network Profile** | Private |

### What the Script Does
✓ Creates a local Windows user account  
✓ Configures shared folder with proper permissions  
✓ Sets network profile to Private  
✓ Opens SMB firewall rules  
- Sets the SMB server service to start automatically on boot
- Restarts file-sharing services
✓ Generates connection details file  

---

## iPhone Connection Guide

### Step-by-Step Instructions

1. **Open the Files app** on your iPhone
2. **Tap the "Browse" tab** (bottom right)
3. **Tap the "..." menu** (top right corner)
4. **Select "Connect to Server"**
5. **Enter the server address:**
   ```
   smb://[YOUR_PC_IP_ADDRESS]
   ```
   ➜ Find your PC's IP in the `iPhone_Share_Details.txt` file

6. **Choose "Registered User"** and enter:
   - Username: (as configured)
   - Password: (as configured)

7. **Tap "Connect"** — Your PC share is now in your iPhone's Files app!

### Finding Your PC's IP Address
The connection details are automatically saved in:
```
C:\shared_folder\iPhone_Share_Details.txt
```

---

## Guidelines

### Best Practices
- **Strong Password:** Use a complex password with uppercase, lowercase, numbers, and symbols
- **Same Network:** Ensure your iPhone and PC are connected to the same Wi-Fi network
- **Private Network:** Keep your network profile set to Private for security
- **Firewall:** Do not disable Windows Firewall; the script only opens the necessary SMB port
- **Regular Use:** Keep the shared folder organized to avoid clutter

### Security Recommendations
- ⚠️ **Do not share your SMB address on public networks**
- ⚠️ **Use unique passwords** — don't reuse passwords from other accounts
- ⚠️ **Only access from trusted devices**
- ⚠️ **Clean up old shares** when no longer needed (see cleanup instructions below)

### When to Use This Solution
✅ Home networks with trusted devices  
✅ Personal file transfers on LAN  
✅ Temporary quick access setups  
❌ Public WiFi networks  
❌ Untrusted networks  
❌ Production/business environments  

---

## Troubleshooting

### Cannot Connect from iPhone

| Issue | Solution |
|-------|----------|
| **"Connection Timeout"** | Verify PC's IP address in `iPhone_Share_Details.txt` |
| **"Permission Denied"** | Check username/password — ensure they're correct |
| **"Server Not Found"** | Verify both devices are on the **same network** |
| **Firewall Block** | Check Windows Firewall settings; port 445 should be open |
| **Network Profile** | Ensure network is set to **Private** (not Public) |

### Common Commands for Diagnostics

Check your PC's IPv4 address:
```bash
ipconfig /all
```

Verify SMB is running:
```bash
net view \\localhost
```

---

## Security & Cleanup

### Removing the Share

When you no longer need the share, remove it with these commands in Command Prompt (Run as Administrator):

**Remove the SMB share:**
```bash
net share "AppleUser_Share" /delete
```

**Remove the local user account:**
```bash
net user AppleUser /delete
```

**Close SMB firewall port (Optional):**
```bash
netsh advfirewall firewall delete rule name="SMB Port 445"
```

---

## License

This project is provided **as-is** with no warranty. Use at your own risk.  
See [LICENSE](LICENSE) file for full details.

---

**Made for easy local file sharing. Questions? Check the troubleshooting section above.** 🎉
