<#
    .DESCRIPTION
        This script generates the cost report for all resources in Azure Tenant
    .NOTES
        AUTHOR: 
        LAST EDIT: Feb 07, 2022
    .EXAMPLE 
        .\azure-teanant-network-report.ps1 -tenantId "your-tenant-id" -emailAddressesForReport "abc@def.com","uvw@xyz.com"
#>

param 
(
    [Parameter(Mandatory=$true)][string]$tenantId,
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
    $filePathPeering = $currentDirectory.Path + "\Azure_Network_Peerings_" + (Get-Date).Date.ToString("dd-MMM-yy") + ".csv"
    $filePath = $currentDirectory.Path + "\Azure_Network_Details_" + (Get-Date).Date.ToString("dd-MMM-yy") + ".csv" 
    $titlePeering = '"Source VNet, Resource Group Name, Peering Name, Destination VNet, Peering Sync Level, Peering Sync State, Allow Forwarded Traffic, Allow Gateway Transit, Allow Virtual Network Access, Use Remote Gateways, Peered Remote Address Space"'
    $title = '"VNet Name, Resource Group Name, VNET Address Prefix, Subnet Name, Subnet Address Prefix, Subnet NSG, Subnet Route Table, Subnet Private Endpoints, Subnet Service Endpoints"'
    
    if(!(Test-Path $filePath))
    {
        Add-Content $filePath $title
    }

    if(!(Test-Path $filePathPeering))
    {
        Add-Content $filePathPeering $titlePeering
    }

    #Cost Report for all subscriptions
    for($iSub=0;$iSub -lt $allSubscriptions.Count;$iSub++)
    {
        $currentSubscription = Select-AzSubscription -SubscriptionId $allSubscriptions[$iSub].Id
        $currentSubscriptionName = $currentSubscription.Name
        Write-Host "Begin for " $currentSubscriptionName " at " (Get-Date).ToString()
        $allVNets = Get-AzVirtualNetwork
        if(($allVNets -ne $null) -and ($allVNets.Count -gt 0))
        {
            foreach($vnet in $allVNets)
            {
                if(($vnet.VirtualNetworkPeerings -ne $null) -and ($vnet.VirtualNetworkPeerings.Count -gt 0))
                {
                    foreach($peering in $vnet.VirtualNetworkPeerings)
                    {
                        $addPeeringToReport = '"' + $vnet.Name + '","' + $vnet.ResourceGroupName + '","' + $peering.Name + '","' + $peering.RemoteVirtualNetwork.Id.Substring($peering.RemoteVirtualNetwork.Id.LastIndexOf('/')+1) + '","' + $peering.PeeringSyncLevel + '","' + $peering.PeeringState + '","' + $peering.AllowForwardedTraffic + '","' + $peering.AllowGatewayTransit + '","' + $peering.AllowVirtualNetworkAccess + '","' + $peering.UseRemoteGateways + '","' + $peering.PeeredRemoteAddressSpace.AddressPrefixes + '"'
                        Add-Content $filePathPeering $addPeeringToReport
                    }
                }

                if(($vnet.Subnets -ne $null) -and ($vnet.Subnets.Count -gt 0))
                {
                    foreach($subnet in $vnet.Subnets)
                    {
                        try
                        {
                            $addToReport = '"' + $vnet.Name + '","' + $vnet.ResourceGroupName + '","' + $vnet.AddressSpace.AddressPrefixes + '","' + $subnet.Name + '","' + $subnet.AddressPrefix + '","' + $subnet.NetworkSecurityGroup.Id.Substring($subnet.NetworkSecurityGroup.Id.lastIndexOf('/') + 1) + '","' + $subnet.RouteTable.Id.Substring($subnet.RouteTable.Id.LastIndexOf('/') + 1) + '","' +  $subnet.PrivateEndpoints.Id.Substring($subnet.PrivateEndpoints.Id.LastIndexOf('/') + 1) + '","' + $subnet.ServiceEndpoints.Service + '"'  
                        }
                        catch
                        {
                            try
                            {
                                $addToReport = '"' + $vnet.Name + '","' + $vnet.ResourceGroupName + '","' + $vnet.AddressSpace.AddressPrefixes + '","' + $subnet.Name + '","' + $subnet.AddressPrefix + '","' + $subnet.NetworkSecurityGroup.Name + '","' + $subnet.RouteTable.Id.Substring($subnet.RouteTable.Id.LastIndexOf('/') + 1) + '","' + $subnet.PrivateEndpoints.Id.Substring($subnet.PrivateEndpoints.Id.LastIndexOf('/') + 1) + '","' + $subnet.ServiceEndpoints.Service + '"'
                            }
                            catch
                            {
                                try
                                {
                                    $addToReport = '"' + $vnet.Name + '","' + $vnet.ResourceGroupName + '","' + $vnet.AddressSpace.AddressPrefixes + '","' + $subnet.Name + '","' + $subnet.AddressPrefix + '","' + $subnet.NetworkSecurityGroup.Name + '","' + $subnet.RouteTable.Id.Substring($subnet.RouteTable.Id.LastIndexOf('/') + 1) + '","' +  $subnet.PrivateEndpoints + '","' + $subnet.ServiceEndpoints.Service + '"'
                                }
                                catch
                                {
                                    $addToReport = '"' + $vnet.Name + '","' + $vnet.ResourceGroupName + '","' + $vnet.AddressSpace.AddressPrefixes + '","' + $subnet.Name + '","' + $subnet.AddressPrefix + '","' + $subnet.NetworkSecurityGroup.Name + '","' + $subnet.RouteTable.Id + '","' +  $subnet.PrivateEndpoints + '","' + $subnet.ServiceEndpoints.Service + '"'                                    
                                }
                            }
                        }
                        Add-Content $filePath $addToReport
                    }
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
$mailMessage.From = "abc@gmail.com"
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
$smtpClient.Credentials = New-Object System.Net.NetworkCredential("abc.onmicrosoft.com", "abcdefg")
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