<#
    .DESCRIPTION
        This script creates & configures the following alerts for input virtual machine list provided:
        a. Restart alert
        b. Deallocation alert
        c. Power Off alert
        d. CPU Utilization alert
        e. Disk Space alert
    .NOTES
        AUTHOR: 
        LAST EDIT: Dec 06, 2021
#>

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted

## Use this for Automation account only
<#-- Initialize Connection & Import Modules --#>
Import-Module -Name Az.Resources
Import-Module -Name Az.Accounts
Import-Module -Name Az.Monitor

$connectionName = "AzureRunAsConnectionName"
$WarningPreference = 'SilentlyContinue'
Write-Output "Started Script at : " (Get-Date).tostring()

param 
(
    [Parameter(Mandatory=$true)][string]$monitorRGName,
    [Parameter(Mandatory=$true)][string]$alertEmailAddress
 )

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
<#-- End Region for Initialize Connection & Import Modules --#>

##Use this for local execution

#Connect-AzAccount -TenantId "Your-AzureAD-TenantID"
#Add-AzAccount
Write-Output "Started Creation of Action Group at : " (Get-Date).tostring()

Select-AzSubscription -Subscription "Your-Target-SubscriptionId"

$receiver = New-AzActionGroupReceiver `
    -Name "AGR-INFRA-DEV-UKS-LTM-01" `
    -EmailAddress "Target-Email-Address"

# Creates a new or updates an existing action group.
$notifyAdminsVMAlert = Set-AzActionGroup `
    -Name "notify-admins-vm-alert" `
    -ShortName "AG-DEV-01" `
    -ResourceGroupName $monitorRGName `
    -Receiver $receiver #12 character limit on the shortname field for action group

#Create Action Group in memory
$notifyAdminsVMAlertActionGroup = New-AzActionGroup -ActionGroupId $notifyAdminsVMAlert.Id


Write-Output "Started Creation of rules at : " (Get-Date).ToString()

#Creating Log Activity Alerts for Deallocate & Restart VMs
$adminCondition = New-AzActivityLogAlertCondition -Field 'category' -Equal 'Administrative'
$deallocateCondition = New-AzActivityLogAlertCondition -Field 'operationName' -Equal 'Microsoft.Compute/virtualMachines/deallocate/action'
$restartCondition = New-AzActivityLogAlertCondition -Field 'operationName' -Equal 'Microsoft.Compute/virtualMachines/restart/action'

# Creates a local criteria object that can be used to create a new metric alert
$percentageCPUCondition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "Percentage CPU" `
    -TimeAggregation Average `
    -Operator GreaterThan `
    -Threshold 0.9

$windowSize = New-TimeSpan -Minutes 60
$frequency = New-TimeSpan -Minutes 60

Write-Output "End Creation of rules at : " (Get-Date).ToString()

$allSubscriptions = Get-AzSubscription

if(($allSubscriptions -ne $null) -and ($allSubscriptions.Count -gt 0))
{
    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
        $subscriptionName = $allSubscriptions[$iSub].Name
        $subscriptionId = $allSubscriptions[$iSub].Id

        $vms=Get-AzVM
        if(($vms -ne $null) -and ($vms.Count -gt 0))
        {
            Write-Output "Started Alert Configuration for " + $vm.Name " + at : " (Get-Date).tostring()
            foreach($vm in $vms)
            {
                $targetResourceId = (Get-AzResource -Name $vm.Name).ResourceId
                $resourceGroupName = $vm.ResourceGroupName
                $scope = "/subscriptions/" + $subscriptionId
                
                # Adds or updates a V2 metric-based alert rule for CPU Utilization
                
                Add-AzMetricAlertRuleV2 `
                -Name "VM-UTILIZATION" `
                -ResourceGroupName $resourceGroupName `
                -WindowSize $windowSize `
                -Frequency $frequency `
                -TargetResourceId $targetResourceId `
                -Condition $percentageCPUCondition `
                -ActionGroup $notifyAdminsVMAlertActionGroup `
                -Severity 2

                #Create VM Deallocated Alert based on Activity Log Signal
                Set-AzActivityLogAlert -Location "Global" -Name "VM-DEALLOCATED" `
                -ResourceGroupName $resourceGroupName -Scope $scope `
                -Action $notifyAdminsVMAlertActionGroup `
                -Condition $adminCondition, $deallocateCondition -Description "Alert to notify when a virtual machine is deallocated"

                #Create VM Restart Alert based on Activity Log Signal
                Set-AzActivityLogAlert -Location "Global" -Name "VM-RESTARTED" `
                -ResourceGroupName $resourceGroupName -Scope $scope `
                -Action $notifyAdminsVMAlertActionGroup `
                -Condition $adminCondition, $restartCondition -Description "Alert to notify when a virtual machine is restarted"
            }
        }
    }
}
