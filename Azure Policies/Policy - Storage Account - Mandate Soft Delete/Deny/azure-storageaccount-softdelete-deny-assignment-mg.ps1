<#
    .DESCRIPTION
        This script creates a policy that will deny any new storage account creation if soft deletes are not enabled for the blobs, containers and fileshares.
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Mar 18, 2022
    .EXAMPLE 
    .\azure-storageaccount-softdelete-deny-assignment-mg.ps1 -tenantId 'your-tenant-id' -managementGroupId 'your-management-group-id'
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$managementGroupId
)

#Connect to your Azure Account
#Connect-AzAccount -TenantId $tenantId

try
{
    # Get Management Group Object
    $managementGroup = Get-AzManagementGroup -GroupId $managementGroupId 
    
    #Create New policy definition for Azure Key Vault - Public Access Disabled
    $saSoftDeleteDenyPolicy = New-AzPolicyDefinition -Name 'SA-SoftDelete-Deny' -DisplayName 'Azure Storage Accounts - Soft Delete Required for Blobs & Containers' -Policy 'AzureStorageAccount-SoftDelete-Deny-BlobsContainers.json' -ManagementGroupName $managementGroup.Name
    
    #Create New policy definition for Azure Key Vault - Public Access Disabled
    $saFSSoftDeleteDenyPolicy = New-AzPolicyDefinition -Name 'SA-SoftDelete-FS-Deny' -DisplayName 'Azure Storage Accounts - Soft Delete Required for File Shares' -Policy 'AzureStorageAccount-SoftDelete-Deny-FileShares.json' -ManagementGroupName $managementGroup.Name

    #Get object for newly created policy definition
    $saSoftDeleteDenyPolicyDefinition = Get-AzPolicyDefinition -Name $saSoftDeleteDenyPolicy.Name -ManagementGroupName $managementGroup.Name

    #Get object for newly created policy definition
    $saFSSoftDeleteDenyPolicyDefinition = Get-AzPolicyDefinition -Name $saFSSoftDeleteDenyPolicy.Name -ManagementGroupName $managementGroup.Name
    
    #Define non-compliance message to be displayed
    $nonComplianceMessages = @(@{Message="Soft Delete must be enabled on blobs & containers in Storage Account"})

    #Define non-compliance message to be displayed
    $nonComplianceMessagesFS = @(@{Message="Soft Delete must be enabled on file shares in Storage Account"})
    
    #Scope for assigning the policy
    $scope = $managementGroup.Id

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name 'SA-SoftDelete-Deny' -PolicyDefinition $saSoftDeleteDenyPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessages

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name 'SA-SoftDelete-FS-Deny' -PolicyDefinition $saFSSoftDeleteDenyPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessagesFS

    #Logging for completion of script
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()