# src/lambda_handler.py
import awsgi
from urllib.parse import parse_qsl
from app import app

def _normalize_event(event):
    # Ensure dict
    if not isinstance(event, dict) or not event:
        event = {}

    # ---- Detect shapes ----
    rc = event.get("requestContext", {}) or {}
    is_v2 = "http" in rc  # HTTP API v2
    is_alb = "elb" in rc  # ALB

    # ---- Start with generic defaults expected by awsgi (API GW v1) ----
    event.setdefault("httpMethod", "GET")
    event.setdefault("path", "/")
    event.setdefault("headers", {})
    event.setdefault("body", None)
    event.setdefault("isBase64Encoded", False)
    event.setdefault("requestContext", {"stage": rc.get("stage", "prod")})
    event.setdefault("queryStringParameters", None)
    event.setdefault("multiValueQueryStringParameters", None)
    event.setdefault("pathParameters", None)
    event.setdefault("stageVariables", None)

    # ---- Map HTTP API v2 -> v1 fields ----
    if is_v2:
        http = rc.get("http", {})
        event["httpMethod"] = http.get("method", event["httpMethod"])
        event["path"] = event.get("rawPath", event["path"])
        event["headers"] = event.get("headers", {}) or {}
        # Keep body/base64 flags if provided by v2
        if "body" in event:
            event["body"] = event["body"]
        if "isBase64Encoded" in event:
            event["isBase64Encoded"] = bool(event["isBase64Encoded"])
        # v2 uses rawQueryString; synthesize v1 queryStringParameters
        if event.get("rawQueryString"):
            qs = dict(parse_qsl(event["rawQueryString"], keep_blank_values=True))
            event["queryStringParameters"] = qs if qs else None

    # ---- Map ALB -> v1 minimal fields ----
    if is_alb:
        # ALB events carry httpMethod/path/headers/body/isBase64Encoded already;
        # just make sure defaults exist (done above). Nothing else required.
        pass

    # Normalize path
    if not event["path"].startswith("/"):
        event["path"] = "/" + event["path"]

    return event

def handler(event, context):
    return awsgi.response(app, _normalize_event(event), context)
