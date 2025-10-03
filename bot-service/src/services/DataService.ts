import { ConfigurationService } from './ConfigurationService';
import { Logger } from '../utils/Logger';
import axios, { AxiosResponse } from 'axios';

export interface CustomerData {
    customer_id: string;
    customer_segment?: string;
    region?: string;
    sales_rep?: string;
    total_orders: number;
    total_sales_amount: number;
    last_order_date?: string;
    created_date?: string;
    updated_date?: string;
}

export interface SalesData {
    customer_id: string;
    product_code: string;
    order_number?: string;
    sales_date: string;
    sales_amount: number;
    sales_quantity: number;
    unit_price: number;
    region?: string;
    channel?: string;
    sales_rep?: string;
    data_source: string;
    customer_segment?: string;
    product_category?: string;
}

export interface ProductPerformance {
    product_code: string;
    product_category?: string;
    total_sales: number;
    total_quantity_sold: number;
    total_sales_amount: number;
    average_unit_price: number;
    first_sale_date?: string;
    last_sale_date?: string;
}

export interface RegionalSales {
    region: string;
    total_sales: number;
    unique_customers: number;
    total_quantity_sold: number;
    total_sales_amount: number;
    average_sale_amount: number;
}

export interface SalesRepPerformance {
    sales_rep: string;
    total_sales: number;
    unique_customers: number;
    total_quantity_sold: number;
    total_sales_amount: number;
    average_sale_amount: number;
}

export class DataService {
    private configService: ConfigurationService;
    private logger: Logger;
    private apiServicesUrl: string;

    constructor(configService: ConfigurationService) {
        this.configService = configService;
        this.logger = new Logger();
        this.apiServicesUrl = process.env.API_SERVICES_URL || 'https://ria-api-services.azurewebsites.net';
    }

    private async makeApiRequest<T>(endpoint: string, params?: Record<string, any>): Promise<T> {
        try {
            const url = `${this.apiServicesUrl}${endpoint}`;
            const response: AxiosResponse<T> = await axios.get(url, { params });
            
            if (response.status === 200) {
                return response.data;
            } else {
                throw new Error(`API request failed with status ${response.status}`);
            }
        } catch (error) {
            this.logger.error(`API request failed for ${endpoint}:`, error);
            throw error;
        }
    }

    async getCustomerData(customerId: string): Promise<CustomerData | null> {
        try {
            this.logger.info(`Getting customer data for ID: ${customerId}`);
            
            const data = await this.makeApiRequest<CustomerData>(`/api/customers/${customerId}`);
            return data;
        } catch (error) {
            this.logger.error(`Error getting customer data for ${customerId}:`, error);
            return null;
        }
    }

    async getCustomerOrders(customerId: string, limit: number = 10): Promise<SalesData[]> {
        try {
            this.logger.info(`Getting orders for customer ${customerId}, limit: ${limit}`);
            
            const data = await this.makeApiRequest<SalesData[]>(`/api/customers/${customerId}/orders`, { limit });
            return data;
        } catch (error) {
            this.logger.error(`Error getting customer orders for ${customerId}:`, error);
            return [];
        }
    }

    async getSalesData(startDate?: string, endDate?: string, region?: string, customerId?: string): Promise<SalesData[]> {
        try {
            this.logger.info(`Getting sales data with filters: startDate=${startDate}, endDate=${endDate}, region=${region}, customerId=${customerId}`);
            
            const params: Record<string, any> = {};
            if (startDate) params.start_date = startDate;
            if (endDate) params.end_date = endDate;
            if (region) params.region = region;
            if (customerId) params.customer_id = customerId;
            
            const data = await this.makeApiRequest<SalesData[]>('/api/sales', params);
            return data;
        } catch (error) {
            this.logger.error('Error getting sales data:', error);
            return [];
        }
    }

    async getTopCustomers(limit: number = 10, startDate?: string, endDate?: string): Promise<CustomerData[]> {
        try {
            this.logger.info(`Getting top ${limit} customers`);
            
            const params: Record<string, any> = { limit };
            if (startDate) params.start_date = startDate;
            if (endDate) params.end_date = endDate;
            
            const data = await this.makeApiRequest<CustomerData[]>(`/api/customers/top`, params);
            return data;
        } catch (error) {
            this.logger.error('Error getting top customers:', error);
            return [];
        }
    }

    async getProductPerformance(productCode?: string, startDate?: string, endDate?: string): Promise<ProductPerformance[]> {
        try {
            this.logger.info(`Getting product performance for product: ${productCode || 'all'}`);
            
            const params: Record<string, any> = {};
            if (productCode) params.product_code = productCode;
            if (startDate) params.start_date = startDate;
            if (endDate) params.end_date = endDate;
            
            const data = await this.makeApiRequest<ProductPerformance[]>(`/api/products/performance`, params);
            return data;
        } catch (error) {
            this.logger.error('Error getting product performance:', error);
            return [];
        }
    }

    async getRegionalSales(startDate?: string, endDate?: string): Promise<RegionalSales[]> {
        try {
            this.logger.info('Getting regional sales data');
            
            const params: Record<string, any> = {};
            if (startDate) params.start_date = startDate;
            if (endDate) params.end_date = endDate;
            
            const data = await this.makeApiRequest<RegionalSales[]>(`/api/sales/regional`, params);
            return data;
        } catch (error) {
            this.logger.error('Error getting regional sales:', error);
            return [];
        }
    }

    async getSalesRepPerformance(startDate?: string, endDate?: string): Promise<SalesRepPerformance[]> {
        try {
            this.logger.info('Getting sales rep performance data');
            
            const params: Record<string, any> = {};
            if (startDate) params.start_date = startDate;
            if (endDate) params.end_date = endDate;
            
            const data = await this.makeApiRequest<SalesRepPerformance[]>(`/api/sales/reps`, params);
            return data;
        } catch (error) {
            this.logger.error('Error getting sales rep performance:', error);
            return [];
        }
    }

    // Helper methods for formatting data for display
    formatCurrency(amount: number): string {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }

    formatNumber(number: number): string {
        return new Intl.NumberFormat('en-US').format(number);
    }

    formatDate(dateString: string): string {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    formatDateTime(dateString: string): string {
        const date = new Date(dateString);
        return date.toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    // Data aggregation helpers
    calculateTotalSales(salesData: SalesData[]): number {
        return salesData.reduce((total, sale) => total + sale.sales_amount, 0);
    }

    calculateAverageOrderValue(salesData: SalesData[]): number {
        if (salesData.length === 0) return 0;
        return this.calculateTotalSales(salesData) / salesData.length;
    }

    getUniqueCustomers(salesData: SalesData[]): string[] {
        const customerIds = new Set(salesData.map(sale => sale.customer_id));
        return Array.from(customerIds);
    }

    getUniqueProducts(salesData: SalesData[]): string[] {
        const productCodes = new Set(salesData.map(sale => sale.product_code));
        return Array.from(productCodes);
    }

    groupByRegion(salesData: SalesData[]): Record<string, SalesData[]> {
        return salesData.reduce((groups, sale) => {
            const region = sale.region || 'Unknown';
            if (!groups[region]) {
                groups[region] = [];
            }
            groups[region].push(sale);
            return groups;
        }, {} as Record<string, SalesData[]>);
    }

    groupByCustomer(salesData: SalesData[]): Record<string, SalesData[]> {
        return salesData.reduce((groups, sale) => {
            if (!groups[sale.customer_id]) {
                groups[sale.customer_id] = [];
            }
            groups[sale.customer_id].push(sale);
            return groups;
        }, {} as Record<string, SalesData[]>);
    }
}
