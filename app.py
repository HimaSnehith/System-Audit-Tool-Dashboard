# app.py
import os
import json
import subprocess
import platform
import uuid
from datetime import datetime
from flask import Flask, request, jsonify, send_file, Response, render_template, current_app
from flask_cors import CORS
from fpdf import FPDF
import logging

BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# --- App Initialization ---
app = Flask(
    __name__,
    template_folder=os.path.join(BASE_DIR, "frontend", "templates"),
    static_folder=os.path.join(BASE_DIR, "frontend", "static")
)

# Load configuration
try:
    app.config.from_object('config.Config')
except ImportError:
    print("❌ config.py not found. Exiting.")
    exit(1)

CORS(app)

# --- Import Helpers ---
from utils import load_scripts, save_scripts, allowed_file, generate_pdf_report

# Register admin blueprint
from admin.routes import admin_bp
app.register_blueprint(admin_bp)

# --- Directory Setup ---
os.makedirs(app.config['REPORTS_DIR'], exist_ok=True)
os.makedirs(app.config['SCRIPTS_DIR'], exist_ok=True)

# --- Logging ---
logging.basicConfig(
    level=logging.ERROR,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filename=app.config['LOG_FILE'],
    filemode='a'
)

# --- Security Headers ---
@app.after_request
def add_security_headers(response):
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    return response

# --- Routes ---
@app.route("/")
def home():
    return render_template("index.html")

@app.route("/detect_os", methods=["GET"])
def detect_os():
    detected_os = platform.system().lower()
    if "windows" in detected_os:
        return jsonify({"os": "Windows"})
    elif "linux" in detected_os:
        return jsonify({"os": "Linux"})
    else:
        return jsonify({"error": f"Unsupported OS: {platform.system()}"}), 400

@app.route("/get_scripts")
def get_scripts():
    os_param = request.args.get("os")
    if not os_param:
        return jsonify({"error": "OS parameter is required"}), 400
    data = load_scripts()
    return jsonify({"scripts": data.get(os_param, {})})

@app.route("/stream_output", methods=["GET"])
def stream_output():
    os_name = request.args.get("os")
    scripts = request.args.getlist("scripts")
    scripts_data = load_scripts()

    def stream():
        yield "data: Starting Audit...\n\n"
        results = {}

        try:
            for script_file in scripts:
                script_path = os.path.join(current_app.config['SCRIPTS_DIR'], os_name, script_file)
                if not (os_name in scripts_data and
                        script_file in scripts_data[os_name] and
                        os.path.exists(script_path) and
                        os.path.abspath(script_path).startswith(os.path.abspath(current_app.config['SCRIPTS_DIR']))):
                    msg = f"Invalid or unauthorized script: {os_name}/{script_file}"
                    yield f"data: ❌ {msg}\n\n"
                    results[script_file] = msg
                    continue

                title = scripts_data[os_name][script_file].get('title', script_file)
                yield f"data: --- Running: {title} ({script_file}) ---\n\n"

                if os_name.lower() == "linux" and not os.access(script_path, os.X_OK):
                    os.chmod(script_path, 0o755)

                command = ["bash", script_path] if os_name.lower() == "linux" else ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path]

                process = subprocess.Popen(
                    command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    encoding='utf-8',
                    errors='replace'
                )

                script_output = []
                for line in iter(process.stdout.readline, ''):
                    line = line.strip()
                    script_output.append(line)
                    yield f"data: {line}\n\n"

                process.stdout.close()
                return_code = process.wait()

                results[script_file] = "\n".join(script_output)

                if return_code != 0:
                    yield f"data: ⚠️ Script exited with code {return_code}\n\n"

            yield "data: Generating PDF report...\n\n"
            report_path = generate_pdf_report(os_name, results)
            if report_path:
                yield f"data: Audit completed.\n\n"
                yield f"data: REPORT_PATH::{report_path}\n\n"
            else:
                yield f"data: ❌ Report generation failed.\n\n"

        except Exception as e:
            err = f"A critical error occurred: {str(e)}"
            app.logger.exception(err)
            yield f"data: ❌ {err}\n\n"

    # Wrap with app context
    def wrapped_stream():
        with app.app_context():
            yield from stream()

    return Response(wrapped_stream(), mimetype='text/event-stream')

@app.route("/download_report", methods=["GET"])
def download_report():
    path = request.args.get("path")
    if not path:
        return jsonify({"error": "Path parameter is missing"}), 400

    reports_dir = os.path.abspath(current_app.config['REPORTS_DIR'])
    safe_path = os.path.abspath(path)

    if os.path.exists(safe_path) and safe_path.startswith(reports_dir):
        return send_file(safe_path, as_attachment=True)
    else:
        current_app.logger.error(f"Unauthorized report path: {path}")
        return jsonify({"error": "Report not found or unauthorized"}), 404

# --- App Entry ---
if __name__ == '__main__':
    HOST = '127.0.0.1'
    PORT = 5000
    print("=" * 80)
    print(" AUDIT DASHBOARD IS STARTING ".center(80, "="))
    print("=" * 80)
    print(f"\n✅ Dashboard: http://{HOST}:{PORT}/")
    print(f"🔑 Admin user: {app.config['ADMIN_USERNAME']}")
    print("\n➡️  Press CTRL+C to stop")
    app.run(host=HOST, port=PORT, debug=True)