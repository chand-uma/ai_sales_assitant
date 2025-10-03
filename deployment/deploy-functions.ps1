# RIA Azure Functions Deployment Script
# This script deploys the data processing Azure Functions

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting RIA Azure Functions Deployment..." -ForegroundColor Green

# Check if deployment outputs exist
if (Test-Path "deployment-outputs.json") {
    $outputs = Get-Content "deployment-outputs.json" | ConvertFrom-Json
    Write-Host "Using deployment outputs from previous infrastructure deployment" -ForegroundColor Yellow
} else {
    Write-Error "deployment-outputs.json not found. Please run deploy-infrastructure.ps1 first."
    exit 1
}

# Get function app names from outputs
$dataProcessingFunctionName = "$($outputs.resourceGroupName.value)-data-processing"
$apiServicesFunctionName = "$($outputs.resourceGroupName.value)-api-services"
$keyVaultName = $outputs.keyVaultName.value

Write-Host "Data Processing Function: $dataProcessingFunctionName" -ForegroundColor Yellow
Write-Host "API Services Function: $apiServicesFunctionName" -ForegroundColor Yellow
Write-Host "Key Vault: $keyVaultName" -ForegroundColor Yellow

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
} catch {
    Write-Error "Not logged in to Azure. Please run 'az login' and try again."
    exit 1
}

# Check if Azure Functions Core Tools is installed
try {
    $funcVersion = func --version
    Write-Host "Azure Functions Core Tools version: $funcVersion" -ForegroundColor Green
} catch {
    Write-Error "Azure Functions Core Tools is not installed. Please install it and try again."
    Write-Host "Installation command: npm install -g azure-functions-core-tools@4 --unsafe-perm true" -ForegroundColor Yellow
    exit 1
}

# Deploy Data Processing Function
Write-Host "Deploying Data Processing Function..." -ForegroundColor Yellow
Push-Location "../api-services/data-processing"

try {
    # Install dependencies
    Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Python dependencies"
        exit 1
    }

    # Deploy function app
    Write-Host "Deploying to Azure Function App..." -ForegroundColor Yellow
    func azure functionapp publish $dataProcessingFunctionName --python

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy data processing function"
        exit 1
    }

    Write-Host "Data Processing Function deployed successfully" -ForegroundColor Green

    # Configure app settings
    Write-Host "Configuring app settings..." -ForegroundColor Yellow
    
    $appSettings = @{
        "KEY_VAULT_URL" = "https://$keyVaultName.vault.azure.net/"
        "FUNCTIONS_WORKER_RUNTIME" = "python"
        "PYTHONPATH" = "/home/site/wwwroot"
    }

    foreach ($setting in $appSettings.GetEnumerator()) {
        az functionapp config appsettings set --resource-group $ResourceGroupName --name $dataProcessingFunctionName --settings "$($setting.Key)=$($setting.Value)"
    }

} finally {
    Pop-Location
}

# Deploy API Services Function
Write-Host "Deploying API Services Function..." -ForegroundColor Yellow
Push-Location "../api-services/api-services"

try {
    # Install dependencies
    Write-Host "Installing Node.js dependencies..." -ForegroundColor Yellow
    npm install

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Node.js dependencies"
        exit 1
    }

    # Deploy function app
    Write-Host "Deploying to Azure Function App..." -ForegroundColor Yellow
    func azure functionapp publish $apiServicesFunctionName --javascript

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy API services function"
        exit 1
    }

    Write-Host "API Services Function deployed successfully" -ForegroundColor Green

    # Configure app settings
    Write-Host "Configuring app settings..." -ForegroundColor Yellow
    
    $appSettings = @{
        "KEY_VAULT_URL" = "https://$keyVaultName.vault.azure.net/"
        "FUNCTIONS_WORKER_RUNTIME" = "node"
        "WEBSITE_NODE_DEFAULT_VERSION" = "18.17.0"
    }

    foreach ($setting in $appSettings.GetEnumerator()) {
        az functionapp config appsettings set --resource-group $ResourceGroupName --name $apiServicesFunctionName --settings "$($setting.Key)=$($setting.Value)"
    }

} finally {
    Pop-Location
}

# Get function URLs
$dataProcessingUrl = az functionapp show --resource-group $ResourceGroupName --name $dataProcessingFunctionName --query "defaultHostName" --output tsv
$apiServicesUrl = az functionapp show --resource-group $ResourceGroupName --name $apiServicesFunctionName --query "defaultHostName" --output tsv

Write-Host "Function URLs:" -ForegroundColor Green
Write-Host "Data Processing: https://$dataProcessingUrl" -ForegroundColor White
Write-Host "API Services: https://$apiServicesUrl" -ForegroundColor White

Write-Host "Azure Functions deployment completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the functions using the Azure portal" -ForegroundColor White
Write-Host "2. Configure Data Factory pipelines to use the functions" -ForegroundColor White
Write-Host "3. Set up monitoring and alerts" -ForegroundColor White
