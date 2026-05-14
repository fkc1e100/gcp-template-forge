import json
import time
from flask import Flask, Response

app = Flask(__name__)

def generate_progress():
    while True:
        try:
            with open("progress.json", "r") as f:
                data = json.load(f)
            yield f"data: {json.dumps(data)}\n\n"
        except FileNotFoundError:
            yield f"data: {json.dumps({'status': 'waiting for progress.json'})}\n\n"
        except json.JSONDecodeError:
            yield f"data: {json.dumps({'status': 'error decoding progress.json'})}\n\n"
        time.sleep(1)

@app.route('/api/progress')
def progress():
    return Response(generate_progress(), mimetype="text/event-stream")

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
