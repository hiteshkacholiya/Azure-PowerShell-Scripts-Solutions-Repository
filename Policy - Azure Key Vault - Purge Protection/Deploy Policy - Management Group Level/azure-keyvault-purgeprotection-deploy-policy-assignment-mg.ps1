<#
    .DESCRIPTION
        This script creates Azure Key Vault Purge Protection Policy - Audit, Deny, Disable and assigns it to management group
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Feb 21, 2022
    .EXAMPLE 
    .\azure-keyvault-purgeprotection-deploy-policy-assignment-mg.ps1 -tenantId 'your-tenant-id'    
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId
)

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted
# Use this for Automation account only
<#-- Initialize Connection & Import Modules --#>
<#Import-Module -Name Az.Resources
Import-Module -Name Az.Accounts
Import-Module -Name Az.Monitor
Import-Module -Name Az.Security#>
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
    # Get Management Group Object
    $managementGroupId = "gitcollab-root-mg"
    $managementGroup = Get-AzManagementGroup -GroupId $managementGroupId 
    $akvPurgeProtectionPolicy = New-AzPolicyDefinition -Name 'Audit-KeyVault-PurgeProtection-Enabled' -DisplayName 'Azure Key Vaults - Purge Protection should be Enabled' -Policy 'AzureKeyVault-PurgeProtection-Enabled-Audit-Deny-Disabled.json' -ManagementGroupName $managementGroup.Name
    $akvPurgeProtectionPolicyDefinition = Get-AzPolicyDefinition -Id $akvPurgeProtectionPolicy.ResourceId
    $nonComplianceMessages = @(@{Message="Purge Protection should be Enabled on Azure Key Vaults"})
    $scope = "/providers/Microsoft.Management/managementGroups/"+ $managementGroupId
    New-AzPolicyAssignment -Name 'AKV-Purge-Enabled' -PolicyDefinition $akvPurgeProtectionPolicyDefinition -Scope $scope
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()