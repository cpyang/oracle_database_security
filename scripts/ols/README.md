# Oracle Label Security (OLS) Scripts

Scripts for configuring Oracle Label Security (OLS) / Virtual Private Database (VPD) for row-level access control.

## Prerequisites

- **Oracle Database 11gR2 or 19c** (Enterprise Edition)
- **Advanced Security Option (ASO)** license
- **DBA privileges** required

## Scripts

### [setup_ols.sql](file:///home/cpyang/src/oracle_data_security/scripts/ols/setup_ols.sql)

Complete OLS setup script that configures a hierarchical label security policy for HR data.

**Steps performed:**
1. Verify prerequisites (OLS installation, user privileges)
2. Create the `HR_POLICY` policy
3. Create label hierarchy: PUBLIC → CONFIDENTIAL → SECRET → TOP_SECRET
4. Create compartmentations: RECRUITING, COMPENSATION, PERFORMANCE
5. Create user groups: HR_STAFF, HR_MANAGERS, HR_DIRECTORS, EXECUTIVES
6. Create sample `HR_EMPLOYEES` table with test data
7. Apply label security policy to the table
8. Grant privileges summary and verification queries

**Usage:**
```bash
# Run as DBA or user with OLS privileges
sqlplus / as sysdba @setup_ols.sql
```

**Expected output:**
```
=== Step 1: Verifying prerequisites ===
Oracle Label Security is installed.
User has OLS privileges.

=== Step 2: Creating Label Security Policy ===
Policy HR_POLICY created successfully.

=== Step 3: Creating Label Hierarchy ===
Label PUBLIC (tag 10) created.
Label CONFIDENTIAL (tag 20) created.
Label SECRET (tag 30) created.
Label TOP_SECRET (tag 40) created.
```

**Label Hierarchy:**
| Label | Tag | Access Level |
|-------|-----|--------------|
| PUBLIC | 10 | No restrictions |
| CONFIDENTIAL | 20 | HR internal data |
| SECRET | 30 | Sensitive personal data |
| TOP_SECRET | 40 | Executive/compensation data |

**User Groups:**
| Group | Max Label | Access |
|-------|-----------|--------|
| HR_STAFF | PUBLIC | Basic HR operations |
| HR_MANAGERS | CONFIDENTIAL | HR internal data |
| HR_DIRECTORS | SECRET | Sensitive personal data |
| EXECUTIVES | TOP_SECRET | All levels |

## Notes

- OLS enforces **row-level** access control based on user labels
- Users can only see data at or below their clearance level
- Compartmentations add multi-dimensional access control (e.g., department)
- Script is idempotent — safe to re-run
