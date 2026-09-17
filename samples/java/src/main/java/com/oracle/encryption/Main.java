package com.oracle.encryption;

/**
 * Main entry point for Oracle Data Security Java encryption samples.
 * Demonstrates basic encryption and Oracle database integration.
 */
public class Main {

    private static String repeat(String s, int count) {
        StringBuilder sb = new StringBuilder(s.length() * count);
        for (int i = 0; i < count; i++) {
            sb.append(s);
        }
        return sb.toString();
    }

    public static void main(String[] args) {
        System.out.println(repeat("=", 70));
        System.out.println("Oracle Data Security - Java Encryption Samples");
        System.out.println(repeat("=", 70));
        System.out.println();

        // Parse command line arguments for optional DB connection
        String dbDsn = "localhost:1521/orcl";
        String dbUser = "app_user";
        String dbPassword = "";

        for (int i = 0; i < args.length; i++) {
            if ("--dsn".equalsIgnoreCase(args[i]) && i + 1 < args.length) {
                dbDsn = args[++i];
            } else if ("--user".equalsIgnoreCase(args[i]) && i + 1 < args.length) {
                dbUser = args[++i];
            } else if ("--password".equalsIgnoreCase(args[i]) && i + 1 < args.length) {
                dbPassword = args[++i];
            } else if ("--help".equalsIgnoreCase(args[i]) || "-h".equals(args[i])) {
                printUsage();
                return;
            }
        }

        boolean hasDbCredentials = !dbPassword.isEmpty();

        // Step 1: Basic Encryption Demo
        runBasicEncryptionDemo();

        // Step 2: Oracle DB Integration (if credentials provided)
        if (hasDbCredentials) {
            runOracleIntegrationDemo(dbDsn, dbUser, dbPassword);
        } else {
            System.out.println("\n[SKIPPED] Oracle DB integration demo");
            System.out.println("         Set ORACLE_PASSWORD environment variable or use --password to enable.");
        }

        System.out.println("\n" + repeat("=", 70));
        System.out.println("All demos completed successfully!");
        System.out.println(repeat("=", 70));
    }

    /**
     * Demonstrates basic encryption/decryption using BasicEncryption.
     */
    private static void runBasicEncryptionDemo() {
        System.out.println(repeat("-", 70));
        System.out.println("Step 1: Basic Encryption Demo (BasicEncryption)");
        System.out.println(repeat("-", 70));

        try {
            BasicEncryption basic = new BasicEncryption();
            System.out.println("  Generated 256-bit key: " + basic.getKey());
            System.out.println();

            String[] testStrings = {
                "Sensitive customer information",
                "SSN: 123-45-6789",
                "Credit Card: 4111-1111-1111-1111",
                "Health record: Patient diagnosed with Type 2 Diabetes"
            };

            System.out.println("  Encrypting test data:");
            System.out.println();

            for (String testData : testStrings) {
                String encrypted = basic.encrypt(testData);
                String decrypted = basic.decrypt(encrypted);
                boolean match = decrypted.equals(testData);

                System.out.println("    Original:  " + testData);
                System.out.println("    Encrypted: " + encrypted);
                System.out.println("    Decrypted: " + decrypted);
                System.out.println("    Verified:  " + match + " ✓");
                System.out.println();
            }

            System.out.println("  [PASS] Basic encryption demo completed successfully.");
        } catch (Exception ex) {
            System.out.println("  [FAIL] Basic encryption demo failed: " + ex.getMessage());
            ex.printStackTrace();
        }
    }

    /**
     * Demonstrates Oracle database integration with encryption.
     */
    private static void runOracleIntegrationDemo(String dsn, String user, String password) {
        System.out.println(repeat("-", 70));
        System.out.println("Step 2: Oracle DB Integration Demo (OracleIntegration)");
        System.out.println(repeat("-", 70));
        System.out.println("  Connecting to: " + dsn + " as " + user);
        System.out.println();

        try {
            OracleIntegration oracle = new OracleIntegration("", dsn, user, password);
            System.out.println("  Encryption key: " + oracle.getKey());
            System.out.println();

            String tableName = "ENCRYPTED_DATA_DEMO";
            String columnName = "ENCRYPTED_VALUE";

            // Step 1: Create sample table
            createSampleTable(oracle, tableName, columnName);

            // Step 2: Insert encrypted data
            insertEncryptedData(oracle, tableName, columnName);

            // Step 3: Retrieve and decrypt
            retrieveAndDecryptData(oracle, tableName, columnName);

            // Step 4: Clean up
            dropSampleTable(oracle, tableName);

            System.out.println("\n  [PASS] Oracle DB integration demo completed successfully.");
        } catch (Exception ex) {
            System.out.println("  [FAIL] Oracle DB integration demo failed: " + ex.getMessage());
            System.out.println("         This may be expected if the database is not available.");
        }
    }

