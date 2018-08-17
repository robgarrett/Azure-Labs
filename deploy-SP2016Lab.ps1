
[CmdletBinding()]Param()

# Create my own storage account.
$labName = "Lab-SP2016";
$ResourceGroupName = "$($labName)-Artifacts";
$StorageAccountName = $ResourceGroupName.ToLower().Replace("-", "");
$Location = "CentralUS";

New-AzureRmResourceGroup -Location $Location -Name $ResourceGroupName -Force;
New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $ResourceGroupName -Location $Location;

# Deploying.
./deployAzureTemplate.ps1 `
    -StorageAccountName $StorageAccountName
    -ArtifactStagingDirectory "Common\AD" `
    -ResourceGroupLocation "CentralUS" `
    -ResourceGroupName "Lab-SP2016" `
    -TemplateParametersFile "Lab-SP2016\azuredeploy.parameters.json"
    -UploadArtifacts;
