<#
    .DESCRIPTION
        This script creates Azure Key Vault Public Network Access Disabled - Audit, Deny, Disable and assigns it to management group
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Mar 03, 2022
    .EXAMPLE 
    .\azure-keyvault-publicanetwork-disabled-policy-assignment-mg.ps1 -tenantId 'your-tenant-id' -managementGroupId 'your-management-group-id'  
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$managementGroupId
)

#Connect to your Azure Account
Connect-AzAccount -TenantId $tenantId

try
{
    # Get Management Group Object
    #$managementGroupId = "your-management-group-name"
    $managementGroup = Get-AzManagementGroup -GroupId $managementGroupId 
    
    #Create New policy definition for Azure Key Vault - Public Access Disabled
    $akvDisablePublicAccessPolicy = New-AzPolicyDefinition -Name 'Azure-KeyVault-PublicNetwork-Disable' -DisplayName 'Azure Key Vaults - Public Network Disabled' -Policy 'AzureKeyVault-PublicNetwork-Deny.json' -ManagementGroupName $managementGroup.Name
    
    #Get object for newly created policy definition
    $akvDisablePublicAccessPolicyDefinition = Get-AzPolicyDefinition -Name $akvDisablePublicAccessPolicy.Name -ManagementGroupName $managementGroup.Name
    
    #Define non-compliance message to be displayed
    $nonComplianceMessages = @(@{Message="Public Network access should be disabled on Azure Key Vaults"})
    
    #Scope for assigning the policy
    $scope = $managementGroup.Id

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name 'AKV-Public-Network-Deny' -PolicyDefinition $akvDisablePublicAccessPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessages

    #Logging for completion of script
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()