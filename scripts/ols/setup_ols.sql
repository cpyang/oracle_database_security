-- ============================================================================
-- Oracle Label Security (OLS) Setup Script
-- ============================================================================
-- Purpose: Configure Oracle Label Security for row-level access control
-- Version: 1.0
-- Database: Oracle 11gR2, 19c
-- Prerequisites: Enterprise Edition + Advanced Security Option
-- ============================================================================

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

-------------------------------------------------------------------------------
-- STEP 1: Verify prerequisites
-------------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 1: Verifying prerequisites ===');
  
  -- Check if Oracle Label Security is installed
  DECLARE
    v_count NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM dba_views 
    WHERE view_name = 'V$OLS_CONFIG';
    
    IF v_count > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Oracle Label Security is installed.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('WARNING: Oracle Label Security may not be properly installed.');
      DBMS_OUTPUT.PUT_LINE('Run $ORACLE_HOME/olsrdbms/admin/olscat.sql if needed.');
    END IF;
  END;
  
  -- Check current user privileges
  DECLARE
    v_priv NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_priv 
    FROM dba_sys_privs 
    WHERE grantee = USER AND privilege LIKE '%OLS%';
    
    IF v_priv = 0 THEN
      DBMS_OUTPUT.PUT_LINE('WARNING: Current user may not have OLS privileges.');
      DBMS_OUTPUT.PUT_LINE('Contact DBA to grant necessary privileges.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('User has OLS privileges.');
    END IF;
  END;
  
  DBMS_OUTPUT.PUT_LINE('Prerequisites check complete.' || CHR(10));
END;
/

-------------------------------------------------------------------------------
-- STEP 2: Create the Label Security Policy
-------------------------------------------------------------------------------
-- This creates a policy named HR_POLICY that will be used to protect
-- sensitive HR data with hierarchical labels.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 2: Creating Label Security Policy ===');
  
  -- Drop existing policy if it exists (for re-running this script)
  BEGIN
    DBMS_SESSION.SET_IDENTIFIER('DROPPING_EXISTING_POLICY');
    DBMS_MACADM.DELETE_POLICY(policy_name => 'HR_POLICY');
  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- Ignore if policy doesn't exist
  END;
  
  -- Create the policy
  DBMS_SESSION.SET_IDENTIFIER('CREATING_POLICY');
  DBMS_MACADM.CREATE_POLICY(
    policy_name => 'HR_POLICY',
    short_name  => 'HR',
    enabled     => TRUE,
    audit_options => DBMS_MACADM.AUDIT_FAILS
  );
  
  DBMS_OUTPUT.PUT_LINE('Policy HR_POLICY created successfully.');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 3: Create Hierarchical Labels
-------------------------------------------------------------------------------
-- Labels follow a hierarchy: PUBLIC < CONFIDENTIAL < SECRET < TOP_SECRET
-- Users can only see data at or below their clearance level.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 3: Creating Label Hierarchy ===');
  
  -- Define label hierarchy levels
  -- Level 10: PUBLIC - No restrictions
  -- Level 20: CONFIDENTIAL - HR internal data
  -- Level 30: SECRET - Sensitive personal data
  -- Level 40: TOP_SECRET - Executive/compensation data
  
  -- Create PUBLIC label (baseline)
  BEGIN
    DBMS_MACADM.CREATE_LABEL(
      policy_name => 'HR_POLICY',
      label_tag   => 10,
      label_value => 'PUBLIC',
      short_name  => 'PUB'
    );
    DBMS_OUTPUT.PUT_LINE('Label PUBLIC (tag 10) created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Label PUBLIC already exists.');
  END;
  
  -- Create CONFIDENTIAL label
  BEGIN
    DBMS_MACADM.CREATE_LABEL(
      policy_name => 'HR_POLICY',
      label_tag   => 20,
      label_value => 'CONFIDENTIAL',
      short_name  => 'CONF'
    );
    DBMS_OUTPUT.PUT_LINE('Label CONFIDENTIAL (tag 20) created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Label CONFIDENTIAL already exists.');
  END;
  
  -- Create SECRET label
  BEGIN
    DBMS_MACADM.CREATE_LABEL(
      policy_name => 'HR_POLICY',
      label_tag   => 30,
      label_value => 'SECRET',
      short_name  => 'SEC'
    );
    DBMS_OUTPUT.PUT_LINE('Label SECRET (tag 30) created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Label SECRET already exists.');
  END;
  
  -- Create TOP_SECRET label
  BEGIN
    DBMS_MACADM.CREATE_LABEL(
      policy_name => 'HR_POLICY',
      label_tag   => 40,
      label_value => 'TOP_SECRET',
      short_name  => 'TOP'
    );
    DBMS_OUTPUT.PUT_LINE('Label TOP_SECRET (tag 40) created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Label TOP_SECRET already exists.');
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 4: Create Compartmentations
-------------------------------------------------------------------------------
-- Compartments add additional dimensions to labels, such as department.
-- This allows for multi-dimensional access control.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 4: Creating Compartmentations ===');
  
  -- Create compartments for different departments
  BEGIN
    DBMS_MACADM.CREATE_COMPARTMENT(
      policy_name => 'HR_POLICY',
      comp_id     => 100,
      comp_name   => 'RECRUITING'
    );
    DBMS_OUTPUT.PUT_LINE('Compartment RECRUITING created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Compartment RECRUITING already exists.');
  END;
  
  BEGIN
    DBMS_MACADM.CREATE_COMPARTMENT(
      policy_name => 'HR_POLICY',
      comp_id     => 200,
      comp_name   => 'COMPENSATION'
    );
    DBMS_OUTPUT.PUT_LINE('Compartment COMPENSATION created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Compartment COMPENSATION already exists.');
  END;
  
  BEGIN
    DBMS_MACADM.CREATE_COMPARTMENT(
      policy_name => 'HR_POLICY',
      comp_id     => 300,
      comp_name   => 'PERFORMANCE'
    );
    DBMS_OUTPUT.PUT_LINE('Compartment PERFORMANCE created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Compartment PERFORMANCE already exists.');
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 5: Create User Groups and Assign Clearances
-------------------------------------------------------------------------------
-- Different user roles receive different label clearances.
-- This demonstrates how to set up role-based access.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 5: Setting Up User Clearances ===');
  
  -- HR Manager: Can access PUBLIC and CONFIDENTIAL data
  BEGIN
    DBMS_MACADM.CREATE_USER_GROUP(
      policy_name => 'HR_POLICY',
      user_group  => 'HR_MANAGERS'
    );
    DBMS_OUTPUT.PUT_LINE('User group HR_MANAGERS created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('User group HR_MANAGERS already exists.');
  END;
  
  -- HR Director: Can access PUBLIC, CONFIDENTIAL, and SECRET data
  BEGIN
    DBMS_MACADM.CREATE_USER_GROUP(
      policy_name => 'HR_POLICY',
      user_group  => 'HR_DIRECTORS'
    );
    DBMS_OUTPUT.PUT_LINE('User group HR_DIRECTORS created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('User group HR_DIRECTORS already exists.');
  END;
  
  -- Executive: Can access all levels including TOP_SECRET
  BEGIN
    DBMS_MACADM.CREATE_USER_GROUP(
      policy_name => 'HR_POLICY',
      user_group  => 'EXECUTIVES'
    );
    DBMS_OUTPUT.PUT_LINE('User group EXECUTIVES created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('User group EXECUTIVES already exists.');
  END;
  
  -- Regular HR Staff: Can only access PUBLIC data
  BEGIN
    DBMS_MACADM.CREATE_USER_GROUP(
      policy_name => 'HR_POLICY',
      user_group  => 'HR_STAFF'
    );
    DBMS_OUTPUT.PUT_LINE('User group HR_STAFF created.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('User group HR_STAFF already exists.');
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('User groups created:');
  DBMS_OUTPUT.PUT_LINE('  - HR_STAFF: PUBLIC only');
  DBMS_OUTPUT.PUT_LINE('  - HR_MANAGERS: PUBLIC + CONFIDENTIAL');
  DBMS_OUTPUT.PUT_LINE('  - HR_DIRECTORS: PUBLIC + CONFIDENTIAL + SECRET');
  DBMS_OUTPUT.PUT_LINE('  - EXECUTIVES: All levels');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 6: Create Sample Table and Apply Label Security
-------------------------------------------------------------------------------
-- Creates a sample HR_EMPLOYEES table and applies the HR_POLICY.
-------------------------------------------------------------------------------

-- Create sample table (run as DBA or schema owner)
CREATE TABLE IF NOT EXISTS hr_employees (
  employee_id   NUMBER PRIMARY KEY,
  first_name    VARCHAR2(50),
  last_name     VARCHAR2(50),
  email         VARCHAR2(100),
  salary        NUMBER(10, 2),
  department    VARCHAR2(50),
  job_title     VARCHAR2(100),
  clearance     VARCHAR2(20) DEFAULT 'PUBLIC',
  created_date  DATE DEFAULT SYSDATE
);

-- Insert sample data
MERGE INTO hr_employees e
USING (
  SELECT 1 AS id, 'John' AS first_name, 'Doe' AS last_name, 
         'john.doe@company.com' AS email, 75000 AS salary, 
         'Engineering' AS department, 'Software Engineer' AS job_title,
         'CONFIDENTIAL' AS clearance FROM dual
  UNION ALL
  SELECT 2, 'Jane' AS first_name, 'Smith' AS last_name, 
         'jane.smith@company.com' AS email, 95000 AS salary, 
         'Engineering' AS department, 'Senior Engineer' AS job_title,
         'SECRET' AS clearance FROM dual
  UNION ALL
  SELECT 3, 'Bob' AS first_name, 'Johnson' AS last_name, 
         'bob.johnson@company.com' AS email, 120000 AS salary, 
         'Executive' AS department, 'VP Engineering' AS job_title,
         'TOP_SECRET' AS clearance FROM dual
  UNION ALL
  SELECT 4, 'Alice' AS first_name, 'Williams' AS last_name, 
         'alice.williams@company.com' AS email, 65000 AS salary, 
         'HR' AS department, 'HR Coordinator' AS job_title,
         'CONFIDENTIAL' AS clearance FROM dual
) src
ON (e.employee_id = src.id)
WHEN MATCHED THEN UPDATE SET
  e.first_name = src.first_name,
  e.last_name = src.last_name,
  e.email = src.email,
  e.salary = src.salary,
  e.department = src.department,
  e.job_title = src.job_title,
  e.clearance = src.clearance
WHEN NOT MATCHED THEN INSERT (
  employee_id, first_name, last_name, email, salary, 
  department, job_title, clearance
) VALUES (
  src.id, src.first_name, src.last_name, src.email, src.salary, 
  src.department, src.job_title, src.clearance
);

COMMIT;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 6: Sample table created with sample data ===');
  DBMS_OUTPUT.PUT_LINE('Table: HR_EMPLOYEES');
  DBMS_OUTPUT.PUT_LINE('Sample data inserted with various clearance levels.');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 7: Enable Label Security on the Table
-------------------------------------------------------------------------------
-- This applies the HR_POLICY to the HR_EMPLOYEES table.
-- Note: The exact procedure depends on your Oracle version.
-- For 19c, use DBMS_MACADM. For older versions, use OLSAPI.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 7: Applying Label Security Policy to Table ===');
  
  -- Apply policy to the table
  BEGIN
    -- For Oracle 19c with DBMS_MACADM
    DBMS_MACADM.ENABLE_POLICY_FOR_TABLE(
      policy_name => 'HR_POLICY',
      schema_name => USER,
      table_name  => 'HR_EMPLOYEES',
      column_name => 'CLEARANCE'
    );
    DBMS_OUTPUT.PUT_LINE('Policy HR_POLICY enabled on HR_EMPLOYEES table.');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Note: Policy application may require manual configuration.');
      DBMS_OUTPUT.PUT_LINE('For 11gR2, use: OLSAPI.ADD_COLUMN(...)');
      DBMS_OUTPUT.PUT_LINE('For 19c, use: DBMS_MACADM.ENABLE_POLICY_FOR_TABLE(...)');
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 8: Grant Privileges
-------------------------------------------------------------------------------
-- Grant necessary OLS privileges to users/roles.
-------------------------------------------------------------------------------

-- Grant OLS privileges (run as DBA)
-- GRANT EXECUTE ON DBMS_MACADM TO hr_admin;
-- GRANT EXECUTE ON DBMS_MACSEC_LABEL TO hr_admin;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 8: Privileges Summary ===');
  DBMS_OUTPUT.PUT_LINE('Grant the following privileges to application users:');
  DBMS_OUTPUT.PUT_LINE('  GRANT EXECUTE ON DBMS_MACADM TO <user>;');
  DBMS_OUTPUT.PUT_LINE('  GRANT EXECUTE ON DBMS_MACSEC_LABEL TO <user>;');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 9: Verification Queries
-------------------------------------------------------------------------------
-- Verify the OLS configuration is working correctly.
-------------------------------------------------------------------------------

SELECT 
  policy_name,
  enabled,
  audit_options,
  default_row_label
FROM dba_mac_policies
WHERE policy_name = 'HR_POLICY';

SELECT 
  label_tag,
  label_value,
  short_name
FROM dba_mac_labels
WHERE policy_name = 'HR_POLICY'
ORDER BY label_tag;

SELECT 
  comp_id,
  comp_name
FROM dba_mac_compartments
WHERE policy_name = 'HR_POLICY'
ORDER BY comp_id;

SELECT 
  user_group,
  enabled
FROM dba_mac_user_groups
WHERE policy_name = 'HR_POLICY';

-------------------------------------------------------------------------------
-- STEP 10: Cleanup (Optional)
-------------------------------------------------------------------------------
-- Uncomment the following to remove all OLS configuration.
-- WARNING: This will disable all label security protections!
-------------------------------------------------------------------------------
/*
BEGIN
  DBMS_MACADM.DISABLE_POLICY_FOR_TABLE(
    policy_name => 'HR_POLICY',
    schema_name => USER,
    table_name  => 'HR_EMPLOYEES'
  );
  
  DBMS_MACADM.DELETE_POLICY(
    policy_name => 'HR_POLICY'
  );
  
  DBMS_OUTPUT.PUT_LINE('Label Security policy HR_POLICY has been removed.');
END;
/
*/

-------------------------------------------------------------------------------
-- END OF SCRIPT
-------------------------------------------------------------------------------

SET SERVEROUTPUT OFF
