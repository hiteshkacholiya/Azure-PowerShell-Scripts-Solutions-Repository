<#
    .DESCRIPTION
        This Script will generate report and/or delete all the Orphan Public IP's in each subscription
        The report will be sent as an attachment in the mail to the user
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 20, 2022
    .EXAMPLE 
    For Deleting & Sending Mail: .\azure-orphan-publicip-report-cleanup.ps1 -tenantId 'your-tenant-id'  -deletePublicIP 'Yes' -sendMail 'Yes' -fromAddress 'your-from-email-address' -toAddressesForReport 'your-email-addresses-comma-separated' -smtpUser 'your-smtp-user' -smtpPassword 'your-smtp-password'
    For Reporting: .\azure-orphan-publicip-report-cleanup.ps1 -tenantId 'your-tenant-id'-toAddressesForReport 'your-email-addresses-comma-separated'
    For Reporting & Sending Mail: .\azure-orphan-publicip-report-cleanup.ps1 -tenantId 'your-tenant-id'-toAddressesForReport 'your-email-addresses-comma-separated' -sendMail 'Yes' -fromAddress 'your-from-email-address' -toAddressesForReport 'your-email-addresses-comma-separated' -smtpUser 'your-smtp-user' -smtpPassword 'your-smtp-password'
#>

## Use this for Automation account only
<#-- Initialize Connection & Import Modules --#>
<#
Import-Module -Name "Az.Resources"
$connectionName = "CloudOps-AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Output $servicePrincipalConnection
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
#Connect-AzAccount

#Import-Module -Name "Az"
$fileName = "$((Get-Date).ToString("yyyy-MM-dd"))_LAW_Report.csv"
$filePath = $fileName

$subscriptions = Get-AzSubscription
$workspace_array = @()
$extension_details = @()

foreach ($sub in $subscriptions) {
  Select-AzSubscription -SubscriptionName $sub
  $workspace_array += Get-AzOperationalInsightsWorkspace
}

foreach ($sub in $subscriptions) {
  Select-AzSubscription -SubscriptionName $sub 
  $VMs = Get-AzVM

  foreach ($vm in $VMs) {
    $lin_extension_name = "OMSAgentForLinux"
    $win_extension_name = "MicrosoftMonitoringAgent"
    $get_extension = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name | Where-Object { $_.Name -eq $win_extension_name -or $_.Name -eq $lin_extension_name } -ErrorAction Continue
    $extension_temp = New-Object psobject 
    $extension_temp | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $sub.Name
    $extension_temp | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
    $extension_temp | Add-Member -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
    if ($get_extension -ne $null) {
      $workspace_id = ( $get_extension.PublicSettings | ConvertFrom-Json).workspaceId
   
      foreach ($w in $workspace_array) {
        if ($w.CustomerId.Guid -eq $workspace_id) { 
          $workspaceName = $w.Name
          $workspaceRG = $w.ResourceGroupName
          $workspaceResourceId = $w.ResourceId
          break
        }
        else {
          $workspaceName = "Doesn't exist"
          $workspaceRG = ""
          $workspaceResourceId = ""
        }
      }
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceId" -Value $workspace_id
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceName" -Value $workspaceName
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceResourceGroup" -Value $workspaceRG
      $extension_temp | Add-Member -MemberType NoteProperty -Name "workspaceResourceId" -Value $workspaceResourceId
   
    }
    else {
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceId" -Value "Not Found"
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceName" -Value ""
      $extension_temp | Add-Member -MemberType NoteProperty -Name "WorkspaceResourceGroup" -Value ""
      $extension_temp | Add-Member -MemberType NoteProperty -Name "workspaceResourceId" -Value ""
    }

    $extension_details += $extension_temp
  }
}
$extension_details | Export-Csv -Path $filePath -NoTypeInformation -NoClobber