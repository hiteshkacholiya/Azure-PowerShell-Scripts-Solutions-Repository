$ErrorActionPreference = "Continue"
$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_AzureVM_HubLicenseChange_Output.csv"
$AzureVMHubOutput = @()

# Get all subscriptions
$azSubs = Get-AzSubscription

#validate if subscriptions are returned
if(($azSubs -ne $null) -and ($azSubs.Count -gt 0))
{
    foreach ( $azSub in $azSubs )
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
                            $azVM.LicenseType = "Windows_Server"
                            try
                            {
                                #update the virtual machine
                                Update-AzVM -VM $azVM -ResourceGroupName $azVM.ResourceGroupName

                                #add the virtual machine details to output
                                $vmUpdated = New-Object PSObject
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "LicenseType" -Value $azVM.LicenseType
                                $AzureVMHubOutput += $vmUpdated
                            }
                            catch
                            {
                                #add the virtual machine details to output as errored out
                                $vmUpdated = New-Object PSObject
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                $vmUpdated | Add-Member -MemberType NoteProperty -Name "LicenseType" -Value "Error in Update"
                                $AzureVMHubOutput += $vmUpdated
                            }
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