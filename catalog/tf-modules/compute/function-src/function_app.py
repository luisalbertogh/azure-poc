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
  - EVENT_HUB_NAME               : name of the Event Hub (set by eventhub unit)
  - EVENT_HUB_CONSUMER_GROUP     : dedicated consumer group for this function
  - EventHubConnection__fullyQualifiedNamespace: Event Hub namespace FQDN
"""

import json
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
        f"Event Hub      : {os.environ.get('EVENT_HUB_NAME', 'not configured')}\n"
    )

    return func.HttpResponse(message, status_code=200, mimetype="text/plain")


@app.event_hub_message_trigger(
    arg_name="event",
    event_hub_name="%EVENT_HUB_NAME%",
    connection="EventHubConnection",
    consumer_group="%EVENT_HUB_CONSUMER_GROUP%",
)
def process_image_upload(event: func.EventHubEvent) -> None:
    """Process a BlobCreated event delivered by Event Grid via Event Hub.

    The event payload is an Event Grid event schema message. The ``data``
    field contains storage-specific properties such as the blob URL, content
    type, and size.

    Flow:
        Storage Account (images container)
            → Event Grid System Topic (Microsoft.Storage.BlobCreated)
            → Event Hub  (evh-images-<env>)
            → This function (Event Hub trigger)
    """
    logging.info("Event Hub trigger: received BlobCreated event from Event Grid.")

    try:
        # The Event Hub message body is the serialised Event Grid event.
        body = event.get_body().decode("utf-8")
        payload = json.loads(body)

        # Event Grid may deliver a single event or a batch (list).
        events = payload if isinstance(payload, list) else [payload]

        for eg_event in events:
            event_type = eg_event.get("eventType", "unknown")
            subject = eg_event.get("subject", "unknown")
            event_time = eg_event.get("eventTime", "unknown")
            data = eg_event.get("data", {})

            blob_url = data.get("url", "unknown")
            content_type = data.get("contentType", "unknown")
            content_length = data.get("contentLength", 0)

            logging.info(
                "Blob uploaded – type=%s subject=%s time=%s url=%s "
                "content_type=%s size_bytes=%d",
                event_type,
                subject,
                event_time,
                blob_url,
                content_type,
                content_length,
            )

    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        logging.error("Failed to decode Event Hub message: %s", exc)

