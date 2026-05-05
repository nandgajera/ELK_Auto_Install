# ELK 9.x Automated Stack Installer

An automated Bash script to deploy **Elastic Stack 9.x (Elasticsearch + Kibana)** on Debian-based Linux systems with minimal manual effort. The script follows Elastic’s recommended installation steps, configures core settings, and securely captures all required credentials in a single file.

This installer is ideal for:

* Security labs and penetration testing environments
* Dev/Test deployments
* Rapid proof-of-concept setups
* Learning and training environments

---

## What This Script Does

* Adds the official **Elastic 9.x APT repository and GPG key**
* Installs:

  * Elasticsearch 9.x
  * Kibana 9.x
  * Required dependencies (`gnupg2`, `wget`)
* Configures:

  * `network.host: 0.0.0.0`
  * `http.port: 9200`
  * Kibana `server.host: 0.0.0.0`
  * Kibana `server.port: 5601`
  * JVM Heap: `-Xms4g -Xmx4g`
* Starts and enables services via **systemd**
* Automatically:

  * Resets and captures the **elastic** user password
  * Generates a **Kibana enrollment token**
  * Extracts the **Kibana OTP** from logs
  * Generates Kibana encryption keys
* Creates a neatly formatted credentials file: `ELK_password.txt`

---

## Architecture Overview

```
Elasticsearch (9200)  <--->  Kibana (5601)
      |
      | (Enrollment Token)
      v
   Secure Pairing
```

---

## 🔧 System Requirements (From Official Installation Guide)

These are the recommended resources for running Elastic Stack 9.x: 

### **Minimum (Test / Lab / Dev)**

* **RAM:** 8 GB
* **CPU:** 4 cores
* **Storage:** Depends on data volume and retention

### **Recommended (Production)**

* **RAM:** 64 GB or more (depending on data ingestion and retention)
* **CPU:** 8+ cores (more is better for performance)
* **Storage:** Sized based on:

  * Daily log ingestion rate
  * Retention period
  * Number of indices/shards

> ⚠️ The script sets JVM heap to **4GB** by default. Adjust if your system has less memory.

---

## 🖥️ Supported Operating Systems

* Ubuntu 22.04 / 24.04
* Debian 11 / 12
* Kali Linux
* Any Debian-based distribution with `apt`

---

## Usage

```bash
sudo su
git clone https://github.com/nandgajera/ELK_Auto_Install.git
cd ELK_AUTO_Install
chmod +x ELK_Automation.sh
./ELK_Automation.sh
```
<img width="1780" height="1786" alt="image" src="https://github.com/user-attachments/assets/2676f8ec-0f26-4e5e-9b08-22940dad7f18" />

---

## What Happens During Installation (Step-by-Step)

1. Update system repositories
2. Install `gnupg2` and `wget`
3. Add Elastic GPG key and repository
4. Install Elasticsearch
5. Configure Elasticsearch (network, port, JVM heap)
6. Start Elasticsearch and reset `elastic` password
7. Install Kibana
8. Configure Kibana and generate encryption keys
9. Extract Kibana OTP from logs
10. Generate Kibana enrollment token
11. Save everything to `ELK_password.txt`

---

## Output: `ELK_password.txt`

After successful installation, you will find:

```
cat ELK_password.txt
```

This file contains:

* ✅ Kibana URL
* ✅ Kibana OTP
* ✅ Elastic username: `elastic`
* ✅ Elastic password
* ✅ Kibana enrollment token (wrapped for readability)

---
<img width="1537" height="822" alt="image" src="https://github.com/user-attachments/assets/d6bcf7a4-bd2e-421c-a0c8-d405464dc883" />

## Accessing Kibana

Once the script finishes, open in your browser:

```
http://<SERVER_IP>:5601
```

You will be prompted for the **Kibana OTP** (taken from `ELK_password.txt`).

---

## ⚠️ Security Notes

* This script exposes Elasticsearch and Kibana on **0.0.0.0** (all interfaces).
* **Do NOT use this in production without:**

  * Firewall rules
  * TLS/HTTPS
  * Authentication hardening
  * Network segmentation

---

## 🛠 Troubleshooting

### Elasticsearch not starting?

```bash
journalctl -u elasticsearch --no-pager -n 200
```

### Kibana not starting?

```bash
journalctl -u kibana --no-pager -n 200
```

### Check ports

```bash
ss -altnp | grep -E "9200|9300|5601"
```

---

## Author Note

Created for fast, repeatable ELK 9.x deployments in lab and security testing environments.

Feel free to fork, modify, and improve!
