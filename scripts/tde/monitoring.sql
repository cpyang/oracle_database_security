-- ============================================================================
-- monitoring.sql - TDE Status and Health Checks
-- ============================================================================
-- This script provides comprehensive monitoring and health check queries
-- for Transparent Data Encryption (TDE) in Oracle Database.
--
-- Prerequisites:
--   - TDE wallet must be configured (see setup_tde.sql)
--   - DBA privileges required
--
-- Usage:
--   sqlplus / as sysdba @monitoring.sql
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

-- ============================================================================
-- Step 1: Wallet Status Check
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 1: Wallet Status Check ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  FOR w IN (
    SELECT status, wallet_type, wallet_location
    FROM v$encryption_wallet
  ) LOOP
    DBMS_OUTPUT.PUT_LINE('Wallet Status: ' || w.status);
    DBMS_OUTPUT.PUT_LINE('Wallet Type: ' || w.wallet_type);
    DBMS_OUTPUT.PUT_LINE('Wallet Location: ' || w.wallet_location);
    
    IF w.status = 'OPEN' THEN
      DBMS_OUTPUT.PUT_LINE('');
      DBMS_OUTPUT.PUT_LINE('  [OK] Wallet is open and ready for TDE operations.');
    ELSIF w.status = 'UNUSABLE' THEN
      DBMS_OUTPUT.PUT_LINE('');
      DBMS_OUTPUT.PUT_LINE('  [ERROR] Wallet is unusable. Check wallet files and permissions.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('');
      DBMS_OUTPUT.PUT_LINE('  [WARNING] Wallet is not open. TDE operations will fail.');
      DBMS_OUTPUT.PUT_LINE('  Action: ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN;');
    END IF;
  END LOOP;
  
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] No wallet found. TDE may not be configured.');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error checking wallet: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 2: Encryption Keys Inventory
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Step 2: Encryption Keys Inventory ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  FOR k IN (
    SELECT key_id,
           TO_CHAR(creation_date, 'YYYY-MM-DD HH24:MI:SS') AS created,
           status,
           algorithm
    FROM v$encryption_keys
    ORDER BY creation_date DESC
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Key ID: ' || k.key_id ||
      ', Created: ' || k.created ||
      ', Algorithm: ' || k.algorithm ||
      ', Status: ' || k.status
    );
  END LOOP;
  
  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  No encryption keys found.');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error querying keys: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 3: Encrypted Objects Summary
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Step 3: Encrypted Objects Summary ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  -- Count encrypted tables
  DBMS_OUTPUT.PUT_LINE('--- Encrypted Tables ---');
  FOR t IN (
    SELECT owner, table_name, tablespace_name
    FROM dba_tables
    WHERE encryption_algorithm IS NOT NULL
    ORDER BY owner, table_name
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Table: ' || t.owner || '.' || t.table_name ||
      ', Tablespace: ' || t.tablespace_name
    );
  END LOOP;
  
  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  No encrypted tables found.');
  END IF;
  
  -- Count encrypted columns
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Encrypted Columns ---');
  FOR c IN (
    SELECT owner, table_name, column_name,
           encryption_algorithm,
           CASE WHEN salt = 'YES' THEN 'Yes' ELSE 'No' END AS salt
    FROM dba_encrypted_columns
    ORDER BY owner, table_name, column_name
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Column: ' || c.owner || '.' || c.table_name || '.' || c.column_name ||
      ', Algorithm: ' || c.encryption_algorithm ||
      ', Salt: ' || c.salt
    );
  END LOOP;
  
  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  No encrypted columns found.');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error querying encrypted objects: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 4: Encrypted Tablespaces
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Step 4: Encrypted Tablespaces ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  FOR ts IN (
    SELECT tablespace_name,
           encryption_algorithm,
           status,
           TO_CHAR(bytes/1024/1024, '999,999.99') AS size_mb
    FROM dba_tablespaces
    WHERE encryption_algorithm IS NOT NULL
    ORDER BY tablespace_name
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Tablespace: ' || ts.tablespace_name ||
      ', Algorithm: ' || ts.encryption_algorithm ||
      ', Status: ' || ts.status ||
      ', Size: ' || ts.size_mb || ' MB'
    );
  END LOOP;
  
  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  No encrypted tablespaces found.');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error querying tablespaces: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 5: TDE Operations Log
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Step 5: TDE Operations Log ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  DBMS_OUTPUT.PUT_LINE('Recent TDE operations (last 7 days):');
  
  FOR op IN (
    SELECT operation,
           TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS started,
           TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS ended,
           status,
           error_code
    FROM v$encryption_operation
    WHERE start_time >= SYSDATE - 7
    ORDER BY start_time DESC
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Operation: ' || op.operation ||
      ', Started: ' || op.started ||
      ', Ended: ' || op.ended ||
      ', Status: ' || op.status ||
      CASE WHEN op.error_code IS NOT NULL THEN ', Error: ' || op.error_code ELSE '' END
    );
  END LOOP;
  
  IF SQL%ROWCOUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  No TDE operations in the last 7 days.');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error querying operations: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 6: Health Check Summary
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== Step 6: Health Check Summary ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  DECLARE
    v_wallet_status VARCHAR2(30);
    v_key_count NUMBER;
    v_table_count NUMBER;
    v_column_count NUMBER;
    v_tablespace_count NUMBER;
  BEGIN
    -- Check wallet
    BEGIN
      SELECT status INTO v_wallet_status FROM v$encryption_wallet;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_wallet_status := 'NOT CONFIGURED';
    END;
    
    -- Count keys
    SELECT COUNT(*) INTO v_key_count FROM v$encryption_keys;
    
    -- Count encrypted tables
    SELECT COUNT(*) INTO v_table_count FROM dba_tables WHERE encryption_algorithm IS NOT NULL;
    
    -- Count encrypted columns
    SELECT COUNT(*) INTO v_column_count FROM dba_encrypted_columns;
    
    -- Count encrypted tablespaces
    SELECT COUNT(*) INTO v_tablespace_count FROM dba_tablespaces WHERE encryption_algorithm IS NOT NULL;
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE('  Wallet Status: ' || v_wallet_status);
    DBMS_OUTPUT.PUT_LINE('  Encryption Keys: ' || v_key_count);
    DBMS_OUTPUT.PUT_LINE('  Encrypted Tables: ' || v_table_count);
    DBMS_OUTPUT.PUT_LINE('  Encrypted Columns: ' || v_column_count);
    DBMS_OUTPUT.PUT_LINE('  Encrypted Tablespaces: ' || v_tablespace_count);
    
    -- Health verdict
    DBMS_OUTPUT.PUT_LINE('');
    IF v_wallet_status = 'OPEN' AND v_key_count > 0 THEN
      DBMS_OUTPUT.PUT_LINE('  [HEALTHY] TDE is properly configured and operational.');
    ELSIF v_wallet_status = 'OPEN' THEN
      DBMS_OUTPUT.PUT_LINE('  [WARNING] Wallet is open but no encryption keys found.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('  [UNHEALTHY] Wallet is not open or not configured.');
    END IF;
    
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [ERROR] Health check failed: ' || SQLERRM);
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Monitoring Complete');
  DBMS_OUTPUT.PUT_LINE('========================================');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  [ERROR] Error in health check: ' || SQLERRM);
END;
/
