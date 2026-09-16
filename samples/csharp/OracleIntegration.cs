using System;
using System.Data;
using System.Text;
using System.Security.Cryptography;

namespace OracleDataSecurity.Samples.CSharp
{
    /// <summary>
    /// Demonstrates application-level encryption with Oracle database integration.
    ///
    /// This class shows how to encrypt data before inserting into Oracle and
    /// decrypt data after retrieving from Oracle using the Oracle Data Provider
    /// for .NET (ODP.NET).
    ///
    /// Usage:
    ///   dotnet add package Oracle.ManagedDataAccess
    ///   dotnet add package System.Security.Cryptography
    /// </summary>
    public class OracleIntegration
    {
        private const int GcmIvLength = 12;
        private const int GcmTagLength = 128;

        private readonly byte[] _key;
        private readonly RandomNumberGenerator _rng;

        // Database connection settings (use environment variables or config in production)
        private readonly string _dsn;
        private readonly string _user;
        private readonly string _password;

        /// <summary>
        /// Creates an OracleIntegration instance with a generated key.
        /// </summary>
        public OracleIntegration()
        {
            _key = new byte[32]; // 256-bit key
            _rng = RandomNumberGenerator.Create();
            _rng.GetBytes(_key);

            _dsn = Environment.GetEnvironmentVariable("ORACLE_DSN") ?? "localhost:1521/orcl";
            _user = Environment.GetEnvironmentVariable("ORACLE_USER") ?? "app_user";
            _password = Environment.GetEnvironmentVariable("ORACLE_PASSWORD") ?? "";
        }

        /// <summary>
        /// Creates an OracleIntegration instance with the provided key and credentials.
        /// </summary>
        public OracleIntegration(string base64Key, string dsn, string user, string password)
        {
            _key = Convert.FromBase64String(base64Key);
            _rng = RandomNumberGenerator.Create();
            _dsn = dsn;
            _user = user;
            _password = password;
        }

        // ==================== Encryption Methods ====================

        /// <summary>
        /// Encrypts plaintext using AES-CBC with PKCS7 padding.
        /// </summary>
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
        /// Decrypts ciphertext using AES-CBC with PKCS7 padding.
        /// </summary>
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

        // ==================== Database Integration Methods ====================

        /// <summary>
        /// Encrypts data and inserts/updates it in the Oracle database.
        /// </summary>
        /// <param name="tableName">Target table name</param>
        /// <param name="columnName">Target column name</param>
        /// <param name="rowId">Row identifier for WHERE clause</param>
        /// <param name="plaintext">Data to encrypt and store</param>
        /// <returns>True if a row was inserted or updated</returns>
        public bool EncryptAndStore(string tableName, string columnName,
                                     string rowId, string plaintext)
        {
            string encrypted = Encrypt(plaintext);
            string sql = $"MERGE INTO {tableName} t " +
                         $"USING DUAL ON (id = :rowId) " +
                         $"WHEN MATCHED THEN UPDATE SET {columnName} = :encrypted " +
                         $"WHEN NOT MATCHED THEN INSERT (id, {columnName}) VALUES (:rowId, :encrypted)";

            try
            {
                using var connection = GetOracleConnection();
                connection.Open();

                using var command = new OracleCommand(sql, connection);
                command.Parameters.Add(":rowId", OracleDbType.Varchar2).Value = rowId;
                command.Parameters.Add(":encrypted", OracleDbType.Varchar2).Value = encrypted;

                return command.ExecuteNonQuery() > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Database operation failed: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Fetches encrypted data from Oracle and decrypts it.
        /// </summary>
        /// <param name="tableName">Source table name</param>
        /// <param name="columnName">Source column name</param>
        /// <param name="rowId">Row identifier</param>
        /// <returns>The decrypted plaintext string</returns>
        public string FetchAndDecrypt(string tableName, string columnName, string rowId)
        {
            string sql = $"SELECT {columnName} FROM {tableName} WHERE id = :rowId";

            try
            {
                using var connection = GetOracleConnection();
                connection.Open();

                using var command = new OracleCommand(sql, connection);
                command.Parameters.Add(":rowId", OracleDbType.Varchar2).Value = rowId;

                var result = command.ExecuteScalar();
                if (result != null && result != DBNull.Value)
                {
                    string encrypted = result.ToString();
                    return Decrypt(encrypted);
                }
                throw new InvalidOperationException($"No record found for row_id: {rowId}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Database fetch failed: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Gets an Oracle database connection.
        /// </summary>
        private OracleConnection GetOracleConnection()
        {
            string connectionString = $"User Id={_user};Password={_password};Data Source={_dsn}";
            return new OracleConnection(connectionString);
        }

        /// <summary>
        /// Returns the base64-encoded secret key.
        /// </summary>
        public string GetKey()
        {
            return Convert.ToBase64String(_key);
        }

        /// <summary>
        /// Demonstrates Oracle database encryption integration.
        /// </summary>
        public static void Main()
        {
            Console.WriteLine(new string('=', 60));
            Console.WriteLine("Oracle Database Encryption Integration Demo");
            Console.WriteLine(new string('=', 60));

            try
            {
                // Create encryption manager
                var manager = new OracleIntegration();

                // Example: encrypt data before storing
                string sensitiveData = "Customer SSN: 123-45-6789";
                string encrypted = manager.Encrypt(sensitiveData);
                Console.WriteLine($"\nOriginal:  {sensitiveData}");
                Console.WriteLine($"Encrypted: {encrypted}");

                // Example: decrypt data after retrieving
                string decrypted = manager.Decrypt(encrypted);
                Console.WriteLine($"Decrypted: {decrypted}");

                Console.WriteLine($"\nKey: {manager.GetKey()}");

                Console.WriteLine($"\n{new string('=', 60)}");
                Console.WriteLine("To connect to Oracle database:");
                Console.WriteLine("  1. Add ODP.NET package: dotnet add package Oracle.ManagedDataAccess");
                Console.WriteLine("  2. Set ORACLE_DSN, ORACLE_USER, ORACLE_PASSWORD env vars");
                Console.WriteLine("  3. Call EncryptAndStore() and FetchAndDecrypt()");
                Console.WriteLine(new string('=', 60));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}
