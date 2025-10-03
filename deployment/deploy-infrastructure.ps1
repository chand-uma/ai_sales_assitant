# RIA Infrastructure Deployment Script
# This script deploys the Azure infrastructure for the RIA system

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$SapSftpServer = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SapSftpUsername = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SapSftpPassword = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OpenAiEndpoint = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OpenAiApiKey = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting RIA Infrastructure Deployment..." -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Check if Azure CLI is installed and user is logged in
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI and try again."
    exit 1
}

# Check if user is logged in
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Error "Not logged in to Azure. Please run 'az login' and try again."
    exit 1
}

# Create resource group if it doesn't exist
Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group"
    exit 1
}

Write-Host "Resource group created successfully" -ForegroundColor Green

# Deploy main Bicep template
Write-Host "Deploying main infrastructure..." -ForegroundColor Yellow
$deploymentName = "ria-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentParams = @{
    "resourceGroupName" = $ResourceGroupName
    "location" = $Location
    "environment" = $Environment
    "sapSftpServer" = $SapSftpServer
    "sapSftpUsername" = $SapSftpUsername
    "sapSftpPassword" = $SapSftpPassword
    "openAiEndpoint" = $OpenAiEndpoint
    "openAiApiKey" = $OpenAiApiKey
}

$paramString = ""
foreach ($param in $deploymentParams.GetEnumerator()) {
    if ($param.Value) {
        $paramString += " $($param.Key)=`"$($param.Value)`""
    }
}

$deployCommand = "az deployment group create --resource-group $ResourceGroupName --template-file ../infrastructure/main.bicep --name $deploymentName$paramString"

Write-Host "Executing: $deployCommand" -ForegroundColor Cyan
Invoke-Expression $deployCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Infrastructure deployment failed"
    exit 1
}

Write-Host "Infrastructure deployed successfully" -ForegroundColor Green

# Get deployment outputs
Write-Host "Getting deployment outputs..." -ForegroundColor Yellow
$outputs = az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output json | ConvertFrom-Json

Write-Host "Deployment Outputs:" -ForegroundColor Green
Write-Host "Storage Account: $($outputs.storageAccountName.value)" -ForegroundColor White
Write-Host "SQL Server: $($outputs.sqlServerName.value)" -ForegroundColor White
Write-Host "Key Vault: $($outputs.keyVaultName.value)" -ForegroundColor White
Write-Host "Bot Service: $($outputs.botServiceName.value)" -ForegroundColor White
Write-Host "AI Search: $($outputs.aiSearchName.value)" -ForegroundColor White

# Save outputs to file for other scripts
$outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath "deployment-outputs.json" -Encoding UTF8

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure SAP SFTP connection details in Key Vault" -ForegroundColor White
Write-Host "2. Set up OpenAI API key in Key Vault" -ForegroundColor White
Write-Host "3. Deploy the bot service using deploy-bot.ps1" -ForegroundColor White
Write-Host "4. Deploy the data processing functions using deploy-functions.ps1" -ForegroundColor White
Write-Host "5. Configure Data Factory pipelines" -ForegroundColor White
