# 🛠️ PowerShell Scripts Collection

A comprehensive collection of automated PowerShell scripts for system administration, maintenance, and notifications.

> [!WARNING]  
> These scripts are **not** official, nor do they have any guarantee backing them.
> Any script found in this repository is given to the community by the community.

## 🚀 Getting Started

1. **Clone or download** this repository
2. **Review the specific script** you want to use
3. **Update the CONFIGURATION section** with your settings
4. **Test the script** in a safe environment first

## ⚠️ Safety & Best Practices

- 📝 Review script contents before execution
- 🔐 Always test scripts in a **non-production environment** first
- 🔄 Keep scripts updated with security patches
- 💾 **Backup** before running destructive operations (e.g., file cleanup)

## 📁 Repository Structure
If you have certain tool scripts please make a new folder for them.

Also, if it's a script for a specific program please make a new folder for them as well.

Scripts will be organized into category folders once sufficient scripts accumulate in each category.
```
Scripts/
├── Uniflow/
│   └── [uniFLOW SmartClient automation scripts]
└── Immybot/
    └── [Immybot integration scripts]
```

## 📝 Adding New Scripts

We welcome any helpful and safe scripts! 
When adding scripts to this repository, follow these guidelines:

1. **Use the naming convention**: `{Functions}_{Dependencies}_{Context}.ps1`
    - **Functions** - Primary action the script performs (e.g., `UpgradePowershell`, `CheckUpdates`)
    - **Dependencies** - Required modules/tools (e.g., `Chocolatey`, `PSSQLite`)
    - **Context** - Environment or target scope (e.g., `System`, `Users`, `Admin`)

2. **Add a synopsis comment block** at the top:
   ```powershell
   <#
   .SYNOPSIS
       Brief description of what the script does
   .DESCRIPTION
       Detailed explanation of functionality and requirements
   #>
   ```

3. **Include CONFIGURATION section** with editable variables at the top
   Most scripts include a `# CONFIGURATION` section **at the top** where you can customize:
   - 🔔 **ntfy.sh Topic** - Change `$ntfyTopic` for different notification channels
   - 🌐 **ntfy.sh Server** - Modify `$ntfyServer` if using self-hosted instance
   - 📂 **Paths** - Update file paths for your environment
   - ⚙️ **Settings** - Adjust script parameters as needed

   **Example:**
   ```powershell
   # CONFIGURATION
   $ntfyTopic = "Insertyourtopicnamehere"
   $ntfyServer = "https://ntfy.sh"
   ```
   ⚠️ Please make sure to sanitize all configurations that aren't general to all.

4. **Add comments** throughout for clarity

5. **Test thoroughly** before committing

6. **Make a new Branch** Add your scripts and then submit a PR
---
---

## 🔎 Community Repositories

Below are some cool community PowerShell repositories and projects that may be useful for learning, inspiration, or specific admin tasks.

### 🧰 Tools

These are more focused tools or purpose-built projects for a specific use case.

| Repository | Purpose | Notes |
|---|---|---|
| [BornToBeRoot/PowerShell_IPv4NetworkScanner](https://github.com/BornToBeRoot/PowerShell_IPv4NetworkScanner) | Asynchronous IPv4 network scanner | Focused network scanning tool for PowerShell. [1](https://github.com/BornToBeRoot/PowerShell_IPv4NetworkScanner) |
| [last-byte/PersistenceSniper](https://github.com/last-byte/PersistenceSniper) | Windows persistence hunting module | Built for blue teams, incident responders, and sysadmins. [2](https://github.com/last-byte/PersistenceSniper) |
| [Micke-K/IntuneManagement](https://github.com/Micke-K/IntuneManagement) | Intune/Azure policy management tool | Supports export, import, compare, document, and edit workflows with PowerShell and WPF UI. [3](https://github.com/Micke-K/IntuneManagement) |
| [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat?pubDate=20260305) | Windows 10/11 debloat and customization script | Removes preinstalled apps, reduces telemetry, and applies Windows customization changes. [4](https://github.com/Raphire/Win11Debloat?pubDate=20260305) |

### 📚 Collections

These are broader repositories that contain many scripts, modules, or categorized utilities.

| Repository | Focus | Notes |
|---|---|---|
| [ruudmens/LazyAdmin](https://github.com/ruudmens/LazyAdmin) | General SysAdmin script collection | Includes folders for Active Directory, AzureAD, Exchange, Office 365, Teams, Windows, UniFi VPN, and more. [5](https://github.com/ruudmens/LazyAdmin) |
| [fleschutz/PowerShell](https://github.com/fleschutz/PowerShell) | Large cross-platform PowerShell script library | Contains 600+ standalone scripts for Linux, macOS, and Windows. [6](https://github.com/fleschutz/PowerShell) |
| [nickrod518/PowerShell-Scripts](https://github.com/nickrod518/PowerShell-Scripts) | Enterprise admin script collection | Covers SCCM, MSO, AD, Exchange, SharePoint, printers, updates, and more. [7](https://github.com/nickrod518/PowerShell-Scripts) |
| [jhochwald/PowerShell-collection](https://github.com/jhochwald/PowerShell-collection) | PowerShell scripts, tools, and modules | Includes categories like Active Directory, AzureAD, Exchange, Graph, Intune, Microsoft 365, Teams, UniFi, and WSUS. [8](https://github.com/jhochwald/PowerShell-collection) |
| [bastienperez/PowerShell-Toolbox](https://github.com/bastienperez/PowerShell-Toolbox) | Small utility/toolbox repository | A set of useful PowerShell scripts and helper utilities. [9](https://github.com/bastienperez/PowerShell-Toolbox) |

> [!NOTE]
> External repositories listed here are maintained by their respective authors.
> Please review all scripts carefully before use and test in a safe environment first.

**Last Updated:** March 2026 | **Version:** 1.0