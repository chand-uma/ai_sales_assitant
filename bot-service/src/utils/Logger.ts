import * as winston from 'winston';

export class Logger {
    private logger: winston.Logger;

    constructor() {
        this.logger = winston.createLogger({
            level: process.env.LOG_LEVEL || 'info',
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.errors({ stack: true }),
                winston.format.json()
            ),
            defaultMeta: { service: 'ria-bot-service' },
            transports: [
                new winston.transports.Console({
                    format: winston.format.combine(
                        winston.format.colorize(),
                        winston.format.simple()
                    )
                })
            ]
        });

        // Add file transport in production
        if (process.env.NODE_ENV === 'production') {
            this.logger.add(new winston.transports.File({
                filename: 'logs/error.log',
                level: 'error'
            }));
            this.logger.add(new winston.transports.File({
                filename: 'logs/combined.log'
            }));
        }
    }

    info(message: string, meta?: any): void {
        this.logger.info(message, meta);
    }

    error(message: string, error?: any): void {
        this.logger.error(message, error);
    }

    warn(message: string, meta?: any): void {
        this.logger.warn(message, meta);
    }

    debug(message: string, meta?: any): void {
        this.logger.debug(message, meta);
    }

    // Bot-specific logging methods
    logUserMessage(userId: string, message: string): void {
        this.info('User message received', {
            userId,
            message: message.substring(0, 100) // Truncate for privacy
        });
    }

    logBotResponse(userId: string, response: string, processingTime: number): void {
        this.info('Bot response sent', {
            userId,
            responseLength: response.length,
            processingTimeMs: processingTime
        });
    }

    logDataQuery(queryType: string, parameters: any, resultCount: number, processingTime: number): void {
        this.info('Data query executed', {
            queryType,
            parameters,
            resultCount,
            processingTimeMs: processingTime
        });
    }

    logError(error: Error, context?: any): void {
        this.error('Bot error occurred', {
            error: error.message,
            stack: error.stack,
            context
        });
    }
}
