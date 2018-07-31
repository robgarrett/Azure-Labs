
[CmdletBinding()]Param()

./deployAzureTemplate.ps1 `
    -ArtifactStagingDirectory "Lab-SP2016" `
    -ResourceGroupLocation "CentralUS" `
    -ResourceGroupName "Lab-SP2016" `
    -UploadArtifacts