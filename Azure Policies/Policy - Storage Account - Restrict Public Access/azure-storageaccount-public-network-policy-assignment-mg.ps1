<#
    .DESCRIPTION
        This script creates Azure Storage Account Public Network Access policy - Audit/Deny and assigns it to management group
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Mar 10, 2022
    .EXAMPLE 
    .\azure-storageaccount-public-network-policy-assignment-mg.ps1 -tenantId 'your-tenant-id' -managementGroupId 'your-management-group-id' -policyEffect 'Audit/Deny'
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
    #$managementGroupId = "your-management-group-name"
    $managementGroup = Get-AzManagementGroup -GroupId $managementGroupId 
    
    $policyDefinitionName = "SA-PublicNetwork-" + $policyEffect
    $policyDescription = "Azure Storage Account - Public Network " + $policyEffect
    $assignmentName = "SA-PublicNetwork- " + $policyEffect

    #Create New policy definition for Azure Key Vault - Public Access Disabled
    $asaDisablePublicAccessPolicy = New-AzPolicyDefinition -Name $policyDefinitionName -DisplayName $policyDescription -Policy 'AzureStorageAccount-PublicNetwork-Deny-Audit.json' -ManagementGroupName $managementGroup.Name
    
    #Get object for newly created policy definition
    $asaDisablePublicAccessPolicyDefinition = Get-AzPolicyDefinition -Name $asaDisablePublicAccessPolicy.Name -ManagementGroupName $managementGroup.Name
    
    #Define non-compliance message to be displayed
    $nonComplianceMessages = @(@{Message="Public Network access should be disabled on Azure Storage Accounts"})
    
    #Scope for assigning the policy
    $scope = $managementGroup.Id

    #Create Policy Parameter Object
    $policyParameter = @{
        'effect' = $policyEffect.ToString().ToLower()
    }

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name $assignmentName -PolicyDefinition $asaDisablePublicAccessPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessages -PolicyParameterObject $policyParameter

    #Logging for completion of script
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()