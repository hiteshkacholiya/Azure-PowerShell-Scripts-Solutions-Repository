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

Param(
	[Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$false)][string]$deletePublicIP="No",
    [Parameter(Mandatory=$false)][string]$sendMail="No",
    [Parameter(Mandatory=$false)][string]$fromAddress="",
    [Parameter(Mandatory=$false)][string[]]$toAddressesForReport,
    [Parameter(Mandatory=$false)][string]$smtpUser="",
    [Parameter(Mandatory=$false)][string]$smtpPassword=""
)


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
Connect-AzAccount -TenantId $tenantId

$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_OrphanPublicIPReport.csv"
$filePath = $fileName

Write-Host "Started Orphan Public IP report Script at : " (Get-Date).tostring()
# ----- Generate report for Orphan Public IP and Delete those-----
try
{        
    #Getting all subscriptions
    $subscriptions = Get-AzSubscription
		
	$publicip_details = $null 
    $publicip_details = @()
		
    foreach ($sub in $subscriptions) 
    {
        $subName = $sub.Name
        Write-Host $subName
        Select-AzSubscription -SubscriptionName $subName

        <#-- Section to report all unattached NICs with public IPs --#>
        
        #Getting all the Network Interface Cards in the current subscription
        $nicList = Get-AzNetworkInterface         

        if(($nicList -ne $null) -and ($nicList.Count -gt 0))
        {
            foreach($nic in $nicList)
            { 
                if($nic.VirtualMachine -eq $null)
			    {
				    $ipConfigurations = $nic.IpConfigurations
				    foreach($ipConfig in $ipConfigurations)
				    {
                        try
                        {
					        if($ipConfig.PublicIpAddress -ne $null)
					        {
						        $pipNameArray  = $ipConfig.PublicIpAddress.Id -Split("/")
						        $pipName = $pipNameArray[$pipNameArray.Length-1]
						        $pip =Get-AzPublicIpAddress -Name $pipName.Trim()
								
						        foreach($ip in $pip)
						        {
							        $deletedIP = "No"
							        Write-Host $ip.Name $ip.ResourceGroupName
									
							        #Creating an object to append the Public IP details to the CSV
							        $publicip_details_temp = New-Object PSObject
							        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $subName
							        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $ip.ResourceGroupName 
							        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "PublicIPName" -Value $ip.Name 
									
							        if($deletePublicIP.ToLower().Equals("yes"))
							        {
                                        try
                                        {
						                    $ipConfig.PublicIpAddress.Id = $null
                                            Set-AzNetworkInterface -NetworkInterface $nic
                                            Remove-AzPublicIpAddress -ResourceGroupName $ip.ResourceGroupName -Name $ip.Name -Force
                                            $deletedIP = "Yes"
									        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                                            Write-Host "Deleted Orphan Public IP " $ip.Name " at : " (Get-Date).ToString()
                                        }
                                        catch
                                        {
                                            $deletedIP = "No"
									        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                                        }
							        }
                                    else
                                    {
								        $publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                                    }	
							        #Append the Public IP details to the CSV
							        $publicip_details = $publicip_details + $publicip_details_temp
						        }
					        }
                        }
                        catch
                        {
                            Write-Host "Exception encountered in " $nic.Name " in resource group " $nic.ResourceGroupName 
                        }
				    }
			    }

            } 
        }
        <#-- Section to report all unused Public IP Addresses --#>
        #Getting all the public IP Addresses in current subscription
        $allPublicIPs = Get-AzPublicIpAddress | Where-Object { $_.IpConfigurationText -eq 'null'}
        
        if(($allPublicIPs -ne $null) -and ($allPublicIPs.Count -gt 0))
        {
            foreach($publicIP in $allPublicIPs)
            {
                $deletedIP = "No"
				Write-Host $publicIP.Name $publicIP.ResourceGroupName
									
				#Creating an object to append the Public IP details to the CSV
				$publicip_details_temp = New-Object PSObject
				$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $subName
				$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $publicIP.ResourceGroupName 
				$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "PublicIPName" -Value $publicIP.Name 
									
				if($deletePublicIP.ToLower().Equals("yes"))
				{
                    try
                    {
                        Remove-AzPublicIpAddress -ResourceGroupName $publicIP.ResourceGroupName -Name $publicIP.Name -Force
                        $deletedIP = "Yes"
						$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                        Write-Host "Deleted Orphan Public IP " $publicIP.Name " at : " (Get-Date).ToString()
                    }
                    catch
                    {
                        $deletedIP = "No"
						$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                    }
				}
                else
                {
					$publicip_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedIP
                }	
				#Append the Public IP details to the CSV
				$publicip_details = $publicip_details + $publicip_details_temp
            }
        }
    } 
    # Exporting the data to csv 
    $publicip_details | Export-Csv -Path $filePath -NoTypeInformation -NoClobber
}
catch
{ 
    Write-Output $_.Exception.Message
    Write-Error 'Error in Delete Orphan Public IP Script' -ErrorAction Stop
    throw $_.Exception
}
    
<#-- End Region for Orphan Public IP Report--#> 

<# -- Send email with report as attachment --#>
if($sendMail.ToLower().Equals('yes'))
{
    try
    {
        $generationTime = (Get-Date).ToString("MMMdyyyy")
        $mailBody = "Hello, <br/><br/> Please find attached the Azure Orphan PublicIP Address Report generated for Azure Tenant Id <b> $tenantId </b> at $generationTime. <br/><br/> <p style=""color:red""> This is a system generated email. Please do not reply to this email.</p><br/>Regards,<br/>OFLM Azure Team"
        $mailAttachment = New-Object System.Net.Mail.Attachment($filePath)
        $mailMessage = new-object Net.Mail.MailMessage
        $mailMessage.From = $fromAddress
        #$toAddressesForReport -join ","
        $mailMessage.Subject = "Azure Orphan PublicIP Report - " + $tenantId + " - " + $generationTime
        $mailMessage.Body = $mailBody
        $mailMessage.IsBodyHtml = $true
        $mailMessage.Attachments.Add($mailAttachment)

        foreach($toMailAddress in $toAddressesForReport)
        {
            $mailMessage.To.Add($toMailAddress)
        }

        $smtpServer = "smtp.office365.com"
        $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, 587)
        $smtpClient.EnableSsl = $true
        $smtpClient.UseDefaultCredentials = $false
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword)
        $smtpClient.Send($mailMessage)
    }
    catch
    {
        Write-Host "Exception encountered while trying to send mail"
    }
}

Write-Host "Ended Orphan Public IP Deletion Script at : " (Get-Date).ToString()