import { BotFrameworkAdapter, TurnContext, ActivityHandler, MessageFactory } from 'botbuilder';
import { TeamsActivityHandler } from 'botbuilder-teams';
import { ConfigurationService } from './services/ConfigurationService';
import { SemanticKernelService } from './services/SemanticKernelService';
import { DataService } from './services/DataService';
import { Logger } from './utils/Logger';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';

// Initialize services
const configService = new ConfigurationService();
const logger = new Logger();
const dataService = new DataService(configService);
const semanticKernelService = new SemanticKernelService(configService, dataService);

// Create adapter
const adapter = new BotFrameworkAdapter({
    appId: configService.getBotAppId(),
    appPassword: configService.getBotAppPassword()
});

// Error handling
adapter.onTurnError = async (context: TurnContext, error: Error) => {
    logger.error('Bot error occurred:', error);
    
    // Send a message to the user
    await context.sendActivity('Sorry, I encountered an error. Please try again.');
    
    // Log the error
    await context.sendActivity(`Error: ${error.message}`);
};

// Create bot
class RiaBot extends TeamsActivityHandler {
    constructor() {
        super();
        
        this.onMessage(async (context: TurnContext, next: () => Promise<void>) => {
            try {
                const userMessage = context.activity.text;
                logger.info(`User message: ${userMessage}`);
                
                // Process the message with Semantic Kernel
                const response = await semanticKernelService.processMessage(userMessage, context);
                
                // Send response back to user
                await context.sendActivity(MessageFactory.text(response));
                
            } catch (error) {
                logger.error('Error processing message:', error);
                await context.sendActivity('I apologize, but I encountered an error processing your request. Please try again.');
            }
            
            await next();
        });
        
        this.onMembersAdded(async (context: TurnContext, next: () => Promise<void>) => {
            const membersAdded = context.activity.membersAdded;
            const welcomeText = 'Welcome to the Riddell Information Assistant! I can help you with:\n\n' +
                '• Customer information and order history\n' +
                '• Product details and performance\n' +
                '• Sales data and analytics\n' +
                '• Regional performance insights\n' +
                '• Sales rep performance\n\n' +
                'Just ask me anything about your business data!';
            
            for (const member of membersAdded) {
                if (member.id !== context.activity.recipient.id) {
                    await context.sendActivity(MessageFactory.text(welcomeText));
                }
            }
            
            await next();
        });
    }
}

// Create bot instance
const bot = new RiaBot();

// Create Express app for health checks
const app = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        service: 'RIA Bot Service'
    });
});

// Bot endpoint
app.post('/api/messages', (req, res) => {
    adapter.processActivity(req, res, async (context: TurnContext) => {
        await bot.run(context);
    });
});

// Start server
const port = process.env.PORT || 3978;
app.listen(port, () => {
    logger.info(`RIA Bot Service listening on port ${port}`);
});

export { RiaBot };
