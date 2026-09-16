"""
Basic encryption and decryption using the cryptography library.

This module demonstrates Fernet symmetric encryption, which provides
a simple and secure way to encrypt sensitive data before storing it.
"""

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64
import os


class BasicEncryption:
    """Provides basic symmetric encryption and decryption using Fernet."""

    def __init__(self, key: bytes = None):
        """
        Initialize encryption with a provided key or generate a new one.

        Args:
            key: Optional 32-byte key. If None, a new key is generated.
        """
        if key is None:
            self.key = Fernet.generate_key()
        else:
            self.key = key
        self.cipher = Fernet(self.key)

    def encrypt(self, plaintext: str) -> str:
        """
        Encrypt a string using Fernet symmetric encryption.

        Args:
            plaintext: The string to encrypt.

        Returns:
            Base64-encoded encrypted string.

        Example:
            >>> encryptor = BasicEncryption()
            >>> encrypted = encryptor.encrypt("Sensitive data")
            >>> print(encrypted)
            b'gAAAA...'
        """
        plaintext_bytes = plaintext.encode("utf-8")
        encrypted_bytes = self.cipher.encrypt(plaintext_bytes)
        return base64.urlsafe_b64encode(encrypted_bytes).decode("utf-8")

    def decrypt(self, ciphertext: str) -> str:
        """
        Decrypt a Fernet-encrypted string.

        Args:
            ciphertext: The base64-encoded encrypted string.

        Returns:
            The decrypted plaintext string.

        Example:
            >>> decryptor = BasicEncryption(key=encryptor.key)
            >>> plaintext = decryptor.decrypt(encrypted)
            >>> print(plaintext)
            'Sensitive data'
        """
        ciphertext_bytes = base64.urlsafe_b64decode(ciphertext.encode("utf-8"))
        decrypted_bytes = self.cipher.decrypt(ciphertext_bytes)
        return decrypted_bytes.decode("utf-8")

    def generate_key(self) -> str:
        """
        Generate a new encryption key.

        Returns:
            Base64-encoded encryption key.

        Note:
            Store this key securely! Never hardcode keys in production.
        """
        new_key = Fernet.generate_key()
        return base64.urlsafe_b64encode(new_key).decode("utf-8")

    @staticmethod
    def derive_key(password: str, salt: bytes = None) -> tuple:
        """
        Derive an encryption key from a password using PBKDF2.

        Args:
            password: The password to derive the key from.
            salt: Optional salt. If None, a new salt is generated.

        Returns:
            Tuple of (derived_key, salt).

        Note:
            Store the salt alongside the encrypted data; it is not secret.
        """
        if salt is None:
            salt = os.urandom(16)

        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=480000,
        )
        key = kdf.derive(password.encode("utf-8"))
        return base64.urlsafe_b64encode(key).decode("utf-8"), salt


def main():
    """Demonstrate basic encryption and decryption."""
    print("=" * 60)
    print("Basic Encryption Demo")
    print("=" * 60)

    # Create encryption instance
    encryptor = BasicEncryption()

    # Encrypt data
    plaintext = "Sensitive customer data: SSN=123-45-6789"
    encrypted = encryptor.encrypt(plaintext)
    print(f"\nOriginal:  {plaintext}")
    print(f"Encrypted: {encrypted}")

    # Decrypt data
    decryptor = BasicEncryption(key=encryptor.key)
    decrypted = decryptor.decrypt(encrypted)
    print(f"Decrypted: {decrypted}")

    # Derive key from password
    password = "my_secure_password"
    derived_key, salt = BasicEncryption.derive_key(password)
    print(f"\nDerived key from password: {derived_key[:32]}...")
    print(f"Salt (store with data):    {salt.hex()}")


if __name__ == "__main__":
    main()
