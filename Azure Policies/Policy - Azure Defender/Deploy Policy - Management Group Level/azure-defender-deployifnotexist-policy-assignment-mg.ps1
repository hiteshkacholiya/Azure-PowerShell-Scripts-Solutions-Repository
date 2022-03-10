<#
    .DESCRIPTION
        This script creates Azure Defender DeployIfNotExist Policy and assigns it to management group - root management group
    .NOTES
        AUTHOR: 
        LAST EDIT: Feb 21, 2022
    .EXAMPLE 
    .\azure-defender-deployifnotexist-policy-assignment.ps1 -tenantId 'your-tenant-id'    
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
Import-Module -Name Az.Security
<#

$connectionName = "AzureRunAsConnectionName"
$WarningPreference = 'SilentlyContinue'
Write-Host "Started Script at : " (Get-Date).tostring()

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

Connect-AzAccount -TenantId $tenantId

try
{
    Write-Host "Trying provider registeration at " (Get-Date).ToString()
    Register-AzResourceProvider -ProviderNamespace 'Microsoft.Security'
    Write-Host "Completed provider registeration at " (Get-Date).ToString()    
}
catch
{
    Write-Host "Error encountered during provider registeration at " (Get-Date).ToString()
}

# Working on LTM UAT And STAGING Subscriptions
#$allSubscriptions = Get-AzSubscription | Where-Object { $_.Name -eq "LTM-UATSUB" -or $_.Name -eq "LTM-STAGINGSUB" }
$allSubscriptions = Get-AzSubscription

try
{
    $managementGroupName = "Your-Management-Group-Name"    
    $azureDefenderDeployIfNotExistPolicy = New-AzPolicyDefinition -Name 'DeployIfNotExistAzureDefender' -DisplayName 'Deploy Azure Defender (if not exist) for Subscriptions' -Policy 'AzureDefender-DeployIfNotExists-Subscriptions.json' -ManagementGroupName "Tenant Root Group"
    $defenderPolicy = Get-AzPolicyDefinition -Name $azureDefenderDeployIfNotExistPolicy.Name
    $managementGroupId = Get-AzManagementGroup -GroupName $managementGroupName
    $nonComplianceMessages = @(@{Message="Azure Defender is not deployed for subscription"})
    $scope = "/providers/Microsoft.Management/managementGroups/"+ $managementGroupId
    New-AzPolicyAssignment -Name 'AzureDefenderPolicyAssignment' -PolicyDefinition $defenderPolicy -Scope $scope
    Write-Host "Policy Assigned for " $$managementGroupName " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()