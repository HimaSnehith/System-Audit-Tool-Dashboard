# utils.py
import os
import json
from flask import current_app
from werkzeug.utils import secure_filename
import uuid
from datetime import datetime
from fpdf import FPDF
import logging

def load_scripts():
    """Loads script metadata from scripts.json."""
    try:
        with open(os.path.join(current_app.config['SCRIPTS_DIR'], "scripts.json"), "r") as f:
            return json.load(f)
    except FileNotFoundError:
        current_app.logger.warning("scripts.json not found. Creating an empty one.")
        save_scripts({}) # Create an empty file
        return {}
    except json.JSONDecodeError:
        current_app.logger.error("Error decoding scripts.json. Please ensure it's valid JSON.")
        return {}
    except Exception:
        current_app.logger.exception("Failed to load scripts.json")
        return {}

def save_scripts(data):
    """Saves script metadata to scripts.json."""
    try:
        with open(os.path.join(current_app.config['SCRIPTS_DIR'], "scripts.json"), "w") as f:
            json.dump(data, f, indent=4)
    except Exception:
        current_app.logger.exception("Failed to save scripts.json")

def allowed_file(filename):
    """Checks if the file extension is allowed for upload."""
    _, ext = os.path.splitext(filename)
    return ext.lower() in current_app.config['ALLOWED_EXTENSIONS']

def generate_pdf_report(os_name, scripts_output):
    """Generates a PDF report from the audit results."""
    report_id = str(uuid.uuid4())
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    report_path = os.path.join(current_app.config['REPORTS_DIR'], f"audit_report_{report_id}.pdf")

    try:
        pdf = FPDF()
        pdf.set_auto_page_break(auto=True, margin=15)
        pdf.add_page()
        pdf.set_font("Arial", size=12)

        pdf.cell(0, 10, txt="System Audit Report", ln=True, align="C")
        pdf.cell(0, 10, txt=f"OS: {os_name}", ln=True)
        pdf.cell(0, 10, txt=f"Generated on: {timestamp}", ln=True)
        pdf.ln(10)

        for title, output in scripts_output.items():
            pdf.set_font("Arial", "B", 12)
            pdf.cell(0, 10, txt=title, ln=True)
            pdf.set_font("Arial", size=10)
            # Encode output to handle potential special characters in script results
            for line in str(output).splitlines():
                safe_line = line.strip().encode('latin-1', 'replace').decode('latin-1')
                pdf.multi_cell(0, 8, txt=safe_line)
            pdf.ln(5)

        pdf.output(report_path)
        return report_path
    except Exception:
        current_app.logger.exception("Error generating PDF report")
        return None