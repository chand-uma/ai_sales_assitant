# RIA Bot Service Deployment Script
# This script deploys the Teams bot service

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$BotAppId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$BotAppPassword = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting RIA Bot Service Deployment..." -ForegroundColor Green

# Check if deployment outputs exist
if (Test-Path "deployment-outputs.json") {
    $outputs = Get-Content "deployment-outputs.json" | ConvertFrom-Json
    Write-Host "Using deployment outputs from previous infrastructure deployment" -ForegroundColor Yellow
} else {
    Write-Error "deployment-outputs.json not found. Please run deploy-infrastructure.ps1 first."
    exit 1
}

# Get bot service name from outputs
$botServiceName = $outputs.botServiceName.value
$keyVaultName = $outputs.keyVaultName.value

Write-Host "Bot Service: $botServiceName" -ForegroundColor Yellow
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

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Error "Node.js is not installed or not in PATH. Please install Node.js and try again."
    exit 1
}

# Check if npm is installed
try {
    $npmVersion = npm --version
    Write-Host "npm version: $npmVersion" -ForegroundColor Green
} catch {
    Write-Error "npm is not installed or not in PATH. Please install npm and try again."
    exit 1
}

# Navigate to bot service directory
Push-Location "../bot-service"

try {
    # Install dependencies
    Write-Host "Installing bot service dependencies..." -ForegroundColor Yellow
    npm install

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies"
        exit 1
    }

    # Build the bot service
    Write-Host "Building bot service..." -ForegroundColor Yellow
    npm run build

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build bot service"
        exit 1
    }

    # Create deployment package
    Write-Host "Creating deployment package..." -ForegroundColor Yellow
    if (Test-Path "deployment-package.zip") {
        Remove-Item "deployment-package.zip"
    }

    # Create zip package excluding node_modules and source files
    $filesToZip = @(
        "dist/*",
        "package.json",
        "package-lock.json"
    )

    Compress-Archive -Path $filesToZip -DestinationPath "deployment-package.zip" -Force

    # Deploy to Azure App Service
    Write-Host "Deploying to Azure App Service..." -ForegroundColor Yellow
    
    # Get the app service name
    $appServiceName = "$($botServiceName)-bot"
    
    # Deploy using zip deploy
    az webapp deployment source config-zip --resource-group $ResourceGroupName --name $appServiceName --src "deployment-package.zip"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy bot service"
        exit 1
    }

    Write-Host "Bot service deployed successfully" -ForegroundColor Green

    # Configure app settings
    Write-Host "Configuring app settings..." -ForegroundColor Yellow
    
    $appSettings = @{
        "BOT_ID" = $BotAppId
        "BOT_PASSWORD" = $BotAppPassword
        "KEY_VAULT_URL" = "https://$keyVaultName.vault.azure.net/"
        "NODE_ENV" = "production"
        "WEBSITE_NODE_DEFAULT_VERSION" = "18.17.0"
    }

    foreach ($setting in $appSettings.GetEnumerator()) {
        if ($setting.Value) {
            az webapp config appsettings set --resource-group $ResourceGroupName --name $appServiceName --settings "$($setting.Key)=$($setting.Value)"
        }
    }

    # Get the bot service URL
    $botUrl = az webapp show --resource-group $ResourceGroupName --name $appServiceName --query "defaultHostName" --output tsv
    $botEndpoint = "https://$botUrl/api/messages"

    Write-Host "Bot Service URL: $botEndpoint" -ForegroundColor Green

    # Update bot service endpoint
    Write-Host "Updating bot service endpoint..." -ForegroundColor Yellow
    az bot update --resource-group $ResourceGroupName --name $botServiceName --endpoint $botEndpoint

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to update bot service endpoint. You may need to update it manually in the Azure portal."
    }

    Write-Host "Bot service deployment completed successfully!" -ForegroundColor Green
    Write-Host "Bot Endpoint: $botEndpoint" -ForegroundColor White
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Test the bot using the Bot Framework Emulator" -ForegroundColor White
    Write-Host "2. Register the bot with Microsoft Teams" -ForegroundColor White
    Write-Host "3. Deploy the data processing functions" -ForegroundColor White

} finally {
    Pop-Location
}
