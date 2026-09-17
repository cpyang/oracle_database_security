# Oracle Data Redaction Scripts

Scripts for configuring Oracle Data Redaction for real-time data masking.

## Prerequisites

- **Oracle Database 12c (12.1.0.2) or later** (19c recommended)
- **Enterprise Edition** with Advanced Security Option
- **DBA privileges** required
- **Note:** Data Redaction is NOT available in Oracle 11gR2

## Scripts

### [setup_redaction.sql](file:///home/cpyang/src/oracle_data_security/scripts/redaction/setup_redaction.sql)

Complete Data Redaction setup with sample table and 5 redaction policies.

**Steps performed:**
1. Verify prerequisites (database version, user privileges)
2. Create sample `EMPLOYEES` table with sensitive data
3. Create 5 redaction policies for different data types
4. Enable all redaction policies
5. Verification queries and utility procedures
6. Monitoring and performance considerations

**Usage:**
```bash
# Run as schema owner or DBA
sqlplus app_user/app_password @setup_redaction.sql
```

**Policies created:**
| Policy | Column | Type | Description |
|--------|--------|------|-------------|
| SSN_FULL_REDACTION | SSN | FULL | Hide all SSN for non-HR users |
| SALARY_PARTIAL_REDACTION | SALARY | PARTIAL | Show last 2 digits for non-managers |
| CREDIT_CARD_PATTERN_REDACTION | CREDIT_CARD | PATTERN | Show last 4 digits |
| PHONE_REGEX_REDACTION | PHONE | REGEXP | Replace area code |
| EMAIL_EMPTY_REDACTION | EMAIL | EMPTY | Clear all email addresses |

### [redaction_policies.sql](file:///home/cpyang/src/oracle_data_security/scripts/redaction/redaction_policies.sql)

Advanced redaction policy management with demo schema creation.

**Steps performed:**
1. Create demo schema (`redact_demo_user`) and sample data
2. Create 4 redaction policies with different function types
3. Query data with redaction applied (real-time masking)
4. List all active redaction policies
5. Enable/disable policies dynamically
6. Cleanup instructions

**Usage:**
```bash
# Run as DBA (creates demo user automatically)
sqlplus / as sysdba @redaction_policies.sql
```

**Redaction Functions:**
| Function | Effect | Example |
|----------|--------|---------|
| `DBMS_REDACT.FULL` | Hide all data | `123-45-6789` → `XXXXXXXXXX` |
| `DBMS_REDACT.PARTIAL` | Show partial data | `$95000` → `******00` |
| `DBMS_REDACT.PATTERN` | Pattern-based masking | `4111111111111111` → `4111************` |
| `DBMS_REDACT.REGEXP` | Regex-based masking | `user@domain.com` → `us**@**.**` |
| `DBMS_REDACT.EMPTY` | Replace with empty string | `user@domain.com` → `` |

## Notes

- Redaction is **real-time and transparent** to applications
- Underlying data is **never modified** in the database
- Policies can be **enabled/disabled dynamically** without downtime
- Expression controls which users see redacted vs. full data
- Minimal performance overhead (~1-3% typically)
