<#
    .DESCRIPTION
        This script generates the cost report for all resources in Azure Tenant
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 12, 2022
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
    #Prepare report file
    $currentDirectory = Get-Location
    $filePath = $currentDirectory.Path + "\Azure_Costs_" + (Get-Date).Date.ToString("dd-MMM-yy") + ".csv"
    $title = '"Subscription Name", "Resource Group Name", "Resource Name", "Cost (in GBP)"'
    if(!(Test-Path $filePath))
    {
        Add-Content $filePath $title
    }

    #Cost Report for all subscriptions
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
                                    #calculate resource cost for the duration provided
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
                                #add blank entry for any exceptions
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

<# -- Send email with report as attachment --#>
$generationTime = (Get-Date).ToString("MMMdyyyy")
$mailSubject = "Azure Cost Report - " + $tenantId + " - " + $generationTime
$mailBody = "Hello, <br/><br/> Please find attached the Azure Cost Report generated for Azure Tenant Id <b> $tenantId </b> at $generationTime. <br/><br/> <p style=""color:red""> This is a system generated email. Please do not reply to this email.</p><br/>Regards,<br/>OFLM Azure Team"
$mailAttachment = New-Object System.Net.Mail.Attachment($filePath)
$mailMessage = new-object Net.Mail.MailMessage
$mailMessage.From = "Senthicloud@gmail.com"
#$emailAddressesForReport -join ","
$mailMessage.Subject = "Azure Cost Report - " + $tenantId + " - " + $generationTime
$mailMessage.Body = $mailBody
$mailMessage.IsBodyHtml = $true
$mailMessage.Attachments.Add($mailAttachment)

foreach($toMailAddress in $emailAddressesForReport)
{
    $mailMessage.To.Add($toMailAddress)
}

$smtpServer = "smtp.office365.com"
$smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, 587)
$smtpClient.EnableSsl = $true
$smtpClient.UseDefaultCredentials = $false
$smtpClient.Credentials = New-Object System.Net.NetworkCredential("Hitesh@arltechnology.onmicrosoft.com", "Freelance@2021")
$smtpClient.Send($mailMessage)

<#
$credential = Get-Credential

## Define the Send-MailMessage parameters
$mailParams = @{
    SmtpServer                 = 'smtp.office365.com'
    Port                       = '587' # or '25' if not using TLS
    UseSSL                     = $true ## or not if using non-TLS
    Credential                 = $credential
    From                       = 'sender@yourdomain.com'
    To                         = 'recipient@yourdomain.com', 'recipient@NotYourDomain.com'
    Subject                    = "SMTP Client Submission - $(Get-Date -Format g)"
    Body                       = 'This is a test email using SMTP Client Submission'
    DeliveryNotificationOption = 'OnFailure', 'OnSuccess'
}

## Send the message
Send-MailMessage @mailParams
#>

Write-Host "End of Script at : " (Get-Date).ToString()