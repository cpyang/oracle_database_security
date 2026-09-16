-- ============================================================================
-- key_management.sql - TDE Key Rotation and Wallet Operations
-- ============================================================================
-- This script provides procedures for managing TDE encryption keys,
-- including key rotation, wallet backup, and key export/import.
--
-- Prerequisites:
--   - TDE wallet must be configured and open (see setup_tde.sql)
--   - DBA privileges required
--
-- Usage:
--   sqlplus / as sysdba @key_management.sql
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

-- ============================================================================
-- Step 1: Current Key Status Overview
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 1: Current Key Status Overview ===');
  DBMS_OUTPUT.PUT_LINE('');
  
  -- Check wallet status
  DBMS_OUTPUT.PUT_LINE('--- Wallet Status ---');
  FOR w IN (SELECT status, wallet_type FROM v$encryption_wallet) LOOP
    DBMS_OUTPUT.PUT_LINE('  Status: ' || w.status);
    DBMS_OUTPUT.PUT_LINE('  Type: ' || w.wallet_type);
  END LOOP;
  
  -- Check encryption keys
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Encryption Keys ---');
  FOR k IN (
    SELECT key_id, creation_date, status
    FROM v$encryption_keys
    ORDER BY creation_date DESC
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Key ID: ' || k.key_id ||
      ', Created: ' || TO_CHAR(k.creation_date, 'YYYY-MM-DD HH24:MI:SS') ||
      ', Status: ' || k.status
    );
  END LOOP;
  
  -- Check last key rotation
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- Last Key Rotation ---');
  FOR r IN (
    SELECT operation, start_time, end_time, status
    FROM v$encryption_operation
    WHERE operation = 'KEY ROTATION'
    ORDER BY start_time DESC
    FETCH FIRST 1 ROWS ONLY
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Operation: ' || r.operation ||
      ', Started: ' || TO_CHAR(r.start_time, 'YYYY-MM-DD HH24:MI:SS') ||
      ', Ended: ' || TO_CHAR(r.end_time, 'YYYY-MM-DD HH24:MI:SS') ||
      ', Status: ' || r.status
    );
  END LOOP;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error checking status: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 2: Rotate the Master Encryption Key
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 2: Rotating Master Encryption Key ===');
  
  -- Backup the current key before rotation
  EXECUTE IMMEDIATE '
    ADMINISTER KEY MANAGEMENT SET KEY 
    BACKUP USING ''Pre_Rotation_Backup_'' || TO_CHAR(SYSDATE, ''YYYYMMDD_HH24MISS'')
  ';
  
  DBMS_OUTPUT.PUT_LINE('Current key backed up successfully.');
  
  -- Generate a new master key
  EXECUTE IMMEDIATE '
    ADMINISTER KEY MANAGEMENT SET KEY
    IDENTIFIED BY ''YourStrongWalletPassword''
    WITH BACKUP USING ''Post_Rotation_Backup_'' || TO_CHAR(SYSDATE, ''YYYYMMDD_HH24MISS'')
  ';
  
  DBMS_OUTPUT.PUT_LINE('New master encryption key generated successfully.');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('IMPORTANT:');
  DBMS_OUTPUT.PUT_LINE('  - Old keys are still accessible for decrypting existing data');
  DBMS_OUTPUT.PUT_LINE('  - New data will be encrypted with the new key');
  DBMS_OUTPUT.PUT_LINE('  - Old backups should be retained for disaster recovery');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error rotating key: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 3: Export Key Backup
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 3: Exporting Key Backup ===');
  
  -- Create a key backup file
  EXECUTE IMMEDIATE '
    ADMINISTER KEY MANAGEMENT CREATE KEY BACKUP
    IDENTIFIED BY ''YourStrongWalletPassword''
    USING ''TDE_Key_Backup_'' || TO_CHAR(SYSDATE, ''YYYYMMDD_HH24MISS'')
    ENCRYPTED USING ''AES256''
  ';
  
  DBMS_OUTPUT.PUT_LINE('Key backup exported successfully.');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('The key backup file is stored in the wallet directory.');
  DBMS_OUTPUT.PUT_LINE('Store this backup securely for disaster recovery.');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error exporting key backup: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 4: List All Key Backups
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 4: Listing All Key Backups ===');
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Available key backups:');
  
  FOR b IN (
    SELECT backup_id, creation_time, status
    FROM v$encryption_key_backup
    ORDER BY creation_time DESC
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(
      '  Backup ID: ' || b.backup_id ||
      ', Created: ' || TO_CHAR(b.creation_time, 'YYYY-MM-DD HH24:MI:SS') ||
      ', Status: ' || b.status
    );
  END LOOP;
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error listing backups: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 5: Restore from Key Backup
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 5: Restore Key from Backup (Optional) ===');
  
  DBMS_OUTPUT.PUT_LINE('To restore a key from backup, use the following command:');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  ADMINISTER KEY MANAGEMENT RESTORE KEY BACKUP');
  DBMS_OUTPUT.PUT_LINE('  IDENTIFIED BY ''YourStrongWalletPassword''');
  DBMS_OUTPUT.PUT_LINE('  USING ''Backup_ID''');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('WARNING:');
  DBMS_OUTPUT.PUT_LINE('  - Restoring a key will change the master key');
  DBMS_OUTPUT.PUT_LINE('  - Existing data encrypted with newer keys may become inaccessible');
  DBMS_OUTPUT.PUT_LINE('  - Always verify backup integrity before restoring');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 6: Wallet Backup and Recovery
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 6: Wallet Backup and Recovery ===');
  
  -- Backup the wallet
  EXECUTE IMMEDIATE '
    ADMINISTER KEY MANAGEMENT CREATE KEY BACKUP
    IDENTIFIED BY ''YourStrongWalletPassword''
    USING ''Wallet_Backup_'' || TO_CHAR(SYSDATE, ''YYYYMMDD_HH24MISS'')
  ';
  
  DBMS_OUTPUT.PUT_LINE('Wallet backed up successfully.');
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Wallet recovery commands:');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  -- Backup wallet');
  DBMS_OUTPUT.PUT_LINE('  ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE');
  DBMS_OUTPUT.PUT_LINE('  IDENTIFIED BY ''YourStrongWalletPassword''');
  DBMS_OUTPUT.PUT_LINE('  USING ''Backup_Name''');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('  -- Restore wallet');
  DBMS_OUTPUT.PUT_LINE('  ADMINISTER KEY MANAGEMENT RESTORE KEYSTORE');
  DBMS_OUTPUT.PUT_LINE('  IDENTIFIED BY ''YourStrongWalletPassword''');
  DBMS_OUTPUT.PUT_LINE('  USING ''Backup_Name''');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 7: Close Wallet
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 7: Closing Wallet (Optional) ===');
  
  -- Close the wallet
  EXECUTE IMMEDIATE 'ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE';
  
  DBMS_OUTPUT.PUT_LINE('Wallet closed successfully.');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('After closing the wallet:');
  DBMS_OUTPUT.PUT_LINE('  - Encrypted data cannot be accessed');
  DBMS_OUTPUT.PUT_LINE('  - The wallet must be reopened before any TDE operations');
  DBMS_OUTPUT.PUT_LINE('  - Use ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN to reopen');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error closing wallet: ' || SQLERRM);
END;
/

-- ============================================================================
-- Step 8: Open Wallet
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 8: Opening Wallet ===');
  
  -- Open the wallet
  EXECUTE IMMEDIATE 'ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ''YourStrongWalletPassword''';
  
  DBMS_OUTPUT.PUT_LINE('Wallet opened successfully.');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error opening wallet: ' || SQLERRM);
END;
/

-- ============================================================================
-- Summary
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('Key Management Summary');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('1. Master key rotation completed');
  DBMS_OUTPUT.PUT_LINE('2. Key backups created');
  DBMS_OUTPUT.PUT_LINE('3. Wallet backed up');
  DBMS_OUTPUT.PUT_LINE('4. Wallet opened for use');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Best Practices:');
  DBMS_OUTPUT.PUT_LINE('  - Rotate keys every 90 days (or per policy)');
  DBMS_OUTPUT.PUT_LINE('  - Keep at least 3 key backups');
  DBMS_OUTPUT.PUT_LINE('  - Store backups in secure off-site location');
  DBMS_OUTPUT.PUT_LINE('  - Document all key management operations');
  DBMS_OUTPUT.PUT_LINE('  - Test recovery procedures regularly');
  DBMS_OUTPUT.PUT_LINE('========================================');
END;
/
