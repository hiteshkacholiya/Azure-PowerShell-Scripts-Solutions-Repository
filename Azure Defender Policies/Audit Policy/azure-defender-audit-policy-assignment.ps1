<#
    .DESCRIPTION
        This script creates Azure Defender Audit Policy and assigns it to all subscriptions
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 05, 2022
    .EXAMPLE
        \azure-defender-audit-policy-assignment.ps1 -tenantId 'c12c0dae-7c48-46d6-b2fc-bcad5ab377a0'
#>
param 
(
    [Parameter(Mandatory=$true)][string]$tenantId
)

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted
# Use this for Automation account only
<#-- Initialize Connection & Import Modules --#>
Import-Module -Name Az.Resources
Import-Module -Name Az.Accounts
Import-Module -Name Az.Monitor

$connectionName = "AzureRunAsConnectionName"
$WarningPreference = 'SilentlyContinue'
Write-Host "Started Script at : " (Get-Date).tostring()

<#
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Host $servicePrincipalConnection
    "Logging in to Azure..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch 
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } 
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
#>
<#-- End Region for Initialize Connection & Import Modules --#>

##Use this for local execution

Connect-AzAccount -TenantId $tenantId

# Working on LTM UAT And STAGING Subscriptions
#$allSubscriptions = Get-AzSubscription | Where-Object { $_.Name -eq "LTM-UATSUB" -or $_.Name -eq "LTM-STAGINGSUB" }
$allSubscriptions = Get-AzSubscription

if(($allSubscriptions -ne $null) -and ($allSubscriptions.Count -gt 0))
{
$azureDefenderAuditPolicy = New-AzPolicyDefinition -Name 'AuditAzureDefender' -DisplayName 'Audit Subscription for disabled Azure Defender' -Policy 'AzureDefender-AuditSubscriptions.json'
$defenderPolicy = Get-AzPolicyDefinition -Name $azureDefenderAuditPolicy.Name
$allSubscriptions = Get-AzSubscription

    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        try
        {
            $currentSubscription = Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
            $currentSubscriptionName = $currentSubscription.Name
            Write-Host "Assign Policy for " $currentSubscriptionName " at " (Get-Date).ToString()
            $scope = "/subscriptions/" + $allSubscriptions[$iSub].Id
            New-AzPolicyAssignment -Name 'AzureDefenderPolicyAssignment' -PolicyDefinition $defenderPolicy -Scope $scope
            Write-Host "Policy Assigned for " $currentSubscriptionName " at " (Get-Date).ToString()
        }
        catch
        {
            Write-Host "Exception while assigning policy for " $allSubscriptions[$iSub].Name " at " (Get-Date).ToString()
        }
    }
}

Write-Host "End of Script at : " (Get-Date).ToString()