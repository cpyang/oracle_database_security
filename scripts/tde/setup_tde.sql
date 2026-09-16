-- ============================================================================
-- setup_tde.sql - Initial TDE Wallet and Key Configuration
-- ============================================================================
-- This script configures the Oracle TDE wallet (encryption wallet) and
-- creates the initial encryption key for Transparent Data Encryption.
--
-- Prerequisites:
--   - Oracle Database 11gR2 or later
--   - TDE wallet directory must be accessible by the Oracle software owner
--   - DBA privileges required
--
-- Usage:
--   sqlplus / as sysdba @setup_tde.sql
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

-- ============================================================================
-- Step 1: Configure the TDE Wallet Location
-- ============================================================================
-- The WALLET_ROOT parameter specifies the base directory for the wallet.
-- In production, use an HSM or dedicated key management server.

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 1: Configuring TDE Wallet Location ===');
  
  -- Set the wallet root directory (adjust path as needed)
  -- In Oracle 12c+, WALLET_ROOT is an auto-login wallet location
  EXECUTE IMMEDIATE 'ALTER SYSTEM SET WALLET_ROOT = ''/opt/oracle/wallets'' SCOPE=SPFILE';
  
  DBMS_OUTPUT.PUT_LINE('Wallet root configured: /opt/oracle/wallets');
  DBMS_OUTPUT.PUT_LINE('NOTE: Database restart required for WALLET_ROOT to take effect.');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Warning: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Manual WALLET_ROOT configuration may be required after restart.');
END;
/

-- ============================================================================
-- Step 2: Create the Encryption Wallet
-- ============================================================================
-- This creates a software wallet. For production, consider using an HSM.

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 2: Creating Encryption Wallet ===');
  
  -- Create the wallet (this will fail if wallet already exists)
  EXECUTE IMMEDIATE 'ADMINISTER KEY MANAGEMENT CREATE KEYSTORE ''/opt/oracle/wallets/tde'' IDENTIFIED BY ''YourStrongWalletPassword''';
  
  DBMS_OUTPUT.PUT_LINE('Wallet created successfully at /opt/oracle/wallets/tde');
  
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -28368 THEN
      DBMS_OUTPUT.PUT_LINE('Wallet already exists. Skipping creation.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('Warning: ' || SQLERRM);
    END IF;
END;
/

-- ============================================================================
-- Step 3: Open the Wallet
-- ============================================================================
-- The wallet must be open to perform encryption/decryption operations.

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 3: Opening the Wallet ===');
  
  -- Open the wallet for this session
  EXECUTE IMMEDIATE 'ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ''YourStrongWalletPassword''';
  
  DBMS_OUTPUT.PUT_LINE('Wallet opened successfully for this session.');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Warning: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Ensure the wallet password is correct.');
END;
/

-- ============================================================================
-- Step 4: Create the Master Encryption Key
-- ============================================================================
-- The master key is used to encrypt the TDE column encryption keys.

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 4: Creating Master Encryption Key ===');
  
  -- Create the master encryption key with a backup
  EXECUTE IMMEDIATE 'ADMINISTER KEY MANAGEMENT CREATE ENCRYPTION KEY IDENTIFIED BY ''YourStrongWalletPassword'' WITH BACKUP USING ''TDE_Master_Key_Backup''';
  
  DBMS_OUTPUT.PUT_LINE('Master encryption key created successfully.');
  DBMS_OUTPUT.PUT_LINE('A backup of the key has been saved.');
  
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -28366 THEN
      DBMS_OUTPUT.PUT_LINE('Master key already exists. Skipping creation.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('Warning: ' || SQLERRM);
    END IF;
END;
/

-- ============================================================================
-- Step 5: Verify Wallet and Key Status
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 5: Verifying Wallet and Key Status ===');
  
  DECLARE
    v_status VARCHAR2(30);
    v_type VARCHAR2(30);
  BEGIN
    SELECT status, wallet_type INTO v_status, v_type 
    FROM v$encryption_wallet;
    
    DBMS_OUTPUT.PUT_LINE('Wallet Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Wallet Type: ' || v_type);
    
    IF v_status = 'OPEN' THEN
      DBMS_OUTPUT.PUT_LINE('SUCCESS: TDE wallet is open and ready for use.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('WARNING: Wallet is not open. Please open it before using TDE.');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Wallet not found. Please complete wallet setup first.');
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error checking status: ' || SQLERRM);
  END;
END;
/

-- ============================================================================
-- Step 6: Create Auto-Login Wallet (Optional but Recommended)
-- ============================================================================
-- Auto-login wallet allows the database to open the wallet automatically
-- on startup without manual intervention.

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 6: Creating Auto-Login Wallet (Optional) ===');
  
  -- Note: This requires OS-level command execution
  DBMS_OUTPUT.PUT_LINE('To create auto-login wallet, run the following OS command:');
  DBMS_OUTPUT.PUT_LINE('  mkstore -wrl /opt/oracle/wallets/tde -createCredential');
  DBMS_OUTPUT.PUT_LINE('Or use orapki for newer Oracle versions:');
  DBMS_OUTPUT.PUT_LINE('  orapki wallet create -wallet /opt/oracle/wallets/tde -auto_login');
  
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Warning: ' || SQLERRM);
END;
/

-- ============================================================================
-- Summary
-- ============================================================================

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('TDE Wallet Setup Summary');
  DBMS_OUTPUT.PUT_LINE('========================================');
  DBMS_OUTPUT.PUT_LINE('1. Wallet location: /opt/oracle/wallets/tde');
  DBMS_OUTPUT.PUT_LINE('2. Wallet status: Check v$encryption_wallet');
  DBMS_OUTPUT.PUT_LINE('3. Next steps: Configure column encryption or tablespace encryption');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('IMPORTANT:');
  DBMS_OUTPUT.PUT_LINE('- Store the wallet password securely');
  DBMS_OUTPUT.PUT_LINE('- Backup the wallet and master key');
  DBMS_OUTPUT.PUT_LINE('- Consider using HSM for production environments');
  DBMS_OUTPUT.PUT_LINE('========================================');
END;
/
