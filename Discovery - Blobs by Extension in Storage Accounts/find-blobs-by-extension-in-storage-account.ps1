<#
    .DESCRIPTION
        This Script will generate a CSV file containing a list of VHDs/unmanaged disks found in all storage accounts
    .NOTES
        AUTHOR: 
        LAST EDIT: Jan 20, 2022
    .EXAMPLE 
    For Reporting: .\find-blobs-by-extension-in-storage-account.ps1 -tenantId 'your-tenant-id' -extension "txt"
#>

Param(
	[Parameter(Mandatory=$true)][string]$tenantId,
	[Parameter(Mandatory=$true)][string]$extension
)

Connect-AzAccount -TenantId $tenantId

$subscriptions = Get-AzSubscription
$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_" + $extension + "_Report.csv"
$filePath = $fileName
$vhd_details = $null 
$vhd_details = @()
$extension = "*." + $extension

if(($subscriptions -ne $null) -and ($subscriptions.Count -gt 0))
{
    ForEach($sub in $subscriptions)
    {
        $storageAccounts = Get-AzStorageAccount | Where-Object {$_.Kind -ne "FileStorage"}
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
                    Continue
                }

                $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
                    
                try 
                {
                    $containers = Get-AzStorageContainer -Context $context -ErrorAction Stop
                } 
                catch 
                {
                    Continue
                }

                If(($containers -ne $null) -and ($containers.Count -gt 0))
                {
                    foreach($container in $containers) 
                    {
                        $blobs = Get-AzStorageBlob -Container $container.Name -Context $context `
                        -Blob $extension| Where-Object { $_.BlobType -eq 'PageBlob' }

                        if(($blobs -ne $null) -and ($blobs.Count -gt 0))
                        {
                            ForEach($blob in $blobs)
                            {
                                $vhd_details_temp = New-Object psobject 
                                $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "VHD Name" -Value $blob.Name
                                $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Container Name" -Value $container.Name
                                $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Storage Account Name" -Value $storageAccount.StorageAccountName
                                $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Resource Group Name" -Value $storageAccount.ResourceGroupName
                                $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
                                $vhd_details = $vhd_details + $vhd_details_temp

                                Write-Host VHD Found in : $container.Name in storage account $storageAccount.Name
                            }
                        }
                        else
                        {
                            $blobs = Get-AzStorageBlob -Container $container.Name -Context $context `
                            -Blob $extension| Where-Object { $_.BlobType -eq 'BlockBlob' }
                            if(($blobs -ne $null) -and ($blobs.Count -gt 0))
                            {
                                ForEach($blob in $blobs)
                                {
                                    $vhd_details_temp = New-Object psobject 
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "VHD Name" -Value $blob.Name
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Container Name" -Value $container.Name
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Storage Account Name" -Value $storageAccount.StorageAccountName
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Resource Group Name" -Value $storageAccount.ResourceGroupName
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
                                    $vhd_details = $vhd_details + $vhd_details_temp

                                    Write-Host VHD Found in : $container.Name in storage account $storageAccount.Name
                                }
                            }
                        }
                        else
                        {
                            $blobs = Get-AzStorageBlob -Container $container.Name -Context $context `
                            -Blob $extension| Where-Object { $_.BlobType -eq 'AppendBlob' }
                            if(($blobs -ne $null) -and ($blobs.Count -gt 0))
                            {
                                ForEach($blob in $blobs)
                                {
                                    $vhd_details_temp = New-Object psobject 
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "VHD Name" -Value $blob.Name
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Container Name" -Value $container.Name
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Storage Account Name" -Value $storageAccount.StorageAccountName
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Resource Group Name" -Value $storageAccount.ResourceGroupName
                                    $vhd_details_temp | Add-Member -MemberType NoteProperty -Name "Subscription Name" -Value $sub.Name
                                    $vhd_details = $vhd_details + $vhd_details_temp

                                    Write-Host VHD Found in : $container.Name in storage account $storageAccount.Name
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

# Exporting the data to csv
$PSPersistPreference = $True
$vhd_details | Export-Csv -Path $filePath -NoTypeInformation -NoClobber
$PSPersistPreference = $False	
