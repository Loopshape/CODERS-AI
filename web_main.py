from flask import Flask, request, send_from_directory
import subprocess

app = Flask(__name__)

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/run')
def run_query():
    query = request.args.get('query', '')
    if not query:
        return ''
    # Run your AI CLI script
    result = subprocess.run(['./ai.sh', query], capture_output=True, text=True)
    return result.stdout

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
