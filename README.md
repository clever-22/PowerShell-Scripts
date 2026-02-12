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

1. **Use the naming convention**: `{Dependencies}-{Dependencies}_{Functions}_{Context}.ps1`
    - **Dependencies** - Required modules/tools (e.g., `Chocolatey`, `PSSQLite`)
    - **Functions** - Primary action the script performs (e.g., `UpgradePowershell`, `CheckUpdates`)
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

**Last Updated:** February 2026 | **Version:** 1.0
