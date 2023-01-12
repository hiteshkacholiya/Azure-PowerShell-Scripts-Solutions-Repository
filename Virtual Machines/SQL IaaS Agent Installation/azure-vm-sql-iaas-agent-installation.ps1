$ErrorActionPreference = "Continue"
$fileName = "$((Get-Date).ToString("yyyy-MM-dd_HHmmss"))_AzureVM_SQLIaaSAgentzInstallation_Output.csv"
$scriptOutput = @()

# Get all subscriptions
$azSubs = Get-AzSubscription

$cred=Get-Credential

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
            
            #Validate if the required provider is registered for SQL IaaS Agent extension
            $providerFlag = $false
            $resourceProviders = Get-AzResourceProvider -ProviderNamespace Microsoft.SqlVirtualMachine | Select-Object ProviderNamespace -Unique
            If($resourceProviders -eq $null)
            {
                try
                {
                    # Register the SQL IaaS Agent extension to your subscription
                    Register-AzResourceProvider -ProviderNamespace Microsoft.SqlVirtualMachine
                    $providerFlag = $true
                }
                catch
                {
                    Write-Error -Message $_.Exception
                }
            }
            else
            {
                $providerFlag = $true
            }

            if($providerFlag)
            {
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
                            if($azVM -ne $null)
                            {
                                
                                try
                                {
                                    # Register SQL VM with 'Lightweight' SQL IaaS agent
                                    New-AzSqlVM -Name $azVM.Name -ResourceGroupName $azVM.ResourceGroupName -Location $azVM.Location -LicenseType AHUB -SqlManagementType LightWeight -Sku Developer
                                }
                                catch
                                {
                                    Write-Host $_.Exception
                                }

                                #convert the agent to full mode.
                                try
                                {
                                    # Update virtual machine with SQL IaaS Agent extension in full mode
                                    Update-AzSqlVM -Name $azVM.Name -ResourceGroupName $azVM.ResourceGroupName -SqlManagementType Full -LicenseType AHUB -Sku Developer
                                    #add the virtual machine details to output
                                    $vmUpdated = New-Object PSObject
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SQL IaaS Extension" -Value "Installed"
                                    $scriptOutput += $vmUpdated
                                }
                                catch
                                {
                                    #add the virtual machine details to output as errored out
                                    $vmUpdated = New-Object PSObject
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $azSubName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $azVM.ResourceGroupName
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "VMName" -Value $azVM.Name
                                    $vmUpdated | Add-Member -MemberType NoteProperty -Name "SQL IaaS Extension" -Value "Installation Failed with error " + $_.Exception
                                    $scriptOutput += $vmUpdated
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
            else
            {
                Write-Host "Please register provider Microsoft.SqlVirtualMachine for SQL IaaS extension as it cound not be done programmatically."
            }
        }
        catch
        {
            Write-Error -Message $_.Exception
        }
    }
}

# Export the script output to a file
if($AzureSQLIaaSExtensionOutpu-ne $null)
{
    # Exporting the data to csv 
    $scriptOutput | Export-Csv -Path $fileName -NoTypeInformation -NoClobber
}
else
{
    Write-Host "Script execution finished. No output generated"
}

<#
Windows_Server --> Azure Hybrid Benefit
Blank --> VM Deployed from Azure Gallery
#>