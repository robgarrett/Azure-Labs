########################################
# Create domain.

#Requires -Module @{ ModuleName = 'xActiveDirectory'; ModuleVersion = '2.16.0.0'; GUID = '9FECD4F6-8F02-4707-99B3-539E940E9FF5' },@{ ModuleName = 'xStorage'; ModuleVersion = '3.2.0.0'; GUID = '00d73ca1-58b5-46b7-ac1a-5bfcf5814faf' }

Configuration DomainControllerConfig {
    # Get parameters from Azure Automation Account.
    $domainCredential = Get-AutomationPSCredential domainCredential;
    # Import PowerShell dependent modules.
    Import-DscResource -ModuleName @{ModuleName='xActiveDirectory';ModuleVersion='2.16.0.0';GUID='9FECD4F6-8F02-4707-99B3-539E940E9FF5'},@{ModuleName='xStorage';ModuleVersion='3.2.0.0';GUID='00d73ca1-58b5-46b7-ac1a-5bfcf5814faf'};
    Import-DscResource -ModuleName @{ModuleName='xStorage';ModuleVersion='3.2.0.0';GUID='00d73ca1-58b5-46b7-ac1a-5bfcf5814faf'};
    Import-DscResource -Module PSDesiredStateConfiguration;
    # Configure nodes.
    Node $AllNodes.NodeName {
        
    }
}