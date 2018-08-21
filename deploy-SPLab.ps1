
[CmdletBinding()]Param([Parameter(Mandatory = $false)][string]$labName = "Lab-SP2016")

# Create my own storage account.
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
    -ResourceGroupName $labName `
    -TemplateParametersFile "$labName\azuredeploy.parameters.json"
    -UploadArtifacts;
