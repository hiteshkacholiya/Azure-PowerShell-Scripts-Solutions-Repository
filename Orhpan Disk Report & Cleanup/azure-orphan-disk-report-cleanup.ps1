<#
    .DESCRIPTION
        This Script will generate report and/or delete all the orphan disks found in the subscriptions
        The report will be sent as an attachment in the mail to the user
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 20, 2022
    .EXAMPLE 
    For Deleting: .\azure-orphan-disk-report-cleanup.ps1 -tenantId 'your-tenant-id' -emailAddressesForReport 'your-email-addresses-comma-separated' -deleteOrphanDisks 'Yes'
    For Reporting: .\azure-orphan-disk-report-cleanup.ps1 -tenantId 'your-tenant-id'-emailAddressesForReport 'your-email-addresses-comma-separated'
#>

Param(
	[Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$false)][string]$deleteOrphanDisks="No",
    [Parameter(Mandatory=$true)][string[]]$emailAddressesForReport
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

<#-- Function to get the total used blob size in GB  --#>
function Get-BlobSpaceUsedInGB
{
    param 
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBlob]$storageBlob
    )

    # Base + blob name
    $blobSizeInBytes = 124 + $storageBlob.Name.Length * 2

    # Get size of metadata
    $metadataEnumerator = $storageBlob.ICloudBlob.Metadata.GetEnumerator()
    
    while ($metadataEnumerator.MoveNext())
    {
        $blobSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length
    }

    if ($storageBlob.BlobType -eq [Microsoft.WindowsAzure.Storage.Blob.BlobType]::BlockBlob) 
    {
        try 
        {
            #Calcaulate size for BlockBlob 
            $blobSizeInBytes += 8
            $storageBlob.ICloudBlob.DownloadBlockList() | ForEach-Object { $blobSizeInBytes += $_.Length + $_.Name.Length }
        } 
        catch 
        {
            #Error: Unable to determine Block Blob used space
            
            Write-Host "Unable to determine the Used Space inside Block Blob: $($storageBlob)"
            return "Unknown"
        }
    } 
    else 
    { 
        try 
        {
            #Calcaulate size for Page Blob
            $storageBlob.ICloudBlob.GetPageRanges() | ForEach-Object { $blobSizeInBytes += 12 + $_.EndOffset - $_.StartOffset }
        } 
        catch 
        {
            # Error: Unable to determine Page Blob used space
            Write-Host "Unable to determine the Used Space inside Page Blob: $($storageBlob)"
            return "Unknown"
        }
    }

    # Return the BlobSize in GB
    return ([math]::Round($blobSizeInBytes / 1024 / 1024 / 1024))
}

$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_OrphanDiskReport.csv"
$filePath = $fileName

