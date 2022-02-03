<#
    .DESCRIPTION
        This script creates Azure Defender DeployIfNotExist Policy and assigns it to all subscriptions
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 07, 2022
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

if(($allSubscriptions -ne $null) -and ($allSubscriptions.Count -gt 0))
{
    $azureDefenderDeployIfNotExistPolicy = New-AzPolicyDefinition -Name 'DeployIfNotExistAzureDefender' -DisplayName 'Deploy Azure Defender (if not exist) for Subscriptions' -Policy 'AzureDefender-DeployIfNotExists-Subscriptions.json'
    $defenderPolicy = Get-AzPolicyDefinition -Name $azureDefenderDeployIfNotExistPolicy.Name
    $nonComplianceMessages = @(@{Message="Azure Defender is not deployed for subscription"})

    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        try
        {
            $currentSubscription = Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
            $currentSubscriptionName = $currentSubscription.Name
            Write-Host "Assign Policy for " $currentSubscriptionName " at " (Get-Date).ToString()
            $scope = "/subscriptions/" + $allSubscriptions[$iSub].Id
            
            <#New-AzPolicyAssignment -Name 'AzureDefenderDeployIfNotExistPolicyAssignment' -Scope $scope `
            -PolicyDefinition $defenderPolicy -NonComplianceMessage $nonComplianceMessages -AssignIdentity -Location uksouth
            #>

            #If not using default values, then uncomment this command & comment the above one.
             New-AzPolicyAssignment -Name 'AzureDefenderDeployIfNotExistPolicyAssignment' -Scope $scope `
            -PolicyDefinition $defenderPolicy -PolicyParameter .\InputValues.json  -NonComplianceMessage $nonComplianceMessages -AssignIdentity -Location uksouth
            

            Write-Host "Policy Assigned for " $currentSubscriptionName " at " (Get-Date).ToString()
        }
        catch
        {
            Write-Host "Exception while assigning policy for " $allSubscriptions[$iSub].Name " at " (Get-Date).ToString()
        }
    }
}

Write-Host "End of Script at : " (Get-Date).ToString()