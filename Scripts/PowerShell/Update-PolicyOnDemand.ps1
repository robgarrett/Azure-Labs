<#
    .SYNOPSIS Force a policy update on my Azure subscriptions.

#>
[CmdletBinding()]Param();

Try {
    Import-Module Az -Force;
    $account = Get-AzContext;
    if ($null -eq $account -or $null -eq $account.Account) {
        Write-Output "Account context not found, please authenticate";
        Connect-AzAccount -UseDeviceAuthentication -SkipContextPopulation;
    }

    $tenantId = $account.Tenant.Id;
    $subs = Get-AzSubscription -TenantId $tenantId;
    $subs | ForEach-Object {
        Set-AzContext -Subscription $_ -Tenant $tenantId;
        $subId = $_.Id;
        Write-Verbose "Subscription: $subId";
        $azContext = Get-AzContext
        $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile;
        $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile);
        $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId);
        $authHeader = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer " + $token.AccessToken
        }
        $restUri = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.PolicyInsights/policyStates/latest/triggerEvaluation?api-version=2018-07-01-preview";
        $response = Invoke-WebRequest -Uri $restUri -Method POST -Headers $authHeader;
        $response;
    }
}
Catch {
    Write-Host -ForegroundColor Red $_.Exception;
}