Write-Host "Started Orphan Disk Report Script at : " (Get-Date).tostring()
# ----- Generate report for Orphan Disks across subscriptions-----
try
{        
    #Getting all subscriptions
    $subscriptions = Get-AzSubscription
    $orphanDisk_details = $null 
    $orphanDisk_details = @()
    foreach ($sub in $subscriptions) 
    {
        $subName = $sub.Name
        Write-Host $subName
        Select-AzSubscription -SubscriptionName $subName
                
        Write-Host "Checking for Unattached Managed Disks of Subscription - $subName"
        $managedDisks = @(Get-AzDisk | Where-Object { $PSItem.ManagedBy -eq $Null})
                
        if($managedDisks.Count -gt 0) 
        {
            foreach ($disk in $managedDisks) 
            {
                #Creating an object to append the orphan disk details to the CSV
                $orphanDisk_details_temp = New-Object psobject 
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $subName
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $disk.ResourceGroupName
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Disk Name" -Value $disk.Name
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "DiskType" -Value "Managed"
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Disk/StorageAccount SKU" -Value $disk.Sku.Tier
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Disk/StorageAccount Location" -Value $disk.Location
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "StorageAccount Name" -Value ""
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "DiskSizeGB" -Value $disk.DiskSizeGB
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "DiskSizeUsedGB" -Value ""
                $lockDetails=Get-AzResourceLock -ResourceName $disk.Name -ResourceType "Microsoft.Compute/disks" -ResourceGroupName $disk.ResourceGroupName
                
                if($lockDetails -ne $null)
                {
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockName" -Value $lockDetails[0].Name
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockLevel/Lease Status" -Value $lockDetails[0].Properties[0]
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockId" -Value $lockDetails[0].LockId
                }
                else
                {
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockName" -Value ""
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockLevel/Lease Status" -Value ""
                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LockId" -Value ""
                }
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "TimeCreated" -Value $disk.TimeCreated
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "LastModified" -Value ""
                $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "DiskUri" -Value $disk.Id
                
                <#-- Region to perform disk clean up or reporting --#>
                if($deleteOrphanDisks.ToLower().Equals("yes"))
	            {
                    try
                    {
                        #code to do a disk cleanup/delete
                        $deletedDisk = "Yes"
			            $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedDisk
                        Write-Host "Deleted Orphan Public IP " $ip.Name " at : " (Get-Date).ToString()
                    }
                    catch
                    {
                        $deletedDisk = "No"
			            $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedDisk
                    }
	            }
                else
                {
		            $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deleteOrphanDisks
                }
                            
                $orphanDisk_details = $orphanDisk_details + $orphanDisk_details_temp            
            }
                
            Write-Host "Orphaned Managed Disks Count = $($managedDisks.Count)"
        } 
        else
        {
            Write-Host "No Orphaned Managed Disks found" 
        }

        #Checking unattached unmanaged disks across subscriptions
        Write-Host "Checking for Unattached Unmanaged Disks of Subscription - $subName"
        try
        {
            $storageAccounts = Get-AzStorageAccount | Where-Object {$_.Kind -ne "FileStorage"}

            [array]$orphanedDisks = @()
            if(($storageAccounts -ne $null) -and ($storageAccounts.Count -gt 0))
            {
                foreach($storageAccount in $storageAccounts)
                {
                    try 
                    {
                        $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName -ErrorAction Stop)[0].Value
                    } 
                    catch 
                    {
                        # Check switch to ignore these Storage Account Access Warnings
                        # If there is a lock on the storage account, this can cause an error, skip these.
                        if($error[0].Exception.ToString().Contains("Please remove the lock and try again")) 
                        {
                            Write-Host "Unable to obtain Storage Account Key for Storage Account below due to Read Only Lock:"
                            Write-Host "Storage Account: $($storageAccount.StorageAccountName) - Resource Group: $($storageAccount.ResourceGroupName) - Read Only Lock Present: True"
                        } 
                        elseif($error[0].Exception.ToString().Contains("does not have authorization to perform action")) 
                        {
                            Write-Host "Unable to obtain Storage Account Key for Storage Account below due lack of permissions:"
                            Write-Host "Storage Account: $($storageAccount.StorageAccountName) - Resource Group: $($storageAccount.ResourceGroupName)"
                        }
                        # Skip this Storage Account, move to next item in For-Each Loop
                        Continue
                    }

                    $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
                    
                    try 
                    {
                        $containers = Get-AzStorageContainer -Context $context -ErrorAction Stop
                    } 
                    catch 
                    {
                        if($error[0].Exception.ToString().Contains("This request is not authorized to perform this operation")) 
                        {
                            # Error: The remote server returned an error: (403) Forbidden.
                            Write-Host "Unable to access the Containers in the Storage Account below, Error 403 Forbidden (not authorized)."
                            Write-Host "Storage Account: $($storageAccount.StorageAccountName) - Resource Group: $($storageAccount.ResourceGroupName)"
                        } 
                        else 
                        {
                            Write-Host "Storage Account: $($storageAccount.StorageAccountName) - Resource Group: $($storageAccount.ResourceGroupName)"
                            Write-Host "$($error[0].Exception)"
                        }
                        # Skip this Storage Account, move to next item in For-Each Loop
                        Continue
                    }

                    If(($containers -ne $null) -and ($containers.Count -gt 0))
                    {
                        foreach($container in $containers) 
                        {
                            $blobs = Get-AzStorageBlob -Container $container.Name -Context $context `
                            -Blob *.vhd | Where-Object { $_.BlobType -eq 'PageBlob' }

                            if(($blobs -ne $null) -and ($blobs.Count -gt 0))
                            {
                                #Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs
                                $blobs | ForEach-Object 
                                { 
                                    #If a Page blob is not attached as disk then LeaseStatus will be unlocked
                                    if($PSItem.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked') 
                                    {
                                        $deletedBlob = "No"
                                        #Add each Disk to an array, used for deleting disk later
                                        $orphanedDisks += $PSItem
                                        #Function to get Used Space
                                        $BlobUsedDiskSpace = Get-BlobSpaceUsedInGB $PSItem
                                        $actualSize = [math]::Round($PSItem.ICloudBlob.Properties.Length / 1024 / 1024 / 1024)
                                        #Creating an object to append the orphan disk details to the CSV
                                        $orphanDisk_details_temp = New-Object psobject 
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "SubscriptionName" -Value $subName
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "ResourceGroupName" -Value $storageAccount.ResourceGroupName
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "Disk Name" -Value $PSItem.Name
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "DiskType" -Value "Unmanaged"
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "Disk/StorageAccount SKU" -Value $storageAccount.Sku.Tier
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "Disk/StorageAccount Location" -Value $storageAccount.Location
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "StorageAccount Name" -Value $storageAccount.StorageAccountName
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "DiskSizeGB" -Value $actualSize
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "DiskSizeUsedGB" -Value $BlobUsedDiskSpace
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "LockName" -Value ""
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "LockLevel/LeaseStatus" -Value $PSItem.ICloudBlob.Properties.LeaseStatus
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "LockId/LeaseState" -Value $PSItem.ICloudBlob.Properties.LeaseState
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "TimeCreated" -Value $PSItem.ICloudBlob.Properties.Created.ToString("MM/dd/yyyy HH:mm")
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "LastModified" -Value $PSItem.LastModified.ToString("MM/dd/yyyy HH:mm")
                                        $orphanDisk_details_temp | Add-Member NoteProperty -Name "DiskUri" -Value $PSItem.ICloudBlob.Uri.AbsoluteUri                            
                            
                                        <#-- Region to perform disk clean up or reporting --#>
                                        if($deleteOrphanDisks.ToLower().Equals("yes"))
	                                    {
                                            try
                                            {
                                                #code to do a disk cleanup/delete
                                                $deletedBlob = "Yes"
			                                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedBlob
                                                Write-Host "Deleted Orphan Public IP " $ip.Name " at : " (Get-Date).ToString()
                                            }
                                            catch
                                            {
                                                $deletedBlob = "No"
			                                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedBlob
                                            }
	                                    }
                                        else
                                        {
		                                    $orphanDisk_details_temp | Add-Member -MemberType NoteProperty -Name "Deleted" -Value $deletedBlob
                                        }
                            
                                        $orphanDisk_details = $orphanDisk_details + $orphanDisk_details_temp
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        catch
        {
            Write-Host $_.Exception.Message
            Write-Error 'Error in Orphan Disk Details Job' -ErrorAction SilentlyContinue
        }

        if($orphanedDisks.Count -gt 0)
        {
            Write-Host "Orphaned Unmanaged Disks Count = $($orphanedDisks.Count)"
        } 
        else
        {
            Write-Host "No Orphaned Unmanaged Disks found"
        }
    }
      
    # Exporting the data to csv
    $PSPersistPreference = $True
    $orphanDisk_details | Export-Csv -Path $filePath -NoTypeInformation -NoClobber
    $PSPersistPreference = $False	

    <#-- Start region for emailing report--#> 
    
    <#-- End Region for emailing report --#> 
}
catch
{ 
    Write-Host $_.Exception.Message
    Write-Error 'Error in Orphan Disk Details Job' -ErrorAction Stop
    throw $_.Exception
}

finally
{
    Write-Host "Ended Orphan Disk Report Script at : " (Get-Date).tostring()
}