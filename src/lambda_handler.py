# src/lambda_handler.py
import awsgi
from app import app

def handler(event, context):
    return awsgi.response(app, event, context)