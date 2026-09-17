# Oracle Data Security - Java Encryption Samples

Application-level encryption samples demonstrating AES-GCM symmetric encryption with optional Oracle database integration.

## Prerequisites

- **Java 8+** (JDK)
- **Maven 3.6+**
- **Oracle Database** (optional, for DB integration demo)

## Build

```bash
# Compile the project
cd samples/java
mvn compile
```

This downloads the Oracle JDBC driver (`ojdbc8`) and compiles all Java sources.

## Run

### Basic Encryption Demo (no database required)

```bash
# Using Maven exec plugin
mvn exec:java

# Or run the compiled class directly
java -cp "target/classes:$(mvn dependency:build-classpath -q -DincludeScope=runtime -Dmdep.outputFile=/dev/stdout)" com.oracle.encryption.Main
```

This demonstrates AES-GCM encryption/decryption of test strings with round-trip verification.

### Oracle DB Integration Demo (requires database)

```bash
# Method 1: Command-line arguments
mvn exec:java -Dexec.args="--dsn localhost:1521/orcl --user app_user --password your_password"

# Method 2: Environment variables
export ORACLE_DSN=localhost:1521/orcl
export ORACLE_USER=app_user
export ORACLE_PASSWORD=your_password
mvn exec:java
```

This demo:
1. Runs the basic encryption test (same as above)
2. Creates a sample table in Oracle
3. Inserts encrypted records
4. Retrieves and decrypts the records
5. Cleans up the table

### Available Options

| Option | Description | Example |
|--------|-------------|---------|
| `--dsn` | Oracle connection string | `localhost:1521/orcl` |
| `--user` | Oracle username | `app_user` |
| `--password` | Oracle password | `secret` |
| `--help`, `-h` | Show help message | — |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ORACLE_DSN` | Oracle connection string (e.g., `localhost:1521/orcl`) |
| `ORACLE_USER` | Oracle username |
| `ORACLE_PASSWORD` | Oracle password |

## Project Structure

```
samples/java/
├── pom.xml                          # Maven project configuration
└── src/main/java/com/oracle/encryption/
    ├── Main.java                    # CLI entry point with full demo flow
    ├── BasicEncryption.java         # AES-GCM encryption/decryption (no DB)
    └── OracleIntegration.java       # Encryption + Oracle DB operations
```

## Sample Output

```
======================================================================
Oracle Data Security - Java Encryption Samples
======================================================================

----------------------------------------------------------------------
Step 1: Basic Encryption Demo (BasicEncryption)
----------------------------------------------------------------------
  Generated 256-bit key: ABC123...

  Encrypting test data:

    Original:  Sensitive customer information
    Encrypted: aBcDeFgH...
    Decrypted: Sensitive customer information
    Verified:  true ✓

  [PASS] Basic encryption demo completed successfully.

----------------------------------------------------------------------
Step 2: Oracle DB Integration Demo (OracleIntegration)
----------------------------------------------------------------------
  Connecting to: localhost:1521/orcl as app_user

  Creating sample table: ENCRYPTED_DATA_DEMO
  [OK] Table created successfully.

  Inserting encrypted records:
    [OK] Inserted record: REC001
    [OK] Inserted record: REC002
    [OK] Inserted record: REC003

  Retrieving and decrypting records:
    [OK] Record REC001: Customer SSN: 123-45-6789
    [OK] Record REC002: Credit Card: 4111-1111-1111-1111
    [OK] Record REC003: Health Record: Patient diagnosed with Type 2 Diabetes

  Cleaning up table: ENCRYPTED_DATA_DEMO
  [OK] Table dropped successfully.

  [PASS] Oracle DB integration demo completed successfully.

======================================================================
All demos completed successfully!
======================================================================
```
