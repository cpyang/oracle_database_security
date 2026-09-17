package com.oracle.encryption;

import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 * Demonstrates application-level encryption with Oracle database integration.
 *
 * This class shows how to encrypt data before inserting into Oracle and
 * decrypt data after retrieving from Oracle using the Oracle JDBC driver.
 *
 * Usage with Oracle JDBC:
 *   mvn dependency:copy-dependencies -DoutputDirectory=lib
 *   java -cp ".:lib/*" com.oracle.encryption.OracleIntegration
 */
public class OracleIntegration {

    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128;

    private final SecretKey secretKey;
    private final SecureRandom secureRandom;

    /** Database connection settings (use environment variables in production) */
    private final String dsn;
    private final String user;
    private final String password;

    /**
     * Creates an OracleIntegration instance with a generated key.
     */
    public OracleIntegration() throws NoSuchAlgorithmException {
        this.secretKey = generateKey();
        this.secureRandom = new SecureRandom();
        this.dsn = System.getenv("ORACLE_DSN");
        this.user = System.getenv("ORACLE_USER");
        this.password = System.getenv("ORACLE_PASSWORD");
    }

    /**
     * Creates an OracleIntegration instance with the provided key and credentials.
     */
    public OracleIntegration(String key, String dsn, String user, String password) {
        byte[] decodedKey = Base64.getDecoder().decode(key);
        this.secretKey = new SecretKeySpec(decodedKey, ALGORITHM);
        this.secureRandom = new SecureRandom();
        this.dsn = dsn;
        this.user = user;
        this.password = password;
    }

    // ==================== Encryption Methods ====================

    public SecretKey generateKey() throws NoSuchAlgorithmException {
        KeyGenerator keyGenerator = KeyGenerator.getInstance(ALGORITHM);
        keyGenerator.init(256, secureRandom);
        return keyGenerator.generateKey();
    }

    /**
     * Encrypts plaintext using AES-GCM.
     *
     * @param plaintext The string to encrypt
     * @return Base64-encoded string containing IV and ciphertext
     */
    public String encrypt(String plaintext) {
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            byte[] iv = new byte[GCM_IV_LENGTH];
            secureRandom.nextBytes(iv);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, parameterSpec);

            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            byte[] ivAndCiphertext = new byte[iv.length + ciphertext.length];
            System.arraycopy(iv, 0, ivAndCiphertext, 0, iv.length);
            System.arraycopy(ciphertext, 0, ivAndCiphertext, iv.length, ciphertext.length);

