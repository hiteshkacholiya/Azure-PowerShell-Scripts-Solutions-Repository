<#
    .DESCRIPTION
        This script creates an audit policy for Azure Storage Accounts which mandates the usage of Private Links for all storage accounts.
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Mar 15, 2022
    .EXAMPLE 
    .\azure-storageaccount-privatelinks-audit-assignment-mg.ps1 -tenantId 'your-tenant-id' -managementGroupId 'your-management-group-d' -policyEffect 'AuditIfNotExists'
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$managementGroupId,
    [Parameter(Mandatory=$true)][string]$policyEffect
)

#Connect to your Azure Account
#Connect-AzAccount -TenantId $tenantId

try
{
    # Get Management Group Object
    $managementGroup = Get-AzManagementGroup -GroupId $managementGroupId 
    
    #Create New policy definition for Azure Key Vault - Public Access Disabled
    $saMandatePrivateLinkPolicy = New-AzPolicyDefinition -Name 'SA-PrivateLink-Mandatory' -DisplayName 'Azure Storage Accounts - Private Link Mandatory' -Policy 'AzureStorageAccount-PrivateLink-Audit.json' -ManagementGroupName $managementGroup.Name
    
    #Get object for newly created policy definition
    $saMandatePrivateLinkPolicyDefinition = Get-AzPolicyDefinition -Name $saMandatePrivateLinkPolicy.Name -ManagementGroupName $managementGroup.Name
    
    #Define non-compliance message to be displayed
    $nonComplianceMessages = @(@{Message="Private Links should be enabled for Azure Storage Accounts"})
    
    #Scope for assigning the policy
    $scope = $managementGroup.Id

    #Create Policy Parameter Object
    $policyParameter = @{
        'effect' = $policyEffect
    }

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name 'SA-PrivateLink-Mandatory' -PolicyDefinition $saMandatePrivateLinkPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessages -PolicyParameterObject $policyParameter

    #Logging for completion of script
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()