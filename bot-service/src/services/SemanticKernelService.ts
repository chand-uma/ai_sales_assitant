import { Kernel, KernelBuilder, KernelConfig, KernelPlugin, KernelFunction } from 'semantic-kernel';
import { ConfigurationService } from './ConfigurationService';
import { DataService } from './DataService';
import { Logger } from '../utils/Logger';
import { TurnContext } from 'botbuilder';

export class SemanticKernelService {
    private kernel: Kernel;
    private configService: ConfigurationService;
    private dataService: DataService;
    private logger: Logger;

    constructor(configService: ConfigurationService, dataService: DataService) {
        this.configService = configService;
        this.dataService = dataService;
        this.logger = new Logger();
        this.kernel = this.initializeKernel();
    }

    private async initializeKernel(): Promise<Kernel> {
        try {
            const openAiEndpoint = await this.configService.getOpenAiEndpoint();
            const openAiApiKey = await this.configService.getOpenAiApiKey();

            if (!openAiEndpoint || !openAiApiKey) {
                throw new Error('OpenAI configuration not found');
            }

            const kernel = new KernelBuilder()
                .withOpenAIChatCompletionService('gpt-4', openAiApiKey, openAiEndpoint)
                .build();

            // Add plugins
            await this.addDataPlugins(kernel);
            await this.addUtilityPlugins(kernel);

            return kernel;
        } catch (error) {
            this.logger.error('Failed to initialize Semantic Kernel:', error);
            throw error;
        }
    }

