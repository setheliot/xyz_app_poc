from flask import Flask, request, Response
import requests, json, base64, os

LAMBDA_PORT = int(os.getenv("LAMBDA_PORT", "9000"))
LAMBDA_INVOKE = f"http://127.0.0.1:{LAMBDA_PORT}/2015-03-31/functions/function/invocations"
app = Flask(__name__)

def to_apigw_v1(req):
    body_bytes = request.get_data() or b""
    ctype = request.headers.get("Content-Type", "")
    is_text = ctype.startswith(("text/", "application/json", "application/x-www-form-urlencoded"))
    body_str = body_bytes.decode("utf-8", errors="ignore") if is_text else base64.b64encode(body_bytes).decode("utf-8")
    return {
        "httpMethod": req.method,
        "path": (req.full_path.split("?")[0] or "/"),
        "headers": {k: v for k, v in req.headers.items()},
        "queryStringParameters": dict(req.args) or None,
        "pathParameters": None,
        "stageVariables": None,
        "body": (body_str if body_bytes else None),
        "isBase64Encoded": (not is_text and bool(body_bytes)),
        "requestContext": {"stage": "prod"},
    }

@app.route("/", defaults={"path": ""}, methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS","HEAD"])
@app.route("/<path:path>", methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS","HEAD"])
def proxy(path):
    event = to_apigw_v1(request)
    r = requests.post(LAMBDA_INVOKE, json=event, timeout=60)
    r.raise_for_status()
    lam = r.json()
    body = lam.get("body") or ""
    if lam.get("isBase64Encoded"):
        body = base64.b64decode(body)
    status = int(lam.get("statusCode", 200))
    headers = lam.get("headers") or {}
    for h in ["Content-Length","Transfer-Encoding","Connection"]:
        headers.pop(h, None)
    return Response(body, status=status, headers=headers)

if __name__ == "__main__":
    app.run("127.0.0.1", int(os.getenv("PROXY_PORT","3000")), debug=False)
