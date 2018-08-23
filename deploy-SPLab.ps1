
[CmdletBinding()]Param([Parameter(Mandatory = $false)][string]$labName = "Lab-SP2016")

# Create my own storage account.
$ResourceGroupName = "$($labName)-Artifacts";
$StorageAccountName = $ResourceGroupName.ToLower().Replace("-", "");
$StorageContainerName = "$($ResourceGroupName.ToLower())-stageartifacts";
$Location = "CentralUS";

New-AzureRmResourceGroup -Location $Location -Name $ResourceGroupName -Force;
New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $ResourceGroupName -Location $Location;

Function EmptyContainer {
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName});
    $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccount.Context;
    Get-AzureStorageBlob -Container $StorageContainerName -blob * -Context $context | % {
        Remove-AzureStorageBlob -Blob $_.Name -Container $StorageContainerName -Context $context;
    }
}

# Deploy AD.
./deployAzureTemplate.ps1 `
    -StorageAccountName $StorageAccountName
    -ArtifactStagingDirectory "Common\AD" `
    -ResourceGroupLocation "CentralUS" `
    -ResourceGroupName $labName `
    -TemplateParametersFile "$labName\AD\azuredeploy.parameters.json"
    -UploadArtifacts;

# Deploy SP.
EmptyContainer;
./deployAzureTemplate.ps1 `
    -StorageAccountName $StorageAccountName
    -ArtifactStagingDirectory "Common\SP" `
    -ResourceGroupLocation "CentralUS" `
    -ResourceGroupName $labName `
    -TemplateParametersFile "$labName\SP\azuredeploy.parameters.json"
    -UploadArtifacts;
