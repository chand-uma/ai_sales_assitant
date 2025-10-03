import { DefaultAzureCredential } from 'azure-identity';
import { SecretClient } from 'azure-keyvault-secrets';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

export class ConfigurationService {
    private credential: DefaultAzureCredential;
    private secretClient?: SecretClient;
    private keyVaultUrl?: string;

    constructor() {
        this.credential = new DefaultAzureCredential();
        this.keyVaultUrl = process.env.KEY_VAULT_URL;
        
        if (this.keyVaultUrl) {
            this.secretClient = new SecretClient(this.keyVaultUrl, this.credential);
        }
    }

    private async getSecret(secretName: string, defaultValue?: string): Promise<string> {
        try {
            if (this.secretClient) {
                const secret = await this.secretClient.getSecret(secretName);
                return secret.value;
            }
        } catch (error) {
            console.warn(`Failed to get secret ${secretName} from Key Vault:`, error);
        }
        
        return process.env[secretName] || defaultValue || '';
    }

    // Bot configuration
    getBotAppId(): string {
        return process.env.BOT_ID || '';
    }

    getBotAppPassword(): string {
        return process.env.BOT_PASSWORD || '';
    }

    // Database configuration
    async getSqlConnectionString(): Promise<string> {
        return await this.getSecret('SQL_CONNECTION_STRING', process.env.SQL_CONNECTION_STRING);
    }

    // AI Search configuration
    async getAiSearchEndpoint(): Promise<string> {
        return await this.getSecret('AI_SEARCH_ENDPOINT', process.env.AI_SEARCH_ENDPOINT);
    }

    async getAiSearchKey(): Promise<string> {
        return await this.getSecret('AI_SEARCH_KEY', process.env.AI_SEARCH_KEY);
    }

    // OpenAI configuration
    async getOpenAiEndpoint(): Promise<string> {
        return await this.getSecret('OPENAI_ENDPOINT', process.env.OPENAI_ENDPOINT);
    }

    async getOpenAiApiKey(): Promise<string> {
        return await this.getSecret('OPENAI_API_KEY', process.env.OPENAI_API_KEY);
    }

    // API Services configuration
    async getApiServicesUrl(): Promise<string> {
        return await this.getSecret('API_SERVICES_URL', process.env.API_SERVICES_URL || 'https://ria-api-services.azurewebsites.net');
    }

    // Environment configuration
    getEnvironment(): string {
        return process.env.NODE_ENV || 'development';
    }

    isDevelopment(): boolean {
        return this.getEnvironment() === 'development';
    }

    isProduction(): boolean {
        return this.getEnvironment() === 'production';
    }

    // Logging configuration
    getLogLevel(): string {
        return process.env.LOG_LEVEL || 'info';
    }

    // Bot behavior configuration
    getMaxRetries(): number {
        return parseInt(process.env.MAX_RETRIES || '3');
    }

    getRequestTimeout(): number {
        return parseInt(process.env.REQUEST_TIMEOUT || '30000');
    }

    // Teams configuration
    getTeamsAppId(): string {
        return process.env.TEAMS_APP_ID || '';
    }

    getTeamsAppPassword(): string {
        return process.env.TEAMS_APP_PASSWORD || '';
    }
}
