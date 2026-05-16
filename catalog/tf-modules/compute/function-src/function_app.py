"""
Hello World Azure Function – HTTP Trigger (Python v2 model)

This function serves as a minimal example deployed alongside the infrastructure.
It is accessible ONLY from within the private virtual network via the private
endpoint – no public internet access is permitted.

Authentication level is ANONYMOUS within the VNet context. Callers inside the
VNet do not need to present a function key.

Environment variables available at runtime (set via app_settings in Terraform):
  - IMAGES_STORAGE_ACCOUNT_NAME : name of the images storage account
  - IMAGES_CONTAINER_NAME        : name of the images blob container
  - COSMOS_DB_ACCOUNT_URI        : Cosmos DB account URI (when provisioned)
  - CONTENT_UNDERSTANDING_ENDPOINT: AI Foundry Content Understanding endpoint
"""

import logging
import os

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="hello", methods=["GET", "POST"])
def hello_world(req: func.HttpRequest) -> func.HttpResponse:
    """Return a greeting message, optionally personalised with a name parameter."""
    logging.info("Python HTTP trigger function processed a request.")

    name = req.params.get("name")
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get("name")

    greeting = f"Hello, {name}!" if name else "Hello, World!"
    message = (
        f"{greeting}\n"
        f"Running on Azure Functions Flex Consumption plan (Python 3.11).\n"
        f"Images storage : {os.environ.get('IMAGES_STORAGE_ACCOUNT_NAME', 'not configured')}"
        f"/{os.environ.get('IMAGES_CONTAINER_NAME', 'not configured')}\n"
        f"Cosmos DB URI  : {os.environ.get('COSMOS_DB_ACCOUNT_URI', 'not configured')}\n"
        f"AI Foundry     : {os.environ.get('CONTENT_UNDERSTANDING_ENDPOINT', 'not configured')}\n"
    )

    return func.HttpResponse(message, status_code=200, mimetype="text/plain")