            return Base64.getEncoder().encodeToString(ivAndCiphertext);
        } catch (Exception e) {
            throw new RuntimeException("Encryption failed", e);
        }
    }

    /**
     * Decrypts ciphertext using AES-GCM.
     *
     * @param ciphertext Base64-encoded string containing IV and ciphertext
     * @return The decrypted plaintext string
     */
    public String decrypt(String ciphertext) {
        try {
            byte[] ivAndCiphertext = Base64.getDecoder().decode(ciphertext);
            byte[] iv = new byte[GCM_IV_LENGTH];
            byte[] ciphertextBytes = new byte[ivAndCiphertext.length - GCM_IV_LENGTH];
            System.arraycopy(ivAndCiphertext, 0, iv, 0, GCM_IV_LENGTH);
            System.arraycopy(ivAndCiphertext, GCM_IV_LENGTH, ciphertextBytes, 0, ciphertextBytes.length);

            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, parameterSpec);

            byte[] plaintext = cipher.doFinal(ciphertextBytes);
            return new String(plaintext, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("Decryption failed", e);
        }
    }

    // ==================== Database Integration Methods ====================

    /**
     * Encrypts data and inserts/updates it in the Oracle database.
     *
     * @param tableName  Target table name
     * @param columnName Target column name
     * @param rowId      Row identifier for WHERE clause
     * @param plaintext  Data to encrypt and store
     * @return true if a row was inserted or updated
     */
    public boolean encryptAndStore(String tableName, String columnName,
                                   String rowId, String plaintext) {
        String encrypted = encrypt(plaintext);
        String sql = "MERGE INTO " + tableName + " t " +
                     "USING DUAL ON (id = ?) " +
                     "WHEN MATCHED THEN UPDATE SET " + columnName + " = ? " +
                     "WHEN NOT MATCHED THEN INSERT (id, " + columnName + ") VALUES (?, ?)";

        try (java.sql.Connection connection = getOracleConnection();
             java.sql.PreparedStatement statement = (java.sql.PreparedStatement) connection.prepareStatement(sql)) {

            statement.setString(1, rowId);
            statement.setString(2, encrypted);
            statement.setString(3, rowId);
            statement.setString(4, encrypted);

            return statement.executeUpdate() > 0;

        } catch (Exception e) {
            System.err.println("Database operation failed: " + e.getMessage());
            return false;
        }
    }

    /**
     * Fetches encrypted data from Oracle and decrypts it.
     *
     * @param tableName  Source table name
     * @param columnName Source column name
     * @param rowId      Row identifier
     * @return The decrypted plaintext string
     */
    public String fetchAndDecrypt(String tableName, String columnName, String rowId) {
        String sql = "SELECT " + columnName + " FROM " + tableName + " WHERE id = ?";

        try (java.sql.Connection connection = getOracleConnection();
             java.sql.PreparedStatement statement = (java.sql.PreparedStatement) connection.prepareStatement(sql)) {

            statement.setString(1, rowId);
            java.sql.ResultSet resultSet = statement.executeQuery();

            if (resultSet.next()) {
                String encrypted = resultSet.getString(1);
                return decrypt(encrypted);
            }
            throw new RuntimeException("No record found for row_id: " + rowId);

        } catch (Exception e) {
            System.err.println("Database fetch failed: " + e.getMessage());
            return null;
        }
    }

    /**
     * Gets an Oracle database connection.
     *
     * @return Oracle Connection object
     */
    private java.sql.Connection getOracleConnection() throws Exception {
        Class.forName("oracle.jdbc.OracleDriver");
        return java.sql.DriverManager.getConnection(
            "jdbc:oracle:thin:@" + dsn, user, password
        );
    }

    /**
     * Returns the base64-encoded secret key.
     */
    public String getKey() {
        return Base64.getEncoder().encodeToString(secretKey.getEncoded());
    }

    /**
     * Executes a raw SQL statement (CREATE, DROP, etc.).
     *
     * @param sql The SQL statement to execute
     */
    public void executeSql(String sql) throws Exception {
        try (java.sql.Connection connection = getOracleConnection();
             java.sql.Statement statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }

    private static String repeat(String s, int count) {
        StringBuilder sb = new StringBuilder(s.length() * count);
        for (int i = 0; i < count; i++) {
            sb.append(s);
        }
        return sb.toString();
    }

    /**
     * Demonstrates Oracle database encryption integration.
     */
    public static void main(String[] args) {
        System.out.println(repeat("=", 60));
        System.out.println("Oracle Database Encryption Integration Demo");
        System.out.println(repeat("=", 60));

        try {
            // Create encryption manager
            OracleIntegration manager = new OracleIntegration();

            // Example: encrypt data before storing
            String sensitiveData = "Customer SSN: 123-45-6789";
            String encrypted = manager.encrypt(sensitiveData);
            System.out.println("\nOriginal:  " + sensitiveData);
            System.out.println("Encrypted: " + encrypted);

            // Example: decrypt data after retrieving
            String decrypted = manager.decrypt(encrypted);
            System.out.println("Decrypted: " + decrypted);

            System.out.println("\nKey: " + manager.getKey());

            System.out.println("\n" + repeat("=", 60));
            System.out.println("To connect to Oracle database:");
            System.out.println("  1. Add Oracle JDBC driver to classpath");
            System.out.println("  2. Set ORACLE_DSN, ORACLE_USER, ORACLE_PASSWORD env vars");
            System.out.println("  3. Call encryptAndStore() and fetchAndDecrypt()");
            System.out.println(repeat("=", 60));

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
