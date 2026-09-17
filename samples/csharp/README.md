# Oracle Data Security - C# Encryption Samples

Application-level encryption samples demonstrating AES-CBC symmetric encryption with optional Oracle database integration.

## Prerequisites

- **.NET 8 SDK** (or later)
- **Oracle Database** (optional, for DB integration demo)

## Build

```bash
# Compile the project
cd samples/csharp
dotnet build
```

This downloads the Oracle JDBC driver (`Oracle.ManagedDataAccess.Core`) and compiles all C# sources.

## Run

### Basic Encryption Demo (no database required)

```bash
# Run the project
dotnet run

# Or run the compiled assembly directly
dotnet run --no-build
```

This demonstrates AES-CBC encryption/decryption of test strings with round-trip verification.

### Oracle DB Integration Demo (requires database)

```bash
# Method 1: Command-line arguments
dotnet run -- --dsn localhost:1521/orcl --user app_user --password your_password

# Method 2: Environment variables
export ORACLE_PASSWORD=your_password
dotnet run
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
samples/csharp/
├── OracleEncryptionSamples.csproj    # .NET project configuration
├── Program.cs                        # CLI entry point with full demo flow
├── OracleCryptoSample.cs             # AES-CBC encryption/decryption (no DB)
└── OracleIntegration.cs              # Encryption + Oracle DB operations
```

## Sample Output

```
======================================================================
Oracle Data Security - C# Encryption Samples
======================================================================

----------------------------------------------------------------------
Step 1: Basic Encryption Demo (OracleCryptoSample)
----------------------------------------------------------------------
  Generated 256-bit key: 93M86xgPACxnKKj9c4DHkCoN2PhJxdmHoL3/gAAcnXM=

  Encrypting test data:

    Original:  Sensitive customer information
    Encrypted: 2YjLLpUr/5v3XGSpIlqkme6tOZ0tFmJIkWxVR2MsWNWYkZknrLrvcsqfOs86fFG7
    Decrypted: Sensitive customer information
    Verified:  True ✓

    Original:  SSN: 123-45-6789
    Encrypted: IA4X1GKgCz+krKwSUSYUPCVM1wPCzsp909L2aAe2KAXeX85EAkJNz0tsoHsiDmcB
    Decrypted: SSN: 123-45-6789
    Verified:  True ✓

  [PASS] Basic encryption demo completed successfully.

======================================================================
All demos completed successfully!
======================================================================
```

## Notes

- The encryption uses **AES-CBC with PKCS7 padding** (128-bit block size, 16-byte IV)
- The `OracleIntegration` class uses `Oracle.ManagedDataAccess.Core` for cross-platform database connectivity
- Build artifacts (`bin/`, `obj/`) are excluded from git via `.gitignore`
