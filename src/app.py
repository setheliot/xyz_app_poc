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

# Function to get the AWS Region from the environment variable
def get_region():
    return os.getenv("AWS_REGION", "us-east-1")

# Initialize DynamoDB client
region = get_region()
log.info(f"Using region: {region}")
dynamodb = boto3.resource('dynamodb', region_name=region)
try:
    table = dynamodb.Table(os.getenv("DDB_TABLE", "guestbook"))
except Exception as e:
    log.error(f"Error initializing DynamoDB table: {e}")


@app.route("/", methods=["GET", "POST"])
def hello():
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
            log.error(f"Error writing to DynamoDB: {e}")
        
        # Redirect to GET method to show updated guestbook
        return redirect(url_for('hello'))
    
    # Get the node name for display
    node_name = get_node_name()
    
    # Retrieve all guestbook entries from DynamoDB
    try:
        response = table.scan()
        entries = response.get('Items', [])
    except Exception as e:
        log.error(f"Error reading from DynamoDB: {e}")
        entries = []
    
    # Render the form with current guestbook entries
    return render_template('guestbook.html', node_name=node_name, region=region, entries=entries)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
