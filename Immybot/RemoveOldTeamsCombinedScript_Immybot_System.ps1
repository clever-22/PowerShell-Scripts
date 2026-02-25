#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Removes Microsoft Teams (Classic) local data folders using Get/Set/Test pattern.
.PARAMETER Method
    The method to execute: get, set, or test
#>

#Add a parameter called: "Remove" set to text and default to true

# -- Configuration --
$targetRelativePaths = @( 
    "AppData\Local\Microsoft\Teams\current", 
    "AppData\Local\Microsoft\Teams" 
)

# -- Helper Function --
function Get-ExistingTeamsPaths {
    $foundPaths = @()
    # Get all real user directories (exclude system/default profiles)
    $userDirs = Get-ChildItem -Path "C:\Users" -Directory -Exclude "Public", "Default*", "All Users" -ErrorAction SilentlyContinue
    
    foreach ($dir in $userDirs) {
        foreach ($relPath in $targetRelativePaths) {
            $fullPath = Join-Path -Path $dir.FullName -ChildPath $relPath
            if (Test-Path -Path $fullPath) {
                $foundPaths += $fullPath
            }
        }
    }
    return $foundPaths
}

# -- Main Logic --
switch ($Method) {
    "get" {
        # GET returns the current state. 
        # We return the list of paths found. If empty, it's already clean.
        $currentPaths = Get-ExistingTeamsPaths
        if ($currentPaths.Count -eq 0) {
            Write-Host "No Teams paths found. System is clean."
            return "Clean"
        }
        else {
            Write-Host "Found $($currentPaths.Count) paths: $($currentPaths -join ', ')"
            return "$($currentPaths.Count) Paths Found"
        }
    }

    "set" {
        # SET performs the actual removal
        $pathsToDelete = Get-ExistingTeamsPaths
        foreach ($path in $pathsToDelete) {
            try {
                Write-Host "Deleting: $path"
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to delete $path : $_"
            }
        }
    }

    "test" {
        # TEST returns $true if the desired state is met (No paths should exist)
        $remainingPaths = Get-ExistingTeamsPaths
        if ($remainingPaths.Count -eq 0) {
            Write-Host "Test Passed: No Teams folders exist."
            return $true
        }
        else {
            Write-Host "Test Failed: $($remainingPaths.Count) paths still exist."
            return $false
        }
    }
}