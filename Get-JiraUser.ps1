<#
.SYNOPSIS
    Builds a flattened org chart from a list of users by recursively retrieving each user’s manager chain.

.DESCRIPTION
    For each user in the input file, retrieves their full management chain until it ends or loops.
    Outputs one row per user with each manager in a separate column.

.NOTES
    Author: YourName
    Date: 2025-04-16
#>

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

# Set input and output file paths
$inputFile = "C:\temp\users.txt"
$outputFile = "C:\temp\OrgChart.csv"

# Check if input file exists
if (-not (Test-Path -Path $inputFile)) {
    Write-Error "Input file not found: $inputFile"
    exit 1
}

# Read list of user IDs
$userIDs = Get-Content $inputFile | Where-Object { $_.Trim() -ne "" }

# Store all results
$results = @()

foreach ($userID in $userIDs) {
    try {
        $chain = @{}
        $visited = @{}

        # Get starting user
        $user = Get-ADUser -Identity $userID -Properties DisplayName, Manager -ErrorAction Stop
        $level = 0
        $originalUser = $user

        # Add the starting user as Level0
        $chain["Level$level"] = $user.DisplayName
        $visited[$user.DistinguishedName] = $true

        # Traverse up the manager chain
        while ($user.Manager) {
            $manager = Get-ADUser -Identity $user.Manager -Properties DisplayName, Manager -ErrorAction Stop

            if ($visited.ContainsKey($manager.DistinguishedName)) {
                Write-Warning "Detected loop in manager chain for user: $userID"
                break
            }

            $level++
            $chain["Level$level"] = $manager.DisplayName
            $visited[$manager.DistinguishedName] = $true

            $user = $manager
        }

        # Add UserID to the beginning
        $chain["UserID"] = $originalUser.SamAccountName

        # Append to results
        $results += New-Object PSObject -Property $chain

    } catch {
        Write-Warning "Error processing user '$userID': $_"
    }
}

# Export result to CSV
try {
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Org chart successfully exported to $outputFile"
} catch {
    Write-Error "Failed to export CSV: $_"
}
