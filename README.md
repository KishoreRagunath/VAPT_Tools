# VAPT Toolset

A collection of scripts and security tools for **Vulnerability Assessment and Penetration Testing (VAPT)**.

This project helps simplify the installation, management, and usage of commonly used cybersecurity tools for reconnaissance, enumeration, vulnerability assessment, web application testing, and penetration testing.

> **Disclaimer:** This project is intended only for authorized security testing, cybersecurity labs, educational purposes, and systems where you have explicit permission to perform security testing.

---

## Features

- Automated VAPT tool installation
- Go-based security tool installation
- Python/Pipx-based security tool installation
- Tool uninstall support
- Centralized tool lists
- Easy tool management
- Beginner-friendly setup

---

## Requirements

Make sure the following are installed before using the toolkit:

- Git
- Python 3
- pip / pip3
- pipx
- Go
- Bash
- Required system package manager

Check the installed versions:

```bash
git --version
python3 --version
pip3 --version
pipx --version
go version
```

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/KishoreRagunath/VAPT_Toolset.git
```

### 2. Navigate to the Project

```bash
cd VAPT_Toolset
```

### 3. Give Execute Permission

```bash
chmod +x install.sh
```

If an uninstall script is available:

```bash
chmod +x uninstall.sh
```

### 4. Run the Installer

```bash
sudo ./install.sh
```

The installation script installs the tools according to their respective installation methods.

---

## Tool Lists

### Go Tools

Go-based tools are maintained in:

```text
Go-tools.txt
```

Example:

```bash
go install <tool>@latest
```

The installation script can read the tool list and install the required Go tools automatically.

### Pipx Tools

Python CLI tools are maintained in:

```text
pipx-tools.txt
```

Example:

```bash
pipx install arjun
```

The installation script can process the tool list and install the required Pipx-based tools.

---

## Updating the VAPT Toolset

If the repository is already cloned, use `git pull` to get the latest changes.

### Simple Update

```bash
cd VAPT_Toolset
git pull origin main
```

### Recommended Update Workflow

First check your local changes:

```bash
git status
```

If you have local changes that you want to keep temporarily:

```bash
git stash
```

Update the repository:

```bash
git pull origin main
```

Restore your local changes:

```bash
git stash pop
```

## Usage

After installation, verify a tool:

```bash
which <tool-name>
```

Check the version:

```bash
<tool-name> --version
```

Check available options:

```bash
<tool-name> --help
```

Example:

```bash
arjun --help
```

---

## VAPT Workflow

A typical VAPT workflow can be:

```text
Reconnaissance
      |
      v
Subdomain Enumeration
      |
      v
Technology Fingerprinting
      |
      v
Port & Service Enumeration
      |
      v
URL / Endpoint Discovery
      |
      v
Parameter Discovery
      |
      v
Vulnerability Assessment
      |
      v
Manual Validation
      |
      v
Exploitation
      |
      v
Reporting
```

---

## Tool Categories

### Reconnaissance

- Information gathering
- DNS enumeration
- Subdomain enumeration
- ASN discovery
- Technology fingerprinting

### Network Scanning

- Port scanning
- Service enumeration
- Network discovery
- Vulnerability scanning

### Web Application Testing

- URL discovery
- Parameter discovery
- JavaScript endpoint discovery
- Web vulnerability scanning
- HTTP enumeration

### Vulnerability Assessment

- CVE identification
- Misconfiguration detection
- Web server assessment
- Automated vulnerability detection

### Exploitation

Tools for authorized exploitation and security validation in controlled environments.

---

## Uninstallation

If an uninstall script is available:

```bash
sudo ./uninstall.sh
```

The uninstall script removes tools according to their respective installation methods.

---

## Troubleshooting

### Permission Denied

If you receive:

```text
Permission denied
```

Run:

```bash
chmod +x install.sh
```

Then:

```bash
sudo ./install.sh
```

### Pipx Tool Not Found

Check Pipx:

```bash
pipx --version
```

List installed Pipx tools:

```bash
pipx list
```

Ensure the Pipx path is configured:

```bash
pipx ensurepath
```

Restart the terminal after modifying the PATH.

### Git Pull Conflict

Check the repository status:

```bash
git status
```

Temporarily save local changes:

```bash
git stash
```

Pull the latest changes:

```bash
git pull origin main
```

Restore local changes:

```bash
git stash pop
```

---

## Contributing

Contributions, improvements, bug fixes, and new tool integrations are welcome.

## Legal Disclaimer

This project is intended for:

- Authorized penetration testing
- Vulnerability assessment
- Security research
- Cybersecurity education
- CTF environments
- Personal security labs

Do not use these tools against systems, networks, applications, or infrastructure without proper authorization.

The author is not responsible for misuse, unauthorized access, data loss, damage, or illegal activity performed using this project.

---

## Author

**Kishore Ragunath**

GitHub:  
https://github.com/KishoreRagunath

---

## License

Add the appropriate license for this project.
