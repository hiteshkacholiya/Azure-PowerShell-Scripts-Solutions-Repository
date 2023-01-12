$ErrorActionPreference = "Continue"
$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_AzureVM_HubLicenseChange_Output.csv"
$AzureVMHubOutput = @()

#read input from CSV file
$csv = Import-Csv "C:\Work\GIT Code\Azure-PowerShell-Scripts-Solutions-Repository\Virtual Machines\Change License to use AHB\ahb-subscription-input - sample.csv"

foreach($inputSub in $csv)
{
    if($inputSub.Type -eq "Non-Prod")
    {
        Write-Host $inputSub.Name
        # Get all subscriptions
        $azSub = Get-AzSubscription -SubscriptionName $inputSub.Name

        #validate if subscriptions are returned
        if(($azSub -ne $null) -and ($azSub.Count -gt 0))
        {
            try
            {
                # Set the context to current subscription
                Select-AzSubscription -Subscription $azSub | Out-Null
                $azSubName = $azSub.Name
                Write-Host "Begin processing for subscription - " $azSubName
            
                #Get all azure virtual machines in the subscription
                $AzureVMs = Get-AzVM -ErrorAction SilentlyContinue
        
                if(($AzureVMs -ne $null) -and ($AzureVMs.Count -gt 0))
                {
                    # process all vms
                    foreach ($azVM in $AzureVMs) 
                    {
                        try
                        {
                            #checking if the license type is blank informs us if the virtual machines is using payg or has been deployed from gallery
                            if($azVM.LicenseType -eq $null)
                            {
                                # change value to this to update as AHB
                                if($azVM.StorageProfile.OsDisk.OsType -eq "Windows")
                                {
                                    $azVM.LicenseType = "Windows_Server"
                                }
                                elseif($azVM.StorageProfile.OsDisk.OsType -eq "Linux")
                                {
                                    if($azVM.StorageProfile.ImageReference.Publisher -eq "canonical")
                                    {
                                        #Update license to RHEL
                                        $azVM.LicenseType = "RHEL_BYOS"
                                    }
                                    elseif($azVM.StorageProfile.ImageReference.Publisher -eq "suse")
                                    {
                                        #Update license to SUSE
                                        $azVM.LicenseType = "SLES_BYOS"
                                    }
                                }

                                try
                                {
                                    #https://aka.ms/rhel-cloud-access
                                    #update the virtual machine
                                    Update-AzVM -VM $azVM -ResourceGroupName $azVM.ResourceGroupName -ErrorAction Stop

                                    #add the virtual machine details to output
                                    $vmUpdated = New-Object PSObject
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "OS Type" -Value $azVM.StorageProfile.OsDisk.OsType
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $azVM.StorageProfile.ImageReference.Publisher
                                    $value = "Successfully updated to - " + $azVm.LicenseType
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "LicenseType" -Value $value
                                    $AzureVMHubOutput += $vmUpdated
                                }
                                catch
                                {
                                    #add the virtual machine details to output as errored out
                                    $vmUpdated = New-Object PSObject
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "OS Type" -Value $azVM.StorageProfile.OsDisk.OsType
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $azVM.StorageProfile.ImageReference.Publisher
                                    $value = "Error in updating to - " + $azVm.LicenseType
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "LicenseType" -Value $value
                                    $AzureVMHubOutput += $vmUpdated
                                }
                            }
                            else
                            {
                                #add the virtual machine details to output as errored out
                                $vmUpdated = New-Object PSObject
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "OS Type" -Value $azVM.StorageProfile.OsDisk.OsType
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $azVM.StorageProfile.ImageReference.Publisher
                                $value = "Existing license type - " + $azVm.LicenseType
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "LicenseType" -Value $value
                                $AzureVMHubOutput += $vmUpdated
                            }
                        }
                        catch
                        {
                            $outMessage = $_.Exception + $azVM.Name
                            Write-Error -Message $outMessage
                        }
                    }
                    Write-Host "End processing for subscription - " $azSubName
                }
                else
                {
                    Write-Host "No VMs found in subscription - " $azSubName
                }
            }
            catch
            {
                Write-Error -Message $_.Exception
            }
        }
    }
    else
    {
        Write-Host "Not processing the subscription " $inputSub.Name " as it is marked as" $inputSub.Type "subscription"
    }
}

# Export the script output to a file
if($AzureVMHubOutput-ne $null)
{
    # Exporting the data to csv 
    $AzureVMHubOutput | Export-Csv -Path $fileName -NoTypeInformation -NoClobber
}
else
{
    Write-Host "Script execution finished. No output generated"
}

<#
Windows_Server --> Azure Hybrid Benefit
Blank --> VM Deployed from Azure Gallery
#>