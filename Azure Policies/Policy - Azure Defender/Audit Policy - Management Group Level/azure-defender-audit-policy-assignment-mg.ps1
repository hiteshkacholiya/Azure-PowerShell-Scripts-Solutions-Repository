<#
    .DESCRIPTION
        This script creates Azure Defender Audit Policy and assigns it at Management Group Level - Root Management Group
    .NOTES
        AUTHOR: 
        LAST EDIT: Feb 21, 2022
    .EXAMPLE
        \azure-defender-audit-policy-assignment-mg.ps1 -tenantId 'your-tenant-id'
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

#Connect-AzAccount -TenantId $tenantId
try
{
    $managementGroupName = "Your-Management-Group-Name"
    $azureDefenderAuditPolicy = New-AzPolicyDefinition -Name 'AuditAzureDefender' -DisplayName 'Audit Subscription for disabled Azure Defender' -Policy 'AzureDefender-AuditSubscriptions.json' -ManagementGroupName "Tenant Root Group"
    $defenderPolicy = Get-AzPolicyDefinition -Name $azureDefenderAuditPolicy.Name
    $managementGroupId = Get-AzManagementGroup -GroupName $managementGroupName
    $scope = "/providers/Microsoft.Management/managementGroups/"+ $managementGroupId
    New-AzPolicyAssignment -Name 'AzureDefenderPolicyAssignment' -PolicyDefinition $defenderPolicy -Scope $scope
    Write-Host "Policy Assigned for " $$managementGroupName " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}
Write-Host "End of Script at : " (Get-Date).ToString()