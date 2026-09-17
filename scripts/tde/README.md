# Transparent Data Encryption (TDE) Scripts

Scripts for configuring and managing Oracle Transparent Data Encryption (TDE) for data-at-rest encryption.

## Prerequisites

- **Oracle Database 11gR2 or later** (19c recommended)
- **Enterprise Edition** with Advanced Security Option (ASO)
- **DBA privileges** required
- **WALLET_ROOT** directory accessible by Oracle software owner

## Scripts

### [setup_tde.sql](file:///home/cpyang/src/oracle_data_security/scripts/tde/setup_tde.sql)

Initial TDE wallet configuration and master key creation.

**Steps performed:**
1. Configure `WALLET_ROOT` parameter
2. Create encryption wallet at `/opt/oracle/wallets/tde`
3. Open the wallet for the session
4. Create the master encryption key with backup
5. Verify wallet and key status
6. Instructions for auto-login wallet creation

**Usage:**
```bash
# Run as sysdba (requires restart for WALLET_ROOT)
sqlplus / as sysdba @setup_tde.sql
```

**Expected output:**
```
=== Step 1: Configuring TDE Wallet Location ===
Wallet root configured: /opt/oracle/wallets
NOTE: Database restart required for WALLET_ROOT to take effect.

=== Step 2: Creating Encryption Wallet ===
Wallet created successfully at /opt/oracle/wallets/tde

=== Step 3: Opening the Wallet ===
Wallet opened successfully for this session.

=== Step 4: Creating Master Encryption Key ===
Master encryption key created successfully.
A backup of the key has been saved.

=== Step 5: Verifying Wallet and Key Status ===
Wallet Status: OPEN
Wallet Type: SOFTWARE
SUCCESS: TDE wallet is open and ready for use.
```

---

### [column_tde.sql](file:///home/cpyang/src/oracle_data_security/scripts/tde/column_tde.sql)

Encrypt individual columns in Oracle tables using TDE.

**Steps performed:**
1. Create demo tablespace `tde_demo_data`
2. Create demo user `tde_demo_user`
3. Create `employees` table with encrypted columns (SSN, credit_card, salary)
4. Insert sample data
5. Query encrypted data (transparent decryption)
6. Demonstrate search on encrypted column (NO SALT)
7. Verify encryption at rest via `dba_encrypted_columns`

**Usage:**
```bash
# Run as schema owner (wallet must be open first)
sqlplus tde_demo_user/DemoUser123! @column_tde.sql
```

**Encrypted columns:**
| Column | Options | Algorithm | Use Case |
|--------|---------|-----------|----------|
| SSN | `ENCRYPT NO SALT` | AES192 | Supports equality searches/indexing |
| Credit Card | `ENCRYPT` (with salt) | AES192 | Higher security, no indexing |
| Salary | `ENCRYPT` (with salt) | AES192 | Sensitive compensation data |

**ENCRYPT options:**
- `ENCRYPT` — Encrypts with salt (higher security, prevents pattern analysis)
- `ENCRYPT NO SALT` — Encrypts without salt (supports equality searches, indexing)

---

### [tablespace_tde.sql](file:///home/cpyang/src/oracle_data_security/scripts/tde/tablespace_tde.sql)

Create and use encrypted tablespaces for automatic data-at-rest encryption.

**Steps performed:**
1. Verify wallet is open
2. Create encrypted tablespace `tde_encrypted_data` with AES256
3. Create demo user with encrypted tablespace as default
4. Create table in encrypted tablespace
5. Insert and query data (transparent encryption/decryption)
6. Verify encryption via `dba_tablespaces`
7. Cleanup instructions

**Usage:**
```bash
# Run as sysdba
sqlplus / as sysdba @tablespace_tde.sql
```

**Encrypted tablespace:**
| Property | Value |
|----------|-------|
| Name | `tde_encrypted_data` |
| Algorithm | AES256 |
| Datafile | `/opt/oracle/oradata/orcl/tde_encrypted_data.dbf` |
| Auto-extend | Enabled (10M increments) |
| Default storage | ENCRYPT |

