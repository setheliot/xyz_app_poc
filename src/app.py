from flask import Flask, request, render_template, redirect, url_for
import os
import uuid
import boto3
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)
app = Flask(__name__)

# Function to get the node name from the environment variable
def get_node_name():
    return os.getenv("NODE_NAME", "Unavailable")

# Get pod name if defined
def get_pod_name():
    return os.getenv("KUBERNETES_POD_NAME", os.getenv("HOSTNAME", "Unknown-Pod"))

# Function to get the AWS Region from the environment variable
def get_region():
    return os.getenv("AWS_REGION", "us-east-1")

region = get_region()

# Initialize DynamoDB client
def initialize_dynamodb():
    log.info(f"Using region: {region}")
    try:
        dynamodb = boto3.resource('dynamodb', region_name=region)
        table = dynamodb.Table(os.getenv("DDB_TABLE", "guestbook"))
        return table, None
    except Exception as e:
        error = f"Error initializing DynamoDB table: {e}"
        log.error(error)
        return None, error

table, _ = initialize_dynamodb()

@app.route("/", methods=["GET", "POST"])
def hello():
    error = None

    # Get the node and pod name for display
    node_name = get_node_name()
    pod_name = get_pod_name()

    # If table did not properly initialize, then try again
    global table
    if not table:
        table, error = initialize_dynamodb()
        if not table:
            return render_template('guestbook.html', node_name=node_name, pod_name=pod_name, region=region, entries=[], error=error)  # Pass the error

    if request.method == "POST":
        # Get the user input from the form
        name = request.form['name']
        message = request.form['message']
        
        # Generate a UUID
        guest_id = str(uuid.uuid4())
        
        # Write to DynamoDB
        try:
            response = table.put_item(
                Item={
                    'GuestID': guest_id,
                    'Name': name,
                    'Message': message
                }
            )
        except Exception as e:
            error = f"Error writing to DynamoDB: {e}"
            log.error(error)

        # Redirect to GET method to show updated guestbook
        return redirect(url_for('hello'))
    
    # Retrieve all guestbook entries from DynamoDB
    try:
        response = table.scan()
        entries = response.get('Items', [])
    except Exception as e:
        error = f"Error reading from DynamoDB: {e}"
        log.error(error)
        entries = []
    
    # Render the form with current guestbook entries
    return render_template('guestbook.html', node_name=node_name, pod_name=pod_name, region=region, entries=entries, error=error)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
