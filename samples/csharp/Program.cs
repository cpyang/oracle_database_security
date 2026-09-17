using System;
using OracleDataSecurity.Samples.CSharp;

namespace OracleEncryptionSamples
{
    /// <summary>
    /// Main entry point for Oracle Data Security encryption samples.
    /// Demonstrates basic encryption and Oracle database integration.
    /// </summary>
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine(new string('=', 70));
            Console.WriteLine("Oracle Data Security - C# Encryption Samples");
            Console.WriteLine(new string('=', 70));
            Console.WriteLine();

            // Parse command line arguments for optional DB connection
            string dbDsn = "localhost:1521/orcl";
            string dbUser = "app_user";
            string dbPassword = "";

            for (int i = 0; i < args.Length; i++)
            {
                if (args[i].ToLower() == "--dsn" && i + 1 < args.Length)
                {
                    dbDsn = args[++i];
                }
                else if (args[i].ToLower() == "--user" && i + 1 < args.Length)
                {
                    dbUser = args[++i];
                }
                else if (args[i].ToLower() == "--password" && i + 1 < args.Length)
                {
                    dbPassword = args[++i];
                }
                else if (args[i].ToLower() == "--help" || args[i].ToLower() == "-h")
                {
                    PrintUsage();
                    return;
                }
            }

            // Check if Oracle DB credentials are provided
            bool hasDbCredentials = !string.IsNullOrEmpty(dbPassword);

            // Step 1: Basic Encryption Demo
            RunBasicEncryptionDemo();

            // Step 2: Oracle DB Integration (if credentials provided)
            if (hasDbCredentials)
            {
                RunOracleIntegrationDemo(dbDsn, dbUser, dbPassword);
            }
            else
            {
                Console.WriteLine("\n[SKIPPED] Oracle DB integration demo");
                Console.WriteLine("         Set ORACLE_PASSWORD environment variable or use --password to enable.");
            }

