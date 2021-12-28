<#
    .DESCRIPTION
        This script generates the cost report for all resources in Azure Tenant
    .NOTES
        AUTHOR: 
        LAST EDIT: Dec 28, 2021
    .EXAMPLE 
        .\azure-teanant-cost-report.ps1 -tenantId "your-tenant-id" -startDate "11/10/2021" -endDate "12/9/2021" -emailAddressesForReport "abc@def.com","uvw@xyz.com"
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][DateTime] $startDate,
    [Parameter(Mandatory=$true)][DateTime] $endDate,
    [Parameter(Mandatory=$true)][string[]]$emailAddressesForReport
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

# Working on LTM UAT And STAGING Subscriptions
#$allSubscriptions = Get-AzSubscription | Where-Object { $_.Name -eq "LTM-UATSUB" -or $_.Name -eq "LTM-STAGINGSUB" }
$allSubscriptions = Get-AzSubscription

if(($allSubscriptions -ne $null) -and ($allSubscriptions.Count -gt 0))
{
    $currentDirectory = Get-Location
    $filePath = $currentDirectory.Path + "\Azure_Costs_" + (Get-Date).Date.ToString("dd-MMM-yy") + ".csv"
    $title = '"Subscription Name", "Resource Group Name", "Resource Name", "Cost (in GBP)"'
    if(!(Test-Path $filePath))
    {
        Add-Content $filePath $title
    }

    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        $currentSubscription = Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
        $currentSubscriptionName = $currentSubscription.Name
        Write-Host "Begin Cost Calculations for " $currentSubscriptionName " at " (Get-Date).ToString()

        $allResourceGroups = Get-AzResourceGroup
        if(($allResourceGroups -ne $null) -and ($allResourceGroups.Count -gt 0))
        {
            for($iRes=0; $iRes -lt $allResourceGroups.Count; $iRes++)
            {
                $currentResourceGroup = $allResourceGroups[$iRes]
                if($currentResourceGroup -ne $null)
                {
                    Write-Host "Calculation started for " $currentResourceGroup.ResourceGroupName " at " (Get-Date).ToString()
                    $allResources = Get-AzResource -ResourceGroupName $currentResourceGroup.ResourceGroupName
                    if(($allResources -ne $null) -and ($allResources.Count -gt 0))
                    {
                        foreach($resource in $allResources)
                        {
                            try
                            {
                                if(($resource.ResourceType -ne "Microsoft.Compute/virtualMachines/extensions"))
                                 <#-and ($resource.ResourceType -ne "microsoft.insights/activityLogAlerts") `
                                 -and ($resource.ResourceType -ne "Microsoft.DevTestLab/schedules") `
                                 -and ($resource.ResourceType -ne "microsoft.insights/scheduledqueryrules") `
                                 -and ($resource.ResourceType -ne "Microsoft.OperationsManagement/solutions") `
                                 -and ($resource.ResourceType -ne "Microsoft.Network/networkWatchers") `
                                 -and ($resource.ResourceType -ne "microsoft.operationalInsights/querypacks"))#>
                                {
                                    $resourceCost = [math]::Round((Get-AzConsumptionUsageDetail -Expand MeterDetails -ResourceGroup $currentResourceGroup.ResourceGroupName `
                                                -StartDate $startDate -EndDate $endDate -InstanceName $resource.Name `
                                                | Measure-Object -Sum PretaxCost | Select-Object -ExpandProperty Sum),2)
                                    # Format: Subscription Name, Resource Group Name, Resource Name, Cost
                                    $addToReport = '"' + $currentSubscriptionName + '","' + $currentResourceGroup.ResourceGroupName + '","' + $resource.Name + '","' + $resourceCost + '"'
                                    Add-Content $filePath $addToReport
                                }
                            }
                            catch
                            {
                                $addToReport = '"' + $currentSubscriptionName + '","' + $currentResourceGroup.ResourceGroupName + '","' + $resource.Name + '","' + "Cost Not Calculated" + '"'
                                Add-Content $filePath $addToReport
                                Write-Host "Exception in calculation of " $resource.Name " for " $currentResourceGroup.ResourceGroupName " at " (Get-Date).ToString()
                            }
                        }
                    }
                    Write-Host "Calculation completed for " $currentResourceGroup.ResourceGroupName " at " (Get-Date).ToString()
                }
            }
        }
    }
}

Write-Host "End of Script at : " (Get-Date).ToString()