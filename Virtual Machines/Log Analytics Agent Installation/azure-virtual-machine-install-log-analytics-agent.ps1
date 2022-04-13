<#
    .DESCRIPTION
        This script installs the log analytics agents on all virtual machines based on Operating System and connects them to specified workspace
        for all subscriptions under the specified management group. If agent is already installed, it will check if it is connected to right workspace. 
        If not, it will remove that extension and re-install.This will only work on VMs that are not in stopped/deallocated state.
        For Windows OS, MMA agent will be installed. For Linux OS, OMSAgentForLinux will be installed.  
    .NOTES
        AUTHOR: 
        LAST EDIT: Apr 15, 2021
    .EXAMPLE
        .\azure-virtual-machine-install-log-analytics-agent.ps1 -tenantId "your-azuread-tenantid" -managementGroupId "your-management-group-id" -workspaceId "your-log-analytic-workspace-id" -workspaceKey "your-log-analytic-workspace-key"
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$managementGroupId,
    [Parameter(Mandatory=$true)][string]$workspaceId,
    [Parameter(Mandatory=$true)][string]$workspaceKey
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

$settings = @{"workspaceId" = $workspaceId}
$protectedSettings = @{"workspaceKey" = $workspaceKey}

#Use this for local execution
#Connect-AzAccount -TenantId $tenantId

$response = Get-AzManagementGroup -GroupId $managementGroupId  -Expand -Recurse
$subscriptions = $response.Children

foreach ($sub in $subscriptions) 
{
    Select-AzSubscription -SubscriptionName $sub.DisplayName
    $allVMs = Get-AzVM

    if(($allVMs -ne $null) -and ($allVMs.Count -gt 0))
    {
      foreach ($vm in $VMs) 
      {
        if($vm.ProvisioningState.ToLower() -eq "succeeded")
        {
            $lin_extension_name = "OMSAgentForLinux"
            $win_extension_name = "MicrosoftMonitoringAgent"
            $get_extension = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name | Where-Object { $_.Name -eq $win_extension_name -or $_.Name -eq $lin_extension_name } -ErrorAction Continue
   
            if ($get_extension -eq $null) 
            {
                #Enable VM Insights by installing agent and connecting it to Log Analytics Workspace on VM if not already enabled
                (.\Install-VMInsights.ps1 -WorkspaceRegion $vm.Location -WorkspaceId $workspaceId  -WorkspaceKey $workspaceKey -SubscriptionId $sub.Name -ResourceGroup $vm.ResourceGroupName)
            }
            else
            {
              $workspace_id = ($get_extension.PublicSettings | ConvertFrom-Json).workspaceId

              if ($workspace_id -ne $workspaceId ) 
              {
                if ($vm.StorageProfile.OsDisk.OsType.ToString().ToLower() -eq "windows") 
                {
                    Remove-AzVMExtension `
                    -ResourceGroupName $vm.ResourceGroupName `
                    -VMName $vm.Name `
                    -Name $win_extension_name `
                    -Confirm:$false `
                    -Force:$true
        
                    Set-AzVMExtension `
                    -ResourceGroupName $vm.ResourceGroupName `
                    -VMName $vm.Name `
                    -ExtensionType "Microsoft.EnterpriseCloud.Monitoring.MicrosoftMonitoringAgent" `
                    -ExtensionName "MicrosoftMonitoringAgent" `
                    -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
                    -TypeHandlerVersion 1.0 `
                    -Settings $settings `
                    -ProtectedSettings $protectedSettings `
                    -Location $vm.Location
                }
                else 
                {
                    Remove-AzVMExtension `
                    -ResourceGroupName $vm.ResourceGroupName `
                    -VMName $vm.Name `
                    -Name $lin_extension_name `
                    -Confirm:$false `
                    -Force:$true

                    Set-AzVMExtension `
                    -ResourceGroupName $vm.ResourceGroupName`
                    -VMName $vm.Name `
                    -ExtensionType "Microsoft.EnterpriseCloud.Monitoring.OmsAgentForLinux" `
                    -ExtensionName "OMSAgentForLinux" `
                    -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
                    -TypeHandlerVersion 1.0 `
                    -Settings $settings `
                    -ProtectedSettings $protectedSettings `
                    -Location $vm.Location
                }
              }
            }
        }
      }
    }
}