    private async addDataPlugins(kernel: Kernel): Promise<void> {
        // Customer data plugin
        const customerPlugin = {
            name: 'CustomerData',
            functions: [
                {
                    name: 'GetCustomerInfo',
                    description: 'Get customer information by customer ID',
                    parameters: {
                        type: 'object',
                        properties: {
                            customerId: {
                                type: 'string',
                                description: 'The customer ID to look up'
                            }
                        },
                        required: ['customerId']
                    },
                    handler: async (args: any) => {
                        const customerId = args.customerId;
                        return await this.dataService.getCustomerData(customerId);
                    }
                },
                {
                    name: 'GetCustomerOrders',
                    description: 'Get recent orders for a customer',
                    parameters: {
                        type: 'object',
                        properties: {
                            customerId: {
                                type: 'string',
                                description: 'The customer ID'
                            },
                            limit: {
                                type: 'number',
                                description: 'Maximum number of orders to return',
                                default: 10
                            }
                        },
                        required: ['customerId']
                    },
                    handler: async (args: any) => {
                        const customerId = args.customerId;
                        const limit = args.limit || 10;
                        return await this.dataService.getCustomerOrders(customerId, limit);
                    }
                }
            ]
        };

        // Sales data plugin
        const salesPlugin = {
            name: 'SalesData',
            functions: [
                {
                    name: 'GetSalesData',
                    description: 'Get sales data with optional filters',
                    parameters: {
                        type: 'object',
                        properties: {
                            startDate: {
                                type: 'string',
                                description: 'Start date in YYYY-MM-DD format'
                            },
                            endDate: {
                                type: 'string',
                                description: 'End date in YYYY-MM-DD format'
                            },
                            region: {
                                type: 'string',
                                description: 'Region filter'
                            },
                            customerId: {
                                type: 'string',
                                description: 'Customer ID filter'
                            }
                        }
                    },
                    handler: async (args: any) => {
                        return await this.dataService.getSalesData(
                            args.startDate,
                            args.endDate,
                            args.region,
                            args.customerId
                        );
                    }
                },
                {
                    name: 'GetTopCustomers',
                    description: 'Get top customers by sales amount',
                    parameters: {
                        type: 'object',
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Number of top customers to return',
                                default: 10
                            },
                            startDate: {
                                type: 'string',
                                description: 'Start date in YYYY-MM-DD format'
                            },
                            endDate: {
                                type: 'string',
                                description: 'End date in YYYY-MM-DD format'
                            }
                        }
                    },
                    handler: async (args: any) => {
                        const limit = args.limit || 10;
                        return await this.dataService.getTopCustomers(
                            limit,
                            args.startDate,
                            args.endDate
                        );
                    }
                }
            ]
        };

        // Product data plugin
        const productPlugin = {
            name: 'ProductData',
            functions: [
                {
                    name: 'GetProductPerformance',
                    description: 'Get product performance data',
                    parameters: {
                        type: 'object',
                        properties: {
                            productCode: {
                                type: 'string',
                                description: 'Product code to filter by'
                            },
                            startDate: {
                                type: 'string',
                                description: 'Start date in YYYY-MM-DD format'
                            },
                            endDate: {
                                type: 'string',
                                description: 'End date in YYYY-MM-DD format'
                            }
                        }
                    },
                    handler: async (args: any) => {
                        return await this.dataService.getProductPerformance(
                            args.productCode,
                            args.startDate,
                            args.endDate
                        );
                    }
                }
            ]
        };

        // Regional data plugin
        const regionalPlugin = {
            name: 'RegionalData',
            functions: [
                {
                    name: 'GetRegionalSales',
                    description: 'Get sales data by region',
                    parameters: {
                        type: 'object',
                        properties: {
                            startDate: {
                                type: 'string',
                                description: 'Start date in YYYY-MM-DD format'
                            },
                            endDate: {
                                type: 'string',
                                description: 'End date in YYYY-MM-DD format'
                            }
                        }
                    },
                    handler: async (args: any) => {
                        return await this.dataService.getRegionalSales(
                            args.startDate,
                            args.endDate
                        );
                    }
                }
            ]
        };

        // Add plugins to kernel
        kernel.addPlugin(customerPlugin);
        kernel.addPlugin(salesPlugin);
        kernel.addPlugin(productPlugin);
        kernel.addPlugin(regionalPlugin);
    }

    private async addUtilityPlugins(kernel: Kernel): Promise<void> {
        // Date utility plugin
        const datePlugin = {
            name: 'DateUtils',
            functions: [
                {
                    name: 'GetCurrentDate',
                    description: 'Get the current date in YYYY-MM-DD format',
                    parameters: {
                        type: 'object',
                        properties: {}
                    },
                    handler: async () => {
                        return new Date().toISOString().split('T')[0];
                    }
                },
                {
                    name: 'GetDateRange',
                    description: 'Get a date range (e.g., last 30 days)',
                    parameters: {
                        type: 'object',
                        properties: {
                            days: {
                                type: 'number',
                                description: 'Number of days to go back',
                                default: 30
                            }
                        }
                    },
                    handler: async (args: any) => {
                        const days = args.days || 30;
                        const endDate = new Date();
                        const startDate = new Date();
                        startDate.setDate(endDate.getDate() - days);
                        
                        return {
                            startDate: startDate.toISOString().split('T')[0],
                            endDate: endDate.toISOString().split('T')[0]
                        };
                    }
                }
            ]
        };

        kernel.addPlugin(datePlugin);
    }

    async processMessage(userMessage: string, context: TurnContext): Promise<string> {
        try {
            this.logger.info(`Processing message: ${userMessage}`);

            // Create a prompt for the AI
            const systemPrompt = `You are the Riddell Information Assistant, a helpful AI assistant that can answer questions about business data including customers, sales, products, and regional performance.

You have access to the following data sources:
- Customer information and order history
- Sales data and analytics
- Product performance data
- Regional sales data
- Sales rep performance

When users ask questions, use the available functions to retrieve relevant data and provide helpful, accurate responses. Always format your responses in a clear, professional manner.

If you need to ask for clarification, do so politely. If you cannot find the requested information, explain what you were able to find and suggest alternative queries.

Current user message: ${userMessage}`;

            // Use the kernel to process the message
            const result = await this.kernel.invokeAsync({
                prompt: systemPrompt,
                variables: {
                    userMessage: userMessage
                }
            });

            return result.toString();
        } catch (error) {
            this.logger.error('Error processing message with Semantic Kernel:', error);
            
            // Fallback response
            return "I apologize, but I'm having trouble processing your request right now. Please try rephrasing your question or ask me about customer data, sales information, or product performance.";
        }
    }

    async getAvailableFunctions(): Promise<string[]> {
        try {
            const plugins = this.kernel.getPlugins();
            const functions: string[] = [];
            
            for (const plugin of plugins) {
                for (const func of plugin.functions) {
                    functions.push(`${plugin.name}.${func.name}: ${func.description}`);
                }
            }
            
            return functions;
        } catch (error) {
            this.logger.error('Error getting available functions:', error);
            return [];
        }
    }
}
