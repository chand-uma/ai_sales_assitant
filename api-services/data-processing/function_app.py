import logging
import azure.functions as func
from .process_sap_data import process_sap_data
from .update_ai_search import update_ai_search
from .generate_insights import generate_insights

app = func.FunctionApp()

@app.function_name(name="ProcessSapData")
@app.timer_trigger(schedule="0 0 2 * * *", arg_name="myTimer", run_on_startup=False,
              use_monitor=False)
def process_sap_data_timer(myTimer: func.TimerRequest) -> None:
    """
    Timer-triggered function to process SAP data daily at 2 AM
    """
    if myTimer.past_due:
        logging.info('The timer is past due!')
    
    logging.info('Starting SAP data processing...')
    try:
        result = process_sap_data()
        logging.info(f'SAP data processing completed: {result}')
    except Exception as e:
        logging.error(f'Error processing SAP data: {str(e)}')
        raise

@app.function_name(name="UpdateAISearch")
@app.timer_trigger(schedule="0 30 2 * * *", arg_name="myTimer", run_on_startup=False,
              use_monitor=False)
def update_ai_search_timer(myTimer: func.TimerRequest) -> None:
    """
    Timer-triggered function to update AI Search index after data processing
    """
    if myTimer.past_due:
        logging.info('The timer is past due!')
    
    logging.info('Starting AI Search index update...')
    try:
        result = update_ai_search()
        logging.info(f'AI Search index update completed: {result}')
    except Exception as e:
        logging.error(f'Error updating AI Search: {str(e)}')
        raise

@app.function_name(name="GenerateInsights")
@app.timer_trigger(schedule="0 0 3 * * *", arg_name="myTimer", run_on_startup=False,
              use_monitor=False)
def generate_insights_timer(myTimer: func.TimerRequest) -> None:
    """
    Timer-triggered function to generate business insights
    """
    if myTimer.past_due:
        logging.info('The timer is past due!')
    
    logging.info('Starting insights generation...')
    try:
        result = generate_insights()
        logging.info(f'Insights generation completed: {result}')
    except Exception as e:
        logging.error(f'Error generating insights: {str(e)}')
        raise

@app.function_name(name="ProcessSapDataHttp")
@app.route(route="process-sap-data", methods=["POST"])
def process_sap_data_http(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP-triggered function to process SAP data on demand
    """
    logging.info('HTTP request received for SAP data processing')
    
    try:
        result = process_sap_data()
        return func.HttpResponse(
            f"SAP data processing completed: {result}",
            status_code=200
        )
    except Exception as e:
        logging.error(f'Error processing SAP data: {str(e)}')
        return func.HttpResponse(
            f"Error processing SAP data: {str(e)}",
            status_code=500
        )

@app.function_name(name="GetCustomerData")
@app.route(route="customers/{customer_id}", methods=["GET"])
def get_customer_data(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP function to get customer data
    """
    customer_id = req.route_params.get('customer_id')
    
    if not customer_id:
        return func.HttpResponse(
            "Customer ID is required",
            status_code=400
        )
    
    try:
        # Import here to avoid circular imports
        from .data_queries import get_customer_data as query_customer_data
        
        customer_data = query_customer_data(customer_id)
        
        if customer_data:
            return func.HttpResponse(
                customer_data,
                mimetype="application/json",
                status_code=200
            )
        else:
            return func.HttpResponse(
                "Customer not found",
                status_code=404
            )
    except Exception as e:
        logging.error(f'Error getting customer data: {str(e)}')
        return func.HttpResponse(
            f"Error getting customer data: {str(e)}",
            status_code=500
        )

@app.function_name(name="GetSalesData")
@app.route(route="sales", methods=["GET"])
def get_sales_data(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP function to get sales data with filters
    """
    try:
        # Import here to avoid circular imports
        from .data_queries import get_sales_data as query_sales_data
        
        # Get query parameters
        start_date = req.params.get('start_date')
        end_date = req.params.get('end_date')
        region = req.params.get('region')
        customer_id = req.params.get('customer_id')
        
        sales_data = query_sales_data(
            start_date=start_date,
            end_date=end_date,
            region=region,
            customer_id=customer_id
        )
        
        return func.HttpResponse(
            sales_data,
            mimetype="application/json",
            status_code=200
        )
    except Exception as e:
        logging.error(f'Error getting sales data: {str(e)}')
        return func.HttpResponse(
            f"Error getting sales data: {str(e)}",
            status_code=500
        )