    /**
     * Creates the sample table in Oracle database.
     */
    private static void createSampleTable(OracleIntegration oracle, String tableName, String columnName) {
        System.out.println("  Creating sample table: " + tableName);

        String sql = "CREATE TABLE " + tableName + " (" +
                     "id VARCHAR2(50) PRIMARY KEY, " +
                     columnName + " CLOB)";

        try {
            oracle.executeSql(sql);
            System.out.println("  [OK] Table created successfully.");
        } catch (Exception ex) {
            if (ex.getMessage().contains("already exists") || ex.getMessage().contains("00001")) {
                System.out.println("  [INFO] Table already exists, skipping creation.");
            } else {
                System.out.println("  [FAIL] Table creation failed: " + ex.getMessage());
                throw new RuntimeException(ex);
            }
        }
        System.out.println();
    }

    /**
     * Inserts encrypted data into the sample table.
     */
    private static void insertEncryptedData(OracleIntegration oracle, String tableName, String columnName) {
        System.out.println("  Inserting encrypted records:");

        String[][] records = {
            {"REC001", "Customer SSN: 123-45-6789"},
            {"REC002", "Credit Card: 4111-1111-1111-1111"},
            {"REC003", "Health Record: Patient diagnosed with Type 2 Diabetes"}
        };

        for (String[] record : records) {
            boolean success = oracle.encryptAndStore(tableName, columnName, record[0], record[1]);
            System.out.println("    [" + (success ? "OK" : "FAIL") + "] Inserted record: " + record[0]);
        }
        System.out.println();
    }

    /**
     * Retrieves and decrypts data from the sample table.
     */
    private static void retrieveAndDecryptData(OracleIntegration oracle, String tableName, String columnName) {
        System.out.println("  Retrieving and decrypting records:");

        String[] recordIds = {"REC001", "REC002", "REC003"};

        for (String id : recordIds) {
            try {
                String decrypted = oracle.fetchAndDecrypt(tableName, columnName, id);
                System.out.println("    [OK] Record " + id + ": " + decrypted);
            } catch (Exception ex) {
                System.out.println("    [FAIL] Record " + id + ": " + ex.getMessage());
            }
        }
        System.out.println();
    }

    /**
     * Drops the sample table (cleanup).
     */
    private static void dropSampleTable(OracleIntegration oracle, String tableName) {
        System.out.println("  Cleaning up table: " + tableName);
        try {
            oracle.executeSql("DROP TABLE " + tableName);
            System.out.println("  [OK] Table dropped successfully.");
        } catch (Exception ex) {
            System.out.println("  [WARN] Table drop failed: " + ex.getMessage());
        }
        System.out.println();
    }

    /**
     * Prints usage information.
     */
    private static void printUsage() {
        System.out.println("Usage: mvn exec:java -Dexec.args=\"<options>\"");
        System.out.println();
        System.out.println("Options:");
        System.out.println("  --dsn <connection_string>   Oracle connection string (e.g., localhost:1521/orcl)");
        System.out.println("  --user <username>           Oracle username");
        System.out.println("  --password <password>       Oracle password");
        System.out.println("  --help, -h                  Show this help message");
        System.out.println();
        System.out.println("Environment Variables:");
        System.out.println("  ORACLE_DSN                  Oracle connection string");
        System.out.println("  ORACLE_USER                 Oracle username");
        System.out.println("  ORACLE_PASSWORD             Oracle password");
        System.out.println();
        System.out.println("Examples:");
        System.out.println("  mvn exec:java -Dexec.args=\"--dsn localhost:1521/orcl --user app --password secret\"");
        System.out.println("  ORACLE_PASSWORD=secret mvn exec:java");
    }
}
