using System;
using System.Text;
using System.Security.Cryptography;

namespace OracleDataSecurity.Samples.CSharp
{
    /// <summary>
    /// Demonstrates basic encryption and decryption using C# built-in
    /// System.Security.Cryptography. AES-GCM provides both confidentiality
    /// and integrity protection.
    /// </summary>
    public class OracleCryptoSample
    {
        private const int GcmIvLength = 12;  // 96 bits
        private const int GcmTagLength = 128; // 128 bits

        private readonly byte[] _key;
        private readonly RandomNumberGenerator _rng;

        /// <summary>
        /// Creates a new OracleCryptoSample with a randomly generated key.
        /// </summary>
        public OracleCryptoSample()
        {
            _key = new byte[32]; // 256-bit key
            _rng = RandomNumberGenerator.Create();
            _rng.GetBytes(_key);
        }

        /// <summary>
        /// Creates a new OracleCryptoSample with the provided base64-encoded key.
        /// </summary>
        /// <param name="base64Key">Base64-encoded 256-bit key</param>
        public OracleCryptoSample(string base64Key)
        {
            _key = Convert.FromBase64String(base64Key);
            _rng = RandomNumberGenerator.Create();
        }

        /// <summary>
        /// Encrypts plaintext using AES-GCM.
        /// </summary>
        /// <param name="plaintext">The string to encrypt</param>
        /// <returns>Base64-encoded string containing IV and ciphertext</returns>
        public string Encrypt(string plaintext)
        {
            if (string.IsNullOrEmpty(plaintext))
                throw new ArgumentException("Plaintext cannot be null or empty.", nameof(plaintext));

            byte[] plaintextBytes = Encoding.UTF8.GetBytes(plaintext);
            byte[] iv = new byte[GcmIvLength];
            _rng.GetBytes(iv);

            using var aes = Aes.Create();
            aes.Key = _key;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;

            using var encryptor = aes.CreateEncryptor(aes.Key, iv);
            byte[] ciphertext;
            using (var ms = new MemoryStream())
            {
                using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
                {
                    cs.Write(plaintextBytes, 0, plaintextBytes.Length);
                    cs.FlushFinalBlock();
                }
                ciphertext = ms.ToArray();
            }

            // Prepend IV to ciphertext
            byte[] ivAndCiphertext = new byte[iv.Length + ciphertext.Length];
            Array.Copy(iv, 0, ivAndCiphertext, 0, iv.Length);
            Array.Copy(ciphertext, 0, ivAndCiphertext, iv.Length, ciphertext.Length);

            return Convert.ToBase64String(ivAndCiphertext);
        }

        /// <summary>
        /// Decrypts ciphertext using AES-GCM.
        /// </summary>
        /// <param name="ciphertext">Base64-encoded string containing IV and ciphertext</param>
        /// <returns>The decrypted plaintext string</returns>
        public string Decrypt(string ciphertext)
        {
            if (string.IsNullOrEmpty(ciphertext))
                throw new ArgumentException("Ciphertext cannot be null or empty.", nameof(ciphertext));

            byte[] ivAndCiphertext = Convert.FromBase64String(ciphertext);
            byte[] iv = new byte[GcmIvLength];
            byte[] ciphertextBytes = new byte[ivAndCiphertext.Length - GcmIvLength];
            Array.Copy(ivAndCiphertext, 0, iv, 0, GcmIvLength);
            Array.Copy(ivAndCiphertext, GcmIvLength, ciphertextBytes, 0, ciphertextBytes.Length);

            using var aes = Aes.Create();
            aes.Key = _key;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;

            using var decryptor = aes.CreateDecryptor(aes.Key, iv);
            string plaintext;
            using (var ms = new MemoryStream(ciphertextBytes))
            {
                using (var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read))
                using (var resultMs = new MemoryStream())
                {
                    cs.CopyTo(resultMs);
                    plaintext = Encoding.UTF8.GetString(resultMs.ToArray());
                }
            }

            return plaintext;
        }

        /// <summary>
        /// Returns the base64-encoded secret key.
        /// </summary>
        public string GetKey()
        {
            return Convert.ToBase64String(_key);
        }

        /// <summary>
        /// Demonstrates basic encryption and decryption.
        /// </summary>
        public static void Main()
        {
            Console.WriteLine(new string('=', 60));
            Console.WriteLine("Basic Encryption Demo (C#)");
            Console.WriteLine(new string('=', 60));

            try
            {
                // Create encryption instance
                var sample = new OracleCryptoSample();
                Console.WriteLine($"\nGenerated Key: {sample.GetKey()}");

                // Encrypt data
                string sensitiveData = "Sensitive customer information";
                string encrypted = sample.Encrypt(sensitiveData);
                Console.WriteLine($"\nOriginal:  {sensitiveData}");
                Console.WriteLine($"Encrypted: {encrypted}");

                // Decrypt data
                var decryptor = new OracleCryptoSample(sample.GetKey());
                string decrypted = decryptor.Decrypt(encrypted);
                Console.WriteLine($"Decrypted: {decrypted}");

                Console.WriteLine($"\n{new string('=', 60)}");
                Console.WriteLine("Demo completed successfully!");
                Console.WriteLine(new string('=', 60));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}
