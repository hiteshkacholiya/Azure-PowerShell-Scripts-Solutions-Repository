<#
    .DESCRIPTION
        This script creates & configures the following alerts for Virtual Machines at both the Log Analytic Workspace level as well as the VM level:
        a. Restart alert
        b. Deallocation alert
        c. Power Off alert
    .NOTES
        AUTHOR: 
        LAST EDIT: Dec 28, 2021
    .EXAMPLE
        .\configure-alerts-virtual-machines.ps1 -monitorRGName "rg01" -tenantId "your-azuread-tenantid" -targetSubscriptionId "your-target-subscription-id" -workspaceName "your-log-analytic-workspace-name" -emailAddressesForAlerts "your-email-array"
#>

param 
(
    [Parameter(Mandatory=$true)][string]$monitorRGName,
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$targetSubscriptionId,
    [Parameter(Mandatory=$true)][string]$workspaceName,
    [Parameter(Mandatory=$true)][string[]]$emailAddressesForAlerts
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

Connect-AzAccount -TenantId $tenantId

#Select-AzSubscription -Subscription $targetSubscriptionId
Write-Host "Started Log Analytic Workspace Configuration: " (Get-Date).ToString()

#Create Log Analytics Workspace if it does not exist
$location = "uksouth"
#$workspaceName = "LA-INFRA-DEV-UKS-LTM-04"
try
{
   $logAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -Name $workspaceName -ResourceGroupName $monitorRGName -ErrorAction Stop
}
catch
{
    $logAnalyticsWorkspace = New-AzOperationalInsightsWorkspace -Location $location -Name $workspaceName -Sku standalone -ResourceGroupName $monitorRGName
    #change SKU based on billing model. For PAYG, only standalone works.
    #$logAnalyticsWorkspace = New-AzOperationalInsightsWorkspace -Location $location -Name $WorkspaceName -Sku standard -ResourceGroupName $monitorRGName
}

# Get Log Analytic Workspace Keys
$logAnalayticKeys = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $monitorRGName -Name $logAnalyticsWorkspace.Name
if($logAnalayticKeys -ne $null)
{
    $secondaryKey = $logAnalayticKeys.SecondarySharedKey
}

#Configure Log Analytic Workspace

# List of solutions to enable
#$Solutions = "Security", "Updates", "WinLog", "VMInsights", "InternalWindowsEvent", "SQLAssessment"
$Solutions = "WinLog", "VMInsights", "InternalWindowsEvent"

# List all solutions and their installation status
#Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $monitorRGName -Name $logAnalyticsWorkspace.Name

# Enable all solutions of interest
foreach ($solution in $Solutions) {
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $monitorRGName -Name $logAnalyticsWorkspace.Name -IntelligencePackName $solution -Enabled $true
}


# Enable IIS Log Collection using agent
Enable-AzOperationalInsightsIISLogCollection -ResourceGroupName $monitorRGName -WorkspaceName $logAnalyticsWorkspace.Name

# Windows Application Events
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $monitorRGName `
                                                -WorkspaceName $logAnalyticsWorkspace.Name `
                                                -EventLogName "Application" `
                                                -CollectErrors -CollectWarnings `
                                                -Name "Application Event Log" 

# Windows System Events
New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $monitorRGName `
                                                -WorkspaceName $logAnalyticsWorkspace.Name `
                                                -EventLogName "System" `
                                                -CollectErrors `
                                                -CollectWarnings `
                                                -CollectInformation `
                                                -Name "System Event Log"
                
# Windows Perf
<#New-AzOperationalInsightsWindowsPerformanceCounterDataSource -ResourceGroupName $monitorRGName `
                                                             -WorkspaceName $logAnalyticsWorkspace.Name `
                                                             -ObjectName "Memory" `
                                                             -InstanceName "*" `
                                                             -CounterName "Available MBytes" `
                                                             -IntervalSeconds 60 `
                                                             -Name "Windows Performance Counter" -Force $true #>


Write-Host "Finished Log Analytic Workspace Configuration: " (Get-Date).ToString()                

Write-Host "Started Creation of Action Group at: " (Get-Date).tostring()

$actiongGroupEmailList =@()
#$emailAddressesForAlerts = @("hitesh.kacholiya@gmail.com","aatifsid07@gmail.com")    
foreach ($emailAddress in $emailAddressesForAlerts)
{
    $userName= $EmailAddress.Split(".")[0]
    $userActionGroup = New-AzActionGroupReceiver -Name $userName -EmailReceiver -EmailAddress $emailAddress -WarningAction SilentlyContinue
    $actiongGroupEmailList+=$userActionGroup
}


<#$receiver = New-AzActionGroupReceiver `
    -Name "AGR-INFRA-DEV-UKS-LTM-01" `
    -EmailAddress $alertEmailAddress#>

# Creates a new or updates an existing action group.
$notifyAdminsVMAlert = Set-AzActionGroup `
    -Name "notify-admins-vm-alert" `
    -ShortName "AG-DEV-01" `
    -ResourceGroupName $monitorRGName `
    -Receiver $actiongGroupEmailList #12 character limit on the shortname field for action group

#Create Action Group in memory
$notifyAdminsVMAlertActionGroup = New-AzActionGroup -ActionGroupId $notifyAdminsVMAlert.Id

Write-Host "Started Creation of Log Analytic Workspace alerts at: " (Get-Date).ToString()

#Create log search based alert for system restart events
$restartQuery = 'Event | where Message has "shutdown" and ParameterXml has "restart" |  project Computer, _ResourceId, UserName, TimeGenerated, Message, EventLog | summarize AggregatedValue= count() by bin(TimeGenerated, 5m)'
$restartQuerySource = New-AzScheduledQueryRuleSource -Query $restartQuery -DataSourceId $logAnalyticsWorkspace.ResourceId -QueryType ResultCount
$schedule = New-AzScheduledQueryRuleSchedule -FrequencyInMinutes 5 -TimeWindowInMinutes 5
#$restartMetricTrigger = New-AzScheduledQueryRuleLogMetricTrigger -ThresholdOperator GreaterThan -Threshold 0 -MetricTriggerType Total -MetricColumn "null"
$restartTriggerCondition = New-AzScheduledQueryRuleTriggerCondition -ThresholdOperator GreaterThan -Threshold 0
$restartAlertAznsActionGroup = New-AzScheduledQueryRuleAznsActionGroup -ActionGroup $notifyAdminsVMAlertActionGroup.ActionGroupId -EmailSubject "Alert - Azure Virtual Machine Restarted"
$restartAlertingAction = New-AzScheduledQueryRuleAlertingAction -AznsAction $restartAlertAznsActionGroup -Severity 3 -Trigger $restartTriggerCondition
#change the name parameter is this is being re-run for any recently deleted LA Workspace. 
New-AzScheduledQueryRule -Source $restartQuerySource -Schedule $schedule -Action $restartAlertingAction -ResourceGroupName $monitorRGName -Location $location -Name "LA-VM-Restart-Alert-04" -Description "Azure VM Restart Alert" -Enabled $true

#Create log search based alert for system shutdown
$shutDownQuery = 'Event | where Message has "initiated a shutdown" | summarize Count = count() by bin(TimeGenerated, 5m)'
$shutDownQuerySource = New-AzScheduledQueryRuleSource -Query $shutDownQuery -DataSourceId $logAnalyticsWorkspace.ResourceId -QueryType ResultCount
$shutDownTriggerCondition = New-AzScheduledQueryRuleTriggerCondition -ThresholdOperator GreaterThan -Threshold 0 -MetricTrigger $shutDownMetricTrigger
$shutDownAlertAznsActionGroup = New-AzScheduledQueryRuleAznsActionGroup -ActionGroup $notifyAdminsVMAlertActionGroup.ActionGroupId -EmailSubject "Alert - Azure Virtual Machine Restarted"
$shutDownAlertingAction = New-AzScheduledQueryRuleAlertingAction -AznsAction $shutDownAlertAznsActionGroup -Severity 3 -Trigger $shutDownTriggerCondition
#change the name parameter is this is being re-run for any recently deleted LA Workspace. 
New-AzScheduledQueryRule -Source $shutDownQuerySource -Schedule $schedule -Action $shutDownAlertingAction -ResourceGroupName $monitorRGName -Location $location -Name "LA-VM-ShutDown-Alert-04" -Description "Azure VM Shutdown Alert" -Enabled $true

# Creates a local criteria object that can be used to create a new metric alert
<#$percentageCPUCondition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "Percentage CPU" `
    -TimeAggregation Average `
    -Operator GreaterThan `
    -Threshold 0.9#>

$windowSize = New-TimeSpan -Minutes 60
$frequency = New-TimeSpan -Minutes 60

Write-Host "End Creation of Log Analytic Workspace alerts at: " (Get-Date).ToString()

Write-Host "Begin Creation of VM alerts at: " (Get-Date).ToString()

#Creating Log Activity Alerts for Deallocate & Restart VMs
$adminCondition = New-AzActivityLogAlertCondition -Field 'category' -Equal 'Administrative'
$deallocateCondition = New-AzActivityLogAlertCondition -Field 'operationName' -Equal 'Microsoft.Compute/virtualMachines/deallocate/action'
$restartCondition = New-AzActivityLogAlertCondition -Field 'operationName' -Equal 'Microsoft.Compute/virtualMachines/restart/action'
$powerOffCondition = New-AzActivityLogAlertCondition -Field 'operationName' -Equal 'Microsoft.Compute/virtualMachines/powerOff/action'
# Working on LTM UAT And STAGING Subscriptions
#$allSubscriptions = Get-AzSubscription | Where-Object { $_.Name -eq "LTM-UATSUB" -or $_.Name -eq "LTM-STAGINGSUB" }
$allSubscriptions = Get-AzSubscription

if(($allSubscriptions -ne $null) -and ($allSubscriptions.Count -gt 0))
{
    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
        $subscriptionName = $allSubscriptions[$iSub].Name
        $subscriptionId = $allSubscriptions[$iSub].Id
        $scope = "/subscriptions/" + $subscriptionId

         # Adds or updates a V2 metric-based alert rule for CPU Utilization             
        <#Add-AzMetricAlertRuleV2 `
        -Name "ALERT-CPU-UTILIZATION" `
        -ResourceGroupName $resourceGroupName `
        -WindowSize $windowSize `
        -Frequency $frequency `
        -TargetResourceId $targetResourceId `
        -Condition $percentageCPUCondition `
        -ActionGroup $notifyAdminsVMAlertActionGroup `
        -Severity 2 #>

        $vms=Get-AzVM

        if(($vms -ne $null) -and ($vms.Count -gt 0))
        {
            foreach($vm in $vms)
            {
                Write-Host "Started Alert Configuration for " $vm.Name " at : " (Get-Date).ToString()
                $targetResourceId = (Get-AzResource -Name $vm.Name).ResourceId
                $resourceGroupName = $vm.ResourceGroupName

                #Enable VM Insights by installing agent and connecting it to Log Analytics Workspace on VM if not already enabled
                (.\Install-VMInsights.ps1 -WorkspaceRegion $location -WorkspaceId $logAnalyticsWorkspace.CustomerId  -WorkspaceKey $secondaryKey -SubscriptionId $subscriptionId -ResourceGroup $monitorRGName)
               
                Write-Host "Finished Agent Installation for " $vm.Name " at: " (Get-Date).ToString()
            }
        }
        
        Write-Host "End Creation of VM alerts for " $subscriptionName ": " (Get-Date).ToString()
    }
}

Write-Host "End of Script at: " (Get-Date).ToString()