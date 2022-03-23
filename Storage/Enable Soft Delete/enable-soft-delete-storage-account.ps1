<#
    .DESCRIPTION
        This script will enable soft delete on all storage accounts. 
        The script will also genearate an output file with action performed on each storage account.
    .NOTES
        AUTHOR: 
        LAST EDIT: Mar 22, 2022
    .EXAMPLE 
    For Reporting: .\enable-soft-delete-storage-account.ps1 -tenantId 'your-tenant-id' -retentionDays 7
#>

Param(
	[Parameter(Mandatory=$true)][string]$tenantId,
	[Parameter(Mandatory=$true)][int]$retentionDays,
	[Parameter(Mandatory=$false)][bool]$enableBlob=$true,
	[Parameter(Mandatory=$false)][bool]$enableFileShare=$true,
	[Parameter(Mandatory=$false)][bool]$enableContainer=$true
)

#Connect-AzAccount -TenantId $tenantId

#Get all subscriptions to loop through
$subscriptions = Get-AzSubscription

#create output file name & path
$fileName = "Enable_SoftDelete_Report_" + "$((Get-Date).ToString("MM_dd_yyyy"))" + ".csv"
$filePath = $fileName
$soft_delete_details = @()

if(($subscriptions -ne $null) -and ($subscriptions.Count -gt 0))
{
    ForEach($sub in $subscriptions)
    {
        Write-Host "Enabling soft deletes in subscription - " $sub.Name

        #Get all storage accounts in the subscription
        $storageAccounts = Get-AzStorageAccount

        #validate if the storage accounts exist and loop through for enabling soft deletes
        if(($storageAccounts -ne $null) -and ($storageAccounts.Count -gt 0))
        {
            foreach($storageAccount in $storageAccounts)
            {
                Write-Host "Processing Storage Account - " $storageAccount.StorageAccountName
                try 
                {
                    $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName -ErrorAction Stop)[0].Value
                } 
                catch 
                {
                    Continue
                }

                #Create storage context object
                $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
                
                #Creating an object to append the Public IP details to the CSV
				$soft_delete_details_temp = New-Object PSObject
				$soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
				$soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Storage Account Name" -Value $storageAccount.StorageAccountName
                                    
                try 
                {
                    <#-- Enable Soft Delete for Blobs --#>                     
                    #Get current soft delete settings for Blobs
                    $blobRetentionPolicy = Get-AzStorageServiceProperty -Context $context -ServiceType Blob | Select-Object -ExpandProperty DeleteRetentionPolicy               
                    
                    if($enableBlob -and (($blobRetentionPolicy.Enabled -eq $False) -or ($blobRetentionPolicy.RetentionDays -eq $null) -or ($blobRetentionPolicy.RetentionDays -eq 0)))
                    {
                        try
                        {
                            #Update soft delete settings to Enabled and configure retention days as per input parameter
                            Enable-AzStorageDeleteRetentionPolicy -Context $context -RetentionDays $retentionDays | Out-null
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Blob Soft Delete" -Value "Enabled"

                        }
                        catch
                        {
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Blob Soft Delete" -Value "Error"
                            Continue
                        }
                    }
                    else
                    {
				        if($enableBlob)
                        {
                            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Blob Soft Delete" -Value "Already Enabled"                        
                        }
                        else
                        {
                            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Blob Soft Delete" -Value "Not Requested"                                                    
                        }
                    }

                    <#-- Enable Soft Delete for File Shares --#> 

                    #Get current soft delete settings for File Shares
                    $fileShareRetentionPolicy = Get-AzStorageFileServiceProperty -StorageAccountName $context.StorageAccountName -ResourceGroupName $storageAccount.ResourceGroupName | Select-Object -ExpandProperty ShareDeleteRetentionPolicy                
                    
                    if($enableFileShare -and (($fileShareRetentionPolicy.Enabled -eq $False) -or ($fileShareRetentionPolicy.Days -eq $null) -or ($fileShareRetentionPolicy.Days -eq 0)))
                    {
                        try
                        {
                            #Update soft delete settings to Enabled and configure retention days as per input parameter
                            Update-AzStorageFileServiceProperty -StorageAccountName $context.StorageAccountName -ResourceGroupName $storageAccount.ResourceGroupName -EnableShareDeleteRetentionPolicy $true -ShareRetentionDays $retentionDays | Out-null
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "File Share Soft Delete" -Value "Enabled"                            
                        }
                        catch
                        {
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "File Share Soft Delete" -Value "Error"                            
                            Continue
                        }
                    }
                    else
                    {
				        if($enableFileShare)
                        {
                            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "File Share Soft Delete" -Value "Already Enabled"                     
                        }
                        else
                        {
                            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "File Share Soft Delete" -Value "Not Requested"                                                    
                        }
                    }

                    <#-- Enable Soft Delete for Containers --#> 
                    if($enableContainer)
                    {
                        try
                        {
                            ##Update soft delete settings to Enabled and configure retention days as per input parameter for Containers
                            Enable-AzStorageContainerDeleteRetentionPolicy -StorageAccountName $context.StorageAccountName -ResourceGroupName $storageAccount.ResourceGroupName -RetentionDays $retentionDays | Out-null
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Container Soft Delete" -Value "Enabled"                            
                        }
                        catch
                        {
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Container Soft Delete" -Value "Error"                            
                            Continue
                        }
                    }
                    else
                    {
				            $soft_delete_details_temp | Add-Member -MemberType NoteProperty -Name "Container Soft Delete" -Value "Not Requested"                                                    
                    }
                } 
                catch 
                {
                    Continue
                }
                $soft_delete_details = $soft_delete_details + $soft_delete_details_temp
            }
        }
        Write-Host "Execution finished for subscription - " $sub.Name
    }
}

# Exporting the data to csv
$PSPersistPreference = $True
$soft_delete_details | Export-Csv -Path $filePath -NoTypeInformation -NoClobber
$PSPersistPreference = $False	
