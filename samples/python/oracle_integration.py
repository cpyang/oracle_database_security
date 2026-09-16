"""
Oracle database integration example for application-level encryption.

This module demonstrates how to encrypt and decrypt data before storing
it in an Oracle database using the oracledb driver.
"""

import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


class OracleEncryptionManager:
    """Manages encryption/decryption for Oracle database operations."""

    def __init__(self, dsn: str = None, user: str = None, password: str = None):
        """
        Initialize the encryption manager with database credentials.

        Args:
            dsn: Oracle Database Service Name or TNS alias.
            user: Database username.
            password: Database password.

        Note:
            Use environment variables or a secrets manager for credentials.
        """
        self.dsn = dsn or os.getenv("ORACLE_DSN", "localhost:1521/orcl")
        self.user = user or os.getenv("ORACLE_USER", "app_user")
        self.password = password or os.getenv("ORACLE_PASSWORD", "")
        self._key = None

    def _load_or_generate_key(self) -> bytes:
        """Load encryption key from environment or generate a new one."""
        key_str = os.getenv("ENCRYPTION_KEY")
        if key_str:
            return base64.urlsafe_b64decode(key_str.encode("utf-8"))
        return Fernet.generate_key()

    @property
    def cipher(self) -> Fernet:
        """Get or create the Fernet cipher instance."""
        if self._key is None:
            self._key = self._load_or_generate_key()
        return Fernet(self._key)

    def encrypt(self, plaintext: str) -> str:
        """
        Encrypt a string for storage in the database.

        Args:
            plaintext: The string to encrypt.

        Returns:
            Base64-encoded encrypted string safe for database storage.
        """
        encrypted_bytes = self.cipher.encrypt(plaintext.encode("utf-8"))
        return base64.urlsafe_b64encode(encrypted_bytes).decode("utf-8")

    def decrypt(self, ciphertext: str) -> str:
        """
        Decrypt a string retrieved from the database.

        Args:
            ciphertext: The base64-encoded encrypted string.

        Returns:
            The decrypted plaintext string.
        """
        encrypted_bytes = base64.urlsafe_b64decode(ciphertext.encode("utf-8"))
        decrypted_bytes = self.cipher.decrypt(encrypted_bytes)
        return decrypted_bytes.decode("utf-8")

    def encrypt_and_store(self, connection, table: str, column: str,
                          row_id: str, plaintext: str) -> None:
        """
        Encrypt data and insert/update it in the database.

        Args:
            connection: Oracle database connection.
            table: Target table name.
            column: Target column name.
            row_id: Row identifier for WHERE clause.
            plaintext: Data to encrypt and store.
        """
        encrypted = self.encrypt(plaintext)

        cursor = connection.cursor()
        try:
            cursor.execute(
                f"MERGE INTO {table} t "
                f"USING DUAL ON (id = :row_id) "
                f"WHEN MATCHED THEN UPDATE SET {column} = :encrypted "
                f"WHEN NOT MATCHED THEN INSERT (id, {column}) VALUES (:row_id, :encrypted)",
                row_id=row_id,
                encrypted=encrypted
            )
            connection.commit()
        finally:
            cursor.close()

    def fetch_and_decrypt(self, connection, table: str, column: str,
                          row_id: str) -> str:
        """
        Fetch encrypted data from the database and decrypt it.

        Args:
            connection: Oracle database connection.
            table: Source table name.
            column: Source column name.
            row_id: Row identifier.

        Returns:
            The decrypted plaintext string.

        Raises:
            ValueError: If no data is found for the given row_id.
        """
        cursor = connection.cursor()
        try:
            cursor.execute(
                f"SELECT {column} FROM {table} WHERE id = :row_id",
                row_id=row_id
            )
            row = cursor.fetchone()
            if not row:
                raise ValueError(f"No record found for row_id: {row_id}")

            encrypted = row[0]
            return self.decrypt(encrypted)
        finally:
            cursor.close()


def main():
    """Demonstrate Oracle database encryption integration."""
    print("=" * 60)
    print("Oracle Database Encryption Integration Demo")
    print("=" * 60)

    # Create encryption manager
    mgr = OracleEncryptionManager()

    # Example: encrypt data before storing
    sensitive_data = "Customer SSN: 123-45-6789"
    encrypted = mgr.encrypt(sensitive_data)
    print(f"\nOriginal:  {sensitive_data}")
    print(f"Encrypted: {encrypted}")

    # Example: decrypt data after retrieving
    decrypted = mgr.decrypt(encrypted)
    print(f"Decrypted: {decrypted}")

    print("\nNote: To connect to Oracle database, use oracledb:")
    print("  import oracledb")
    print("  connection = oracledb.connect(user='user', password='pass', dsn='dsn')")


if __name__ == "__main__":
    main()
