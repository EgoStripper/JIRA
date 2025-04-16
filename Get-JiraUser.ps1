# ===========================================
# Export Jira Users (Active & Inactive) with License Info and Last Login
# Compatible with Jira Data Center using Crowd
# Author: ChatGPT (PowerShell Guru Mode)
# ===========================================

# ========== CONFIGURATION ==========
$JiraBaseUrl    = "https://your-jira-url.com"  # CHANGE ME
$Username       = "jira_admin"                 # CHANGE ME
$ApiToken       = "your_api_token_or_password" # CHANGE ME
$OutputFile     = "C:\Temp\users.csv"
$BatchSize      = 100                          # Jira pagination limit

# ========== AUTH ==========
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username:$ApiToken"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    Accept        = "application/json"
}

# ========== FUNCTION ==========
function Get-AllJiraUsers {
    $startAt = 0
    $allUsers = @()

    Write-Host "Fetching active and inactive users from Jira..." -ForegroundColor Cyan

    do {
        $url = "$JiraBaseUrl/rest/api/2/user/search?startAt=$startAt&maxResults=$BatchSize&includeInactive=true&username=%"

        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop

            foreach ($user in $response) {
                # Get user details
                $userUrl = "$JiraBaseUrl/rest/api/2/user?username=$($user.name)"
                $userDetail = Invoke-RestMethod -Uri $userUrl -Headers $headers -Method Get -ErrorAction Stop

                $groupList = @()
                if ($userDetail.groups.items) {
                    $groupList = $userDetail.groups.items | ForEach-Object { $_.name }
                }

                # Guess license type based on group membership (may vary per org setup)
                $licenseType = if ($groupList -match "jira-software-users") {
                    "Jira Software"
                } elseif ($groupList -match "jira-servicedesk-users") {
                    "Jira Service Management"
                } elseif ($groupList -match "jira-core-users") {
                    "Jira Core"
                } else {
                    "Unlicensed or Custom"
                }

                $lastLogin = if ($userDetail."active") {
                    $userDetail."lastLogin"  # May be null if Crowd is not syncing login info
                } else {
                    "Inactive"
                }

                $allUsers += [PSCustomObject]@{
                    Username      = $user.name
                    DisplayName   = $user.displayName
                    Email         = $user.emailAddress
                    Active        = $user.active
                    License       = $licenseType
                    Groups        = $groupList -join ", "
                    LastLogin     = if ($lastLogin) { $lastLogin } else { "Unknown" }
                }
            }

            $startAt += $response.Count
        } catch {
            Write-Error "Error fetching users: $_"
            break
        }

    } while ($response.Count -ge $BatchSize)

    return $allUsers
}

# ========== EXECUTION ==========
try {
    $users = Get-AllJiraUsers

    if ($users.Count -eq 0) {
        Write-Warning "No users retrieved!"
    } else {
        $users | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Export complete. File saved to: $OutputFile" -ForegroundColor Green
    }
} catch {
    Write-Error "❌ Script execution failed: $_"
}
