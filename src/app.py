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
    return os.getenv("NODE_NAME", "Unknown node")


# Get host name if defined
def get_host_name():
    # Check for Kubernetes/pod environment
    _pod_name = os.getenv("KUBERNETES_POD_NAME") or os.getenv("HOSTNAME")
    if _pod_name:
        return f"pod:{_pod_name}"
    
    # Check for Lambda environment
    _lambda_name = os.getenv("AWS_LAMBDA_FUNCTION_NAME")
    if _lambda_name:
        return f"lambda:{_lambda_name}"
    
    return "unknown host"

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

PV_MOUNT_PATH = "/app/data"
ID_FILE = "guestbook_ids"
LAMBDA_DIR = "/tmp"

def get_id_file_path() -> str:

    is_lambda = 'AWS_LAMBDA_FUNCTION_NAME' in os.environ

    if is_lambda:
        return_path = LAMBDA_DIR
        log.info(f"Running on Lambda, adjusting mount path: {return_path}")
        return return_path
    else:
        return PV_MOUNT_PATH


def append_to_ids_file(mount_path: str, content: str) -> bool:
    """
    Checks if the mount_path exists.
    - If it does, appends 'content' to a file named 'ids' inside the mount, creating it if necessary, and returns True.
    - If the mount does not exist, returns False.

    Args:
        mount_path (str): The path to check for existence.
        content (str): The string to append to the file.

    Returns:
        bool: True if the file was written, False if the mount path does not exist.
    """
    if not os.path.exists(mount_path):
        log.info(f"Path does not exist: {mount_path}")
        return False  # Path does not exist

    ids_file_path = os.path.join(mount_path, ID_FILE)

    try:
        with open(ids_file_path, "a") as f:
            f.write(content + "\n")
        return True  # Successfully written
    except Exception as e:
        log.error(f"Error writing to file {ids_file_path}: {e}")
        return False  # In case of an unexpected error

def read_last_id(mount_path: str) -> tuple [str, str]:
    """
    Reads the last line from the 'ids' file inside the mount path if it exists.
    
    - If the file exists, returns (last_line, None).
    - If the file or mount path does not exist, returns (None, error_msg)

    Args:
        mount_path (str): The path where the 'ids' file is expected.

    Returns:
        tuple[str, str]: (last_line, error message)
    """
    error_msg = None

    ids_file_path = os.path.join(mount_path, ID_FILE)

    if not os.path.exists(ids_file_path):
        return None, f"file [{ids_file_path}] does not exist" # File does not exist

    try:
        with open(ids_file_path, "r") as f:
            lines = f.readlines()
            if lines:
                return lines[-1].strip(), None  # Return last line without trailing newline
            return None, "File [{ids_file_path}] exists but is empty"  # File exists but is empty
    except Exception as e:
        error_msg = f"Error reading file {ids_file_path}: {e}"
        log.error(error_msg)
        return None, error_msg  # In case of any unexpected error



table, _ = initialize_dynamodb()

@app.route("/", methods=["GET", "POST"])
def hello():
    error = None
    pv_action = None

    # Get the node and pod name for display
    node_name = get_node_name()
    host_name = get_host_name()

    # If table did not properly initialize, then try again
    global table
    if not table:
        table, error = initialize_dynamodb()
        if not table:
            return render_template('guestbook.html', node_name=node_name, host_name=host_name, region=region, entries=[], error=error)  # Pass the error

    id_file_path = get_id_file_path()

    if request.method == "POST":
        # Get the user input from the form
        name = request.form['name']
        message = request.form['message']
        
        # Generate a UUID
        guest_id = str(uuid.uuid4())


        # write ID to PV
        if append_to_ids_file(id_file_path, guest_id):
            pv_action = f"Successfully wrote ID [{guest_id}] to PersistentVolume [{id_file_path}]"
            log.info(pv_action)
        else:
            pv_action = f"Could not write to PersistentVolume [{id_file_path}]"
            log.info(pv_action)


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
    
    # Retrieve last ID from PersistentVolume
    last_id, error = read_last_id(id_file_path)
    if last_id:
        pv_action = f"Last ID [{last_id}] read from PersistentVolume [{id_file_path}]"
        log.info(pv_action)
    else:
        pv_action = f"Could not read from PersistentVolume [{id_file_path}] - Reason: {error}"
        log.info(pv_action)


    # Retrieve all guestbook entries from DynamoDB
    try:
        response = table.scan()
        entries = response.get('Items', [])
    except Exception as e:
        error = f"Error reading from DynamoDB: {e}"
        log.error(error)
        entries = []
    
    # Render the form with current guestbook entries
    return render_template('guestbook.html', node_name=node_name, host_name=host_name, region=region, entries=entries, pv_action=pv_action, error=error)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
