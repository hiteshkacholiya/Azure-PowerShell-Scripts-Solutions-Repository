$ErrorActionPreference = "Continue"
$azSubs = Get-AzSubscription
$dateTime = Get-Date -Format "yyMMdd-HHmm" 
$AzureVMOutput = @()

foreach ( $azSub in $azSubs )
{
    try
    {
        Select-AzSubscription -Subscription $azSub | Out-Null

        $azSubName = $azSub.Name

        Write-Host "Context set to - " $azSubName
        
        $AzureVMs = Get-AzVM -ErrorAction SilentlyContinue
        
        if(($AzureVMs -ne $null) -and ($AzureVMs.Count -gt 0))
        {
            foreach ($azVM in $AzureVMs) 
            {
                try
                {
                    $props = @{
                        VMName = $azVM.Name
                        Region = $azVM.Location
                        OsType = $azVM.StorageProfile.OsDisk.OsType
                        ResourceGroupName = $azVM.ResourceGroupName
                        SubscriptionName = $azSubName
                        }

                    if (!$azVM.LicenseType) 
                    {
                        $props += @{
                        LicenseType = "No License"
                        }
                    }
                    else 
                    {
                        $props += @{
                        LicenseType = $azVM.LicenseType
                        }
                    }
                    $ServiceObject = New-Object -TypeName PSObject -Property $props
                    $AzureVMOutput += $ServiceObject
                }
                catch
                {
                    $outMessage = $_.Exception + $azVM.Name
                    Write-Error -Message $outMessage
                }
            }
            Write-Host "Processing completed for - " $azSubName
        }
        else
        {
            Write-Host "No VMs found in - " $azSubName
        }
    }
    catch
    {
        Write-Error -Message $_.Exception
    }
}

if($AzureVMOutput-ne $null)
{
    $AzureVMOutput | Export-Csv -Path "C:\Users\hites\Downloads\$dateTime-AzVM-Licensing.csv" -NoTypeInformation -force
}
else
{
    Write-Host "Script execution finished. No output generated"
}

<#
Windows_Server --> Azure Hybrid Benefit
Blank --> VM Deployed from Azure Gallery
Possible values for Windows Server operating system are: 
- Windows_Client 
- Windows_Server
Possible values for Linux Server operating system are: 
- RHEL_BYOS (for RHEL) 
- SLES_BYOS (for SUSE)
#>