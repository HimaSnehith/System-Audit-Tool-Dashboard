# admin/routes.py
from flask import Blueprint, render_template, request, redirect, url_for, current_app, jsonify, session
import os
from werkzeug.utils import secure_filename
from werkzeug.security import check_password_hash, generate_password_hash

# Import helper functions from utils
from utils import load_scripts, save_scripts, allowed_file

admin_bp = Blueprint('admin', __name__, url_prefix='/admin')

# Simple authentication check (for demonstration)
def is_admin_authenticated():
    # In a real app, check session or token
    # For this example, we'll check if 'admin_logged_in' is in the session
    return 'admin_logged_in' in session

@admin_bp.before_request
def require_admin():
    if request.endpoint != 'admin.login' and not is_admin_authenticated():
        return redirect(url_for('admin.login'))

@admin_bp.route("/login", methods=["GET", "POST"])
def login():
    """Admin login route."""
    error = None
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")
        if username == current_app.config['ADMIN_USERNAME'] and check_password_hash(current_app.config['ADMIN_PASSWORD_HASH'], password):
            # In a real app, set a secure session cookie
            session['admin_logged_in'] = True
            return redirect(url_for("admin.dashboard"))
        else:
            error = "Invalid credentials"
    return render_template("admin/login.html", error=error)

@admin_bp.route("/logout")
def logout():
    session.pop('admin_logged_in', None)
    return redirect(url_for('admin.login'))

@admin_bp.route("/dashboard")
def dashboard():
    """Admin dashboard to manage scripts."""
    scripts = load_scripts()
    return render_template("admin/dashboard.html", scripts=scripts)

@admin_bp.route("/upload_script", methods=["POST"])
def upload_script():
    """Uploads a new script."""
    if 'os' not in request.form or 'script_file' not in request.files:
        return jsonify({"error": "Missing OS or script file"}), 400

    os_name = request.form['os']
    script_file = request.files['script_file']
    description = request.form.get('description', '')
    title = request.form.get('title', '')

    if script_file.filename == '':
        return jsonify({"error": "No file selected"}), 400

    if script_file and allowed_file(script_file.filename):
        filename = secure_filename(script_file.filename)
        os.makedirs(os.path.join(current_app.config['SCRIPTS_DIR'], os_name), exist_ok=True)
        script_path = os.path.join(current_app.config['SCRIPTS_DIR'], os_name, filename)
        script_file.save(script_path)

        scripts_data = load_scripts()
        if os_name not in scripts_data:
            scripts_data[os_name] = {}
        scripts_data[os_name][filename] = {"description": description, "filename": filename, "title": title}
        save_scripts(scripts_data)

        return redirect(url_for("admin.dashboard"))
    else:
        return jsonify({"error": "Invalid file type"}), 400

@admin_bp.route("/delete_script/<os_name>/<filename>")
def delete_script(os_name, filename):
    """Deletes a script."""
    safe_filename = secure_filename(filename)
    script_path = os.path.join(current_app.config['SCRIPTS_DIR'], os_name, safe_filename)

    if os.path.exists(script_path) and os.path.abspath(script_path).startswith(os.path.abspath(os.path.join(current_app.config['SCRIPTS_DIR'], os_name))):
        try:
            os.remove(script_path)
            scripts_data = load_scripts()
            if os_name in scripts_data and safe_filename in scripts_data[os_name]:
                del scripts_data[os_name][safe_filename]
                save_scripts(scripts_data)
            return redirect(url_for("admin.dashboard"))
        except Exception as e:
            current_app.logger.error(f"Error deleting script {script_path}: {e}")
            return jsonify({"error": f"Failed to delete script: {str(e)}"}), 500
    else:
        current_app.logger.error(f"Attempted to delete unauthorized or non-existent script: {script_path}")
        return jsonify({"error": "Script not found or unauthorized access"}), 404

@admin_bp.route("/edit_script/<os_name>/<filename>", methods=['GET', 'POST'])
def edit_script(os_name, filename):
    """Edits a script's metadata (description, title)."""
    scripts_data = load_scripts()
    safe_filename = secure_filename(filename)

    if os_name not in scripts_data or safe_filename not in scripts_data[os_name]:
        return jsonify({"error": "Script not found"}), 404

    script_info = scripts_data[os_name][safe_filename]

    if request.method == 'POST':
        new_description = request.form.get('description', '')
        new_title = request.form.get('title', '')
        scripts_data[os_name][safe_filename]['description'] = new_description
        scripts_data[os_name][safe_filename]['title'] = new_title
        save_scripts(scripts_data)
        return redirect(url_for('admin.dashboard'))
    return render_template('admin/edit_script.html', os_name=os_name, filename=safe_filename, script_info=script_info)

# Example route to change admin password (for development/initial setup)
# **Remove or secure this in a production environment!**
@admin_bp.route("/change_password", methods=['GET', 'POST'])
def change_password():
    error = None
    if request.method == 'POST':
        new_password = request.form.get('new_password')
        confirm_password = request.form.get('confirm_password')
        if new_password == confirm_password:
            hashed_password = generate_password_hash(new_password)
            current_app.config['ADMIN_PASSWORD_HASH'] = hashed_password
            # In a real app, you would save this to your config file or database
            # For this example, it's in memory and will reset on app restart
            return redirect(url_for('admin.dashboard'))
        else:
            error = "Passwords do not match"
    return render_template('admin/change_password.html', error=error)