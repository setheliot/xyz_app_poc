from flask import Flask
import os

app = Flask(__name__)

# Function to get the availability zone from the environment variable
# This must have been previously defined in the K8s deployment
def get_node_name():
    return os.getenv("NODE_NAME", "Unavailable")

@app.route("/")
def hello():
    node_name = get_node_name()
    return f"Hello, World! <br/>Running on node: {node_name}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
#    app.run(host="0.0.0.0", port=5000) #for local testing