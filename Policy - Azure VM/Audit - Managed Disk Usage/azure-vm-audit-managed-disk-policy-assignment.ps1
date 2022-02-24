<#
    .DESCRIPTION
        This script creates Azure VM Audit Policy to report all VMs that do not use managed disks and assigns it to all subscriptions
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 25, 2022
    .EXAMPLE
        \azure-vm-audit-managed-disk-policy-assignment -tenantId 'your-tenant-id'
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
    $managedDiskPolicy = Get-AzPolicyDefinition | Where-Object {$_.Properties.DisplayName -eq 'Audit VMs that do not use managed disks' }
    $allSubscriptions = Get-AzSubscription

    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        try
        {
            $currentSubscription = Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
            $currentSubscriptionName = $currentSubscription.Name
            Write-Host "Assign Policy for " $currentSubscriptionName " at " (Get-Date).ToString()
            $scope = "/subscriptions/" + $allSubscriptions[$iSub].Id
            New-AzPolicyAssignment -Name 'AzureManagedDiskPolicyAssignment' -PolicyDefinition $managedDiskPolicy -Scope $scope
            Write-Host "Policy Assigned for " $currentSubscriptionName " at " (Get-Date).ToString()
        }
        catch
        {
            Write-Host "Exception while assigning policy for " $allSubscriptions[$iSub].Name " at " (Get-Date).ToString()
        }
    }
}

Write-Host "End of Script at : " (Get-Date).ToString()