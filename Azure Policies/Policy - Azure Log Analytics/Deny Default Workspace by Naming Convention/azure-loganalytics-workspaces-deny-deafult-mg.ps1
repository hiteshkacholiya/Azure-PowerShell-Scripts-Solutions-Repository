<#
    .DESCRIPTION
        This script creates a policy that will deny creation of any new default log analytic workspaces.
    .NOTES
        PRE-REQUISITES: Account used to execute this script needs to have Owner/User Access Administrator access along with Management Group Reader/Contributor
        AUTHOR: 
        LAST EDIT: Mar 28, 2022
    .EXAMPLE 
    .\azure-loganalytics-workspaces-deny-deafult-mg.ps1 -tenantId 'your-tenant-id' -managementGroupId 'your-management-group-id'
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
    $lawDefaultDenyPolicy = New-AzPolicyDefinition -Name 'LAW-Default-Deny' -DisplayName 'Log Analytic Workspace - Default Workspaces not allowed' -Policy 'LogAnalytics-Workspace-Default-Deny.json' -ManagementGroupName $managementGroup.Name
    
    #Get object for newly created policy definition
    $lawDefaultDenyPolicyDefinition = Get-AzPolicyDefinition -Name $lawDefaultDenyPolicy.Name -ManagementGroupName $managementGroup.Name

    #Define non-compliance message to be displayed
    $nonComplianceMessages = @(@{Message="Default Log Analytic Workspaces are not allowed to be created."})
    
    #Scope for assigning the policy
    $scope = $managementGroup.Id

    #Create the Policy Assignment on scope selected
    New-AzPolicyAssignment -Name 'LAW-Default-Deny' -PolicyDefinition $lawDefaultDenyPolicyDefinition -Scope $scope -NonComplianceMessage $nonComplianceMessages

    #Logging for completion of script
    Write-Host "Policy Assigned for " $managementGroup.Name " at " (Get-Date).ToString()
}
catch
{
    Write-Error -Message $_.Exception
}

Write-Host "End of Script at : " (Get-Date).ToString()