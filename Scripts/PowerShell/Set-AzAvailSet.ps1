
[CmdletBinding()]Param(
    [Parameter(Mandatory = $true)][string]$VmName,
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    [Parameter(Mandatory = $false)][string]$AvailabilitySetName
);

Function _Login {
    $wrongCreds = $true;
    while ($wrongCreds) {
        try {
            $azAccount = Connect-AzAccount;
            if ($null -eq $azAccount.Context.Tenant) {
                $wrongCreds = $true;
                Write-Host -BackgroundColor Red -ForegroundColor Yellow `
                    "The credentials for $($azAccount.Context.Account.Id) are not valid.";
            } else {
                $wrongCreds = $false;
            }
        } catch {
            Write-Host -BackgroundColor Red -ForegroundColor Yellow `
                "The credentials for $($azAccount.Context.Account.Id) are not valid.";
        }
    }
}

Function _SelectSubscription {
    Write-Host "Choose Subscription:";
    $subs = Get-AzSubscription;
    for ($i = 0; $i -lt $subs.Length; $i++) {
        Write-Host "`t$($i+1): $($subs[$i].Name)";
    }
    do {
        $choice = Read-Host;
        $number = -1;
        if ([int]::TryParse($choice, [ref]$number)) { 
            if ($number -lt 1 -or $number -gt $subs.Length) {
                Write-Host -ForegroundColor Yellow -BackgroundColor Red "Please enter a number between 1 and $($subs.Length).";
            } else {
                break;
            }
        } else {
            Write-Host -ForegroundColor Yellow -BackgroundColor Red "Please enter a number.";
        }
    } while ($true);
    Write-Host -ForegroundColor Green "Setting subscription to $($subs[$number - 1].Name)";
    Select-AzSubscription -Subscription $subs[$number - 1].Id | Out-Null;
}

Try {
    _Login;    
    _SelectSubscription;
    # Get the VM.
    $vm = Get-AzVm -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -ieq $VmName; }
    if ($null -eq $vm) { Throw "Cannot find VM $($VmName) in Resource Group $($ResourceGroupName)."; }
    Write-Host -ForegroundColor Green "Found VM $VmName";
    # Make sure VM is stopped.
    $vmState = (Get-AzVm -ResourceGroupName $ResourceGroupName  -Name $VmName -Status).Statuses[1].Code;
    if ($vmState -ine "PowerState/deallocated" -and $vmState -ine "PowerState/Stopped") {
        Write-Host "Stopping VM";
        $vm | Stop-AzVM -StayProvisioned -Force | Out-Null;
    }
    Write-Host -ForegroundColor Green "Exporting VM config to file.";
    ConvertTo-Json -InputObject $vm -Depth 100 | Out-File "$PSScriptRoot\$($ResourceGroupName)-$($VmName).json";
    # Change the VM object.
    $vm.StorageProfile.OsDisk.CreateOption = "Attach";
    for ($i = 0; $i -lt $vm.StorageProfile.DataDisks.Count; $i++) {
        $vm.StorageProfile.DataDisks[$i].CreateOption = "Attach";
    }
    if ($AvailabilitySetName -eq "0") {
        $vm.AvailabilitySetReference = $null;
    } else {
        Write-Host -ForegroundColor Green "Getting Avail Set $AvailabilitySetName";
        $availSetId = (Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName).Id;
        $availSet = [Microsoft.Azure.Management.Compute.Models.SubResource]::new();
        $availSet.Id = $availSetId;
        $vm.AvailabilitySetReference = $availSet;
    }
    # Disconnecting dependencies.
    $vm.OSProfile = $null;
    $vm.StorageProfile.ImageReference = $null;
    if ($vm.StorageProfile.OsDisk.Image) { $vm.StorageProfile.OsDisk.Image = $null; }
    Write-Host -ForegroundColor Green "Recreating VM";
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force | Out-Null;
    Start-Sleep 5;
    New-AzVM -ResourceGroupName $vm.ResourceGroupName -Location $vm.Location -VM $vm | Out-Null;
} Catch {
    Write-Host -ForegroundColor Red $_.Exception;
}