**Benefits:**
- Complete transparency to applications (no code changes)
- Encrypts all data in the tablespace automatically
- Supports all data types including CLOB/BLOB
- No column-by-column configuration needed

**Considerations:**
- Performance overhead: ~5-15%
- Cannot encrypt existing data without reorganization
- Wallet must be open for all operations

---

### [key_management.sql](file:///home/cpyang/src/oracle_data_security/scripts/tde/key_management.sql)

TDE key rotation, wallet backup, and recovery procedures.

**Steps performed:**
1. Current key status overview (wallet, keys, rotation history)
2. Rotate master encryption key with automatic backup
3. Export key backup with AES256 encryption
4. List all available key backups
5. Restore key from backup (with warnings)
6. Wallet backup and recovery instructions
7. Close/reopen wallet procedures

**Usage:**
```bash
# Run as sysdba
sqlplus / as sysdba @key_management.sql
```

**Key management operations:**
| Operation | Command | Purpose |
|-----------|---------|---------|
| Rotate key | `ADMINISTER KEY MANAGEMENT SET KEY` | Generate new master key |
| Backup key | `ADMINISTER KEY MANAGEMENT CREATE KEY BACKUP` | Export key for DR |
| Restore key | `ADMINISTER KEY MANAGEMENT RESTORE KEY BACKUP` | Recover from backup |
| Backup wallet | `ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE` | Backup entire wallet |
| Restore wallet | `ADMINISTER KEY MANAGEMENT RESTORE KEYSTORE` | Restore entire wallet |
| Close wallet | `ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE` | Disable TDE temporarily |
| Open wallet | `ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN` | Enable TDE operations |

**Best practices:**
- Rotate keys every 90 days (or per security policy)
- Keep at least 3 key backups
- Store backups in secure off-site location
- Document all key management operations
- Test recovery procedures regularly

---

### [monitoring.sql](file:///home/cpyang/src/oracle_data_security/scripts/tde/monitoring.sql)

Comprehensive TDE monitoring and health check queries.

**Steps performed:**
1. Wallet status check (OPEN/UNUSABLE/NOT CONFIGURED)
2. Encryption keys inventory (key ID, algorithm, status)
3. Encrypted objects summary (tables, columns)
4. Encrypted tablespaces listing
5. TDE operations log (last 7 days)
6. Health check summary with verdict

**Usage:**
```bash
# Run as sysdba
sqlplus / as sysdba @monitoring.sql
```

**Health check output:**
```
=== Step 6: Health Check Summary ===

  Wallet Status: OPEN
  Encryption Keys: 3
  Encrypted Tables: 2
  Encrypted Columns: 5
  Encrypted Tablespaces: 1

  [HEALTHY] TDE is properly configured and operational.
```

**Key views used:**
| View | Purpose |
|------|---------|
| `V$ENCRYPTION_WALLET` | Wallet status and type |
| `V$ENCRYPTION_KEYS` | Key inventory and algorithms |
| `V$ENCRYPTION_OPERATION` | Operation history |
| `DBA_TABLES` | Encrypted tables |
| `DBA_ENCRYPTED_COLUMNS` | Encrypted columns |
| `DBA_TABLESPACES` | Encrypted tablespaces |

## Script Flow

```
setup_tde.sql     → Create wallet and master key
     ↓
column_tde.sql    → Encrypt individual columns
tablespace_tde.sql → Create encrypted tablespaces
     ↓
key_management.sql → Rotate keys, backup, restore
     ↓
monitoring.sql    → Health checks and status
```

## Notes

- All scripts are **idempotent** — safe to re-run
- Wallet password must be consistent across all operations
- Always backup the wallet before key rotation
- For production, consider using **HSM** (Hardware Security Module) instead of software wallet
- Auto-login wallet (`orapki wallet create -wallet <path> -auto_login`) recommended for production
