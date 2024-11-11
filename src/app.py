from flask import Flask, request, render_template_string, redirect, url_for
import os
import uuid
import boto3
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)
app = Flask(__name__)

# Initialize DynamoDB client
region = os.getenv("AWS_REGION", "us-east-1")
log.info(f"Using region: {region}")
dynamodb = boto3.resource('dynamodb', region_name=region)
try:
    table = dynamodb.Table('guestbook')
except Exception as e:
    log.error(f"Error initializing DynamoDB table: {e}")

# Function to get the node name from the environment variable
def get_node_name():
    return os.getenv("NODE_NAME", "Unavailable")

# HTML template for user input and displaying the guestbook
form_template = '''
<!DOCTYPE html>
<html>
    <head>
        <title>Guestbook Entry</title>
    </head>
    <body>
        <h1>Hello, World! <br>Running on node: {{ node_name }}</h1>
        <h2>Enter your details</h2>
        <form action="/" method="post">
            Name: <input type="text" name="name" required><br>
            Message: <textarea name="message" required></textarea><br>
            <input type="submit" value="Submit">
        </form>
        
        <h2>Current Guestbook Entries:</h2>
        {% if entries %}
            <ul>
                {% for entry in entries %}
                    <li><strong>{{ entry['Name'] }}</strong>: {{ entry['Message'] }} (UUID: {{ entry['GuestID'] }})</li>
                {% endfor %}
            </ul>
        {% else %}
            <p>No entries yet.</p>
        {% endif %}
    </body>
</html>
'''

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
    return render_template_string(form_template, node_name=node_name, entries=entries)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
