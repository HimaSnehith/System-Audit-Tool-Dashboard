import os
from werkzeug.security import generate_password_hash

# Get the absolute path of the directory where this file is located
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

class Config:
    """Base configuration class."""
    # This key is essential for session security. CHANGE IT to a long, random string!
    # You can generate one using: python -c 'import os; print(os.urandom(24))'
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'a-super-secret-key-you-should-change'

    # --- Directory Paths ---
    SCRIPTS_DIR = os.path.join(BASE_DIR, "audit_scripts")
    REPORTS_DIR = os.path.join(BASE_DIR, "reports")

    # --- Scripting ---
    ALLOWED_EXTENSIONS = {'.sh', '.ps1'}

    # --- Admin Credentials ---
    # Store a securely hashed password, not the password itself.
    # To generate a new hash for a new password (e.g., 'newpassword123'), run:
    # python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('newpassword123'))"
    ADMIN_USERNAME = "admin"
    ADMIN_PASSWORD_HASH = os.environ.get('ADMIN_PASSWORD_HASH') or 'pbkdf2:sha256:600000$cT8xZ9b5gQj3nL4a$452a32a63116a152344795b68e1837b25201402c4974f260395c3a37b31d2a45' # Default password is 'admin'

    # --- Logging ---
    LOG_FILE = 'audit.log'