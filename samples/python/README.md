# Oracle Data Security - Python Encryption Samples

Application-level encryption samples demonstrating Fernet symmetric encryption with optional Oracle database integration.

## Prerequisites

- **Python 3.7+**
- **pip** (package manager)
- **Oracle Database** (optional, for DB integration demo)

## Installation

```bash
# Install dependencies
cd samples/python
pip install -r requirements.txt
```

This installs the `cryptography` library for Fernet encryption.

## Run

### Basic Encryption Demo (no database required)

```bash
# Run the encryption demo
python encryption.py
```

This demonstrates Fernet symmetric encryption/decryption with key derivation from passwords.

### Oracle DB Integration Demo (requires database)

```bash
# Run the Oracle integration demo
python oracle_integration.py
```

This demonstrates encryption/decryption with Oracle database operations (encrypt-and-store, fetch-and-decrypt).

### Available Options

| Option | Description | Example |
|--------|-------------|---------|
| `ORACLE_DSN` | Oracle connection string | `localhost:1521/orcl` |
| `ORACLE_USER` | Oracle username | `app_user` |
| `ORACLE_PASSWORD` | Oracle password | `secret` |
| `ENCRYPTION_KEY` | Base64-encoded encryption key | (optional, auto-generated if not set) |

## Project Structure

```
samples/python/
├── requirements.txt                  # Python dependencies (cryptography)
├── encryption.py                     # Fernet symmetric encryption/decryption
└── oracle_integration.py             # Encryption + Oracle DB operations
```

## Sample Output

```
============================================================
Basic Encryption Demo
============================================================

Original:  Sensitive customer data: SSN=123-45-6789
Encrypted: gAAAAABm... (base64 encoded)
Decrypted: Sensitive customer data: SSN=123-45-6789

Derived key from password: kMx7...
Salt (store with data):    a1b2c3d4e5f6...
```

## Notes

- Encryption uses **Fernet** (AES-128-CBC with HMAC-SHA256) from the `cryptography` library
- Password-derived keys use **PBKDF2** with 480,000 iterations (FIPS compliant)
- The `OracleEncryptionManager` class uses the `oracledb` driver for database connectivity
- Salt values are stored alongside encrypted data (not secret, but required for key derivation)
