# Run PowerShell as Administrator

# Step 1: (Optional) Check current edition
DISM /online /Get-CurrentEdition

# Step 2: (Optional) Confirm Pro is an available upgrade target
DISM /online /Get-TargetEditions

# Step 3: Switch edition to Pro using the generic key (does NOT activate, just unlocks Pro)
changepk.exe /productkey VK7JG-NPHTM-C97JM-9MPGT-3V66T

# Step 4: Reboot to complete the edition switch
shutdown /r /t 0
# --- After reboot, run the following ---

# Step 5: Install your valid Pro license key
slmgr.vbs /ipk YOUR-REAL-PRO-KEY-HERE

# Step 6: Activate
slmgr.vbs /ato