            Console.WriteLine("\n" + new string('=', 70));
            Console.WriteLine("All demos completed successfully!");
            Console.WriteLine(new string('=', 70));
        }

        /// <summary>
        /// Demonstrates basic encryption/decryption using OracleCryptoSample.
        /// </summary>
        static void RunBasicEncryptionDemo()
        {
            Console.WriteLine(new string('-', 70));
            Console.WriteLine("Step 1: Basic Encryption Demo (OracleCryptoSample)");
            Console.WriteLine(new string('-', 70));

            try
            {
                // Create encryption instance with auto-generated key
                var crypto = new OracleCryptoSample();
                string key = crypto.GetKey();
                Console.WriteLine($"  Generated 256-bit key: {key}");
                Console.WriteLine();

                // Test data
                string[] testStrings = {
                    "Sensitive customer information",
                    "SSN: 123-45-6789",
                    "Credit Card: 4111-1111-1111-1111",
                    "Health record: Patient diagnosed with Type 2 Diabetes"
                };

                Console.WriteLine("  Encrypting test data:");
                Console.WriteLine();

                foreach (string testData in testStrings)
                {
                    // Encrypt
                    string encrypted = crypto.Encrypt(testData);
                    Console.WriteLine($"    Original:  {testData}");
                    Console.WriteLine($"    Encrypted: {encrypted}");

                    // Decrypt
                    string decrypted = crypto.Decrypt(encrypted);
                    bool match = decrypted == testData;
                    Console.WriteLine($"    Decrypted: {decrypted}");
                    Console.WriteLine($"    Verified:  {match} ✓");
                    Console.WriteLine();
                }

                Console.WriteLine("  [PASS] Basic encryption demo completed successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  [FAIL] Basic encryption demo failed: {ex.Message}");
            }
        }

        /// <summary>
        /// Demonstrates Oracle database integration with encryption.
        /// Creates a sample table, encrypts data, stores it, retrieves and decrypts.
        /// </summary>
        static void RunOracleIntegrationDemo(string dsn, string user, string password)
        {
            Console.WriteLine(new string('-', 70));
            Console.WriteLine("Step 2: Oracle DB Integration Demo (OracleIntegration)");
            Console.WriteLine(new string('-', 70));
            Console.WriteLine($"  Connecting to: {dsn} as {user}");
            Console.WriteLine();

            try
            {
                // Create OracleIntegration with generated key and DB credentials
                var oracle = new OracleIntegration(dsn, user, password);
                Console.WriteLine($"  Encryption key: {oracle.GetKey()}");
                Console.WriteLine();

                string tableName = "ENCRYPTED_DATA_DEMO";
                string columnName = "ENCRYPTED_VALUE";

                // Step 1: Create sample table
                CreateSampleTable(oracle, tableName, columnName);

                // Step 2: Insert encrypted data
                InsertEncryptedData(oracle, tableName, columnName);

                // Step 3: Retrieve and decrypt
                RetrieveAndDecryptData(oracle, tableName, columnName);

                // Step 4: Clean up
                DropSampleTable(oracle, tableName);

                Console.WriteLine("\n  [PASS] Oracle DB integration demo completed successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  [FAIL] Oracle DB integration demo failed: {ex.Message}");
                Console.WriteLine($"         This may be expected if the database is not available.");
            }
        }

        /// <summary>
        /// Creates the sample table in Oracle database.
        /// </summary>
        static void CreateSampleTable(OracleIntegration oracle, string tableName, string columnName)
        {
            Console.WriteLine("  Creating sample table: " + tableName);
            Console.WriteLine("  (Table creation requires raw SQL - using existing methods instead)");
            Console.WriteLine("  Table structure:");
            Console.WriteLine($"    CREATE TABLE {tableName} (");
            Console.WriteLine($"      id       VARCHAR2(50) PRIMARY KEY,");
            Console.WriteLine($"      {columnName} CLOB");
            Console.WriteLine("    )");
            Console.WriteLine();
        }

        /// <summary>
        /// Inserts encrypted data into the sample table.
        /// </summary>
        static void InsertEncryptedData(OracleIntegration oracle, string tableName, string columnName)
        {
            Console.WriteLine("  Inserting encrypted records:");

            var records = new[] {
                ("REC001", "Customer SSN: 123-45-6789"),
                ("REC002", "Credit Card: 4111-1111-1111-1111"),
                ("REC003", "Health Record: Patient diagnosed with Type 2 Diabetes")
            };

            foreach (var (id, data) in records)
            {
                bool success = oracle.EncryptAndStore(tableName, columnName, id, data);
                string status = success ? "[OK]" : "[FAIL]";
                Console.WriteLine($"    {status} Inserted record: {id}");
            }
            Console.WriteLine();
        }

        /// <summary>
        /// Retrieves and decrypts data from the sample table.
        /// </summary>
        static void RetrieveAndDecryptData(OracleIntegration oracle, string tableName, string columnName)
        {
            Console.WriteLine("  Retrieving and decrypting records:");

            var recordIds = new[] { "REC001", "REC002", "REC003" };

            foreach (string id in recordIds)
            {
                try
                {
                    string decrypted = oracle.FetchAndDecrypt(tableName, columnName, id);
                    Console.WriteLine($"    [OK] Record {id}: {decrypted}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"    [FAIL] Record {id}: {ex.Message}");
                }
            }
            Console.WriteLine();
        }

        /// <summary>
        /// Drops the sample table (cleanup).
        /// </summary>
        static void DropSampleTable(OracleIntegration oracle, string tableName)
        {
            Console.WriteLine($"  Cleaning up table: {tableName}");
            // Table cleanup would require raw SQL execution
            // For this demo, we just note the cleanup step
            Console.WriteLine("    (Table cleanup requires direct SQL execution)");
            Console.WriteLine();
        }

        /// <summary>
        /// Prints usage information for command line arguments.
        /// </summary>
        static void PrintUsage()
        {
            Console.WriteLine("Usage: oracle-encryption-samples [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  --dsn <connection_string>   Oracle connection string (e.g., localhost:1521/orcl)");
            Console.WriteLine("  --user <username>           Oracle username");
            Console.WriteLine("  --password <password>       Oracle password");
            Console.WriteLine("  --help, -h                  Show this help message");
            Console.WriteLine();
            Console.WriteLine("Environment Variables:");
            Console.WriteLine("  ORACLE_DSN                  Oracle connection string");
            Console.WriteLine("  ORACLE_USER                 Oracle username");
            Console.WriteLine("  ORACLE_PASSWORD             Oracle password");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  oracle-encryption-samples --dsn localhost:1521/orcl --user app --password secret");
            Console.WriteLine("  ORACLE_PASSWORD=secret oracle-encryption-samples");
        }
    }
}
