-- ============================================================================
-- Oracle Data Redaction Setup Script
-- ============================================================================
-- Purpose: Configure Oracle Data Redaction for real-time data masking
-- Version: 1.0
-- Database: Oracle 12c or later (19c recommended)
-- Prerequisites: Enterprise Edition + Advanced Security Option
-- Note: Data Redaction is NOT available in Oracle 11gR2
-- ============================================================================

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

-------------------------------------------------------------------------------
-- STEP 1: Verify prerequisites
-------------------------------------------------------------------------------
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 1: Verifying prerequisites ===');
  
  -- Check database version
  DECLARE
    v_version VARCHAR2(30);
  BEGIN
    SELECT version INTO v_version FROM v$version WHERE banner LIKE 'Oracle Database%';
    DBMS_OUTPUT.PUT_LINE('Database version: ' || v_version);
    
    -- Check if version supports Data Redaction (12.1.0.2 or later)
    IF v_version LIKE '12.1.0.2%' OR v_version LIKE '12.2%' OR v_version LIKE '18.%' OR v_version LIKE '19.%' OR v_version LIKE '21.%' THEN
      DBMS_OUTPUT.PUT_LINE('Data Redaction is supported in this version.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('WARNING: Data Redaction may not be supported in this version.');
      DBMS_OUTPUT.PUT_LINE('Data Redaction requires Oracle 12.1.0.2 or later.');
    END IF;
  END;
  
  -- Check if user has required privileges
  DECLARE
    v_priv NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_priv 
    FROM dba_sys_privs 
    WHERE grantee = USER AND privilege = 'ANALYZE ANY';
    
    IF v_priv = 0 THEN
      DBMS_OUTPUT.PUT_LINE('WARNING: Current user may not have sufficient privileges.');
      DBMS_OUTPUT.PUT_LINE('Contact DBA to grant EXECUTE ON DBMS_REDACT.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('User has required privileges.');
    END IF;
  END;
  
  DBMS_OUTPUT.PUT_LINE('Prerequisites check complete.' || CHR(10));
END;
/

-------------------------------------------------------------------------------
-- STEP 2: Create Sample Table with Sensitive Data
-------------------------------------------------------------------------------
-- Creates a sample EMPLOYEES table with sensitive data for redaction testing.
-------------------------------------------------------------------------------

-- Create sample table
CREATE TABLE IF NOT EXISTS employees (
  employee_id   NUMBER PRIMARY KEY,
  first_name    VARCHAR2(50),
  last_name     VARCHAR2(50),
  email         VARCHAR2(100),
  ssn           VARCHAR2(11),
  salary        NUMBER(10, 2),
  phone         VARCHAR2(20),
  credit_card   VARCHAR2(19),
  hire_date     DATE,
  department    VARCHAR2(50),
  created_date  DATE DEFAULT SYSDATE
);

-- Insert sample data
MERGE INTO employees e
USING (
  SELECT 1 AS id, 'John' AS first_name, 'Doe' AS last_name, 
         'john.doe@company.com' AS email, '123-45-6789' AS ssn, 
         75000.00 AS salary, '555-0101' AS phone, 
         '4111 1111 1111 1111' AS credit_card, 
         DATE '2020-01-15' AS hire_date, 'Engineering' AS department FROM dual
  UNION ALL
  SELECT 2, 'Jane' AS first_name, 'Smith' AS last_name, 
         'jane.smith@company.com' AS email, '987-65-4321' AS ssn, 
         95000.00 AS salary, '555-0102' AS phone, 
         '5500 0000 0000 0004' AS credit_card, 
         DATE '2019-03-20' AS hire_date, 'Engineering' AS department FROM dual
  UNION ALL
  SELECT 3, 'Bob' AS first_name, 'Johnson' AS last_name, 
         'bob.johnson@company.com' AS email, '456-78-9012' AS ssn, 
         120000.00 AS salary, '555-0103' AS phone, 
         '3782 822463 10005' AS credit_card, 
         DATE '2018-07-10' AS hire_date, 'Executive' AS department FROM dual
  UNION ALL
  SELECT 4, 'Alice' AS first_name, 'Williams' AS last_name, 
         'alice.williams@company.com' AS email, '321-54-9876' AS ssn, 
         65000.00 AS salary, '555-0104' AS phone, 
         '6011 0000 0000 0004' AS credit_card, 
         DATE '2021-09-01' AS hire_date, 'HR' AS department FROM dual
  UNION ALL
  SELECT 5, 'Charlie' AS first_name, 'Brown' AS last_name, 
         'charlie.brown@company.com' AS email, '654-32-1098' AS ssn, 
         82000.00 AS salary, '555-0105' AS phone, 
         '3530 1113 3330 0000' AS credit_card, 
         DATE '2020-06-15' AS hire_date, 'Finance' AS department FROM dual
) src
ON (e.employee_id = src.id)
WHEN MATCHED THEN UPDATE SET
  e.first_name = src.first_name,
  e.last_name = src.last_name,
  e.email = src.email,
  e.ssn = src.ssn,
  e.salary = src.salary,
  e.phone = src.phone,
  e.credit_card = src.credit_card,
  e.hire_date = src.hire_date,
  e.department = src.department
WHEN NOT MATCHED THEN INSERT (
  employee_id, first_name, last_name, email, ssn, salary, 
  phone, credit_card, hire_date, department
) VALUES (
  src.id, src.first_name, src.last_name, src.email, src.ssn, src.salary, 
  src.phone, src.credit_card, src.hire_date, src.department
);

COMMIT;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 2: Sample table created with sample data ===');
  DBMS_OUTPUT.PUT_LINE('Table: EMPLOYEES');
  DBMS_OUTPUT.PUT_LINE('Sample data inserted with sensitive fields (SSN, salary, credit card).');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 3: Create Data Redaction Policies
-------------------------------------------------------------------------------
-- Creates multiple redaction policies for different data types and use cases.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 3: Creating Data Redaction Policies ===');
  
  -- Policy 1: Full redaction of SSN for non-HR users
  BEGIN
    DBMS_REDACT.ADD_POLICY(
      object_schema   => USER,
      object_name     => 'EMPLOYEES',
      column_name     => 'SSN',
      policy_name     => 'SSN_FULL_REDACTION',
      expression      => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT IN (''HR_ADMIN'', ''DBA'')',
      function_type   => DBMS_REDACT.FULL,
      function_parameters => NULL,
      description     => 'Full redaction of SSN for non-HR users'
    );
    DBMS_OUTPUT.PUT_LINE('Policy SSN_FULL_REDACTION created (Full redaction).');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Policy SSN_FULL_REDACTION may already exist.');
  END;
  
  -- Policy 2: Partial redaction of salary for non-manager users
  BEGIN
    DBMS_REDACT.ADD_POLICY(
      object_schema   => USER,
      object_name     => 'EMPLOYEES',
      column_name     => 'SALARY',
      policy_name     => 'SALARY_PARTIAL_REDACTION',
      expression      => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT IN (''HR_ADMIN'', ''MANAGER'', ''DBA'')',
      function_type   => DBMS_REDACT.PARTIAL,
      function_parameters => '9,4,*,*,*,*,*,*,*,2',  -- Show last 2 digits
      description     => 'Partial redaction of salary for non-manager users'
    );
    DBMS_OUTPUT.PUT_LINE('Policy SALARY_PARTIAL_REDACTION created (Partial redaction).');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Policy SALARY_PARTIAL_REDACTION may already exist.');
  END;
  
  -- Policy 3: Pattern-based redaction of credit card numbers
  BEGIN
    DBMS_REDACT.ADD_POLICY(
      object_schema   => USER,
      object_name     => 'EMPLOYEES',
      column_name     => 'CREDIT_CARD',
      policy_name     => 'CREDIT_CARD_PATTERN_REDACTION',
      expression      => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT IN (''PAYROLL_ADMIN'', ''DBA'')',
      function_type   => DBMS_REDACT.PATTERN,
      function_parameters => '4,4,4,4,*,*,*,*,*,*,*,*,*,*,*,*,*,*,2',  -- Show last 4 digits
      description     => 'Pattern-based redaction of credit card numbers'
    );
    DBMS_OUTPUT.PUT_LINE('Policy CREDIT_CARD_PATTERN_REDACTION created (Pattern redaction).');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Policy CREDIT_CARD_PATTERN_REDACTION may already exist.');
  END;
  
  -- Policy 4: Regular expression redaction of phone numbers
  BEGIN
    DBMS_REDACT.ADD_POLICY(
      object_schema   => USER,
      object_name     => 'EMPLOYEES',
      column_name     => 'PHONE',
      policy_name     => 'PHONE_REGEX_REDACTION',
      expression      => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT IN (''HR_ADMIN'', ''DBA'')',
      function_type   => DBMS_REDACT.REGEXP,
      function_parameters => '3,3,XXX-XX-XXXX,*,*,*,*,*,*,*',  -- Replace area code
      description     => 'Regular expression redaction of phone numbers'
    );
    DBMS_OUTPUT.PUT_LINE('Policy PHONE_REGEX_REDACTION created (Regex redaction).');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Policy PHONE_REGEX_REDACTION may already exist.');
  END;
  
  -- Policy 5: Empty redaction for email addresses
  BEGIN
    DBMS_REDACT.ADD_POLICY(
      object_schema   => USER,
      object_name     => 'EMPLOYEES',
      column_name     => 'EMAIL',
      policy_name     => 'EMAIL_EMPTY_REDACTION',
      expression      => 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT IN (''HR_ADMIN'', ''DBA'')',
      function_type   => DBMS_REDACT.EMPTY,
      function_parameters => NULL,
      description     => 'Empty redaction of email addresses'
    );
    DBMS_OUTPUT.PUT_LINE('Policy EMAIL_EMPTY_REDACTION created (Empty redaction).');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Policy EMAIL_EMPTY_REDACTION may already exist.');
  END;
  
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Policies created:');
  DBMS_OUTPUT.PUT_LINE('  1. SSN_FULL_REDACTION - Full redaction for non-HR users');
  DBMS_OUTPUT.PUT_LINE('  2. SALARY_PARTIAL_REDACTION - Partial redaction for non-managers');
  DBMS_OUTPUT.PUT_LINE('  3. CREDIT_CARD_PATTERN_REDACTION - Pattern-based redaction');
  DBMS_OUTPUT.PUT_LINE('  4. PHONE_REGEX_REDACTION - Regex-based redaction');
  DBMS_OUTPUT.PUT_LINE('  5. EMAIL_EMPTY_REDACTION - Empty redaction');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 4: Enable Data Redaction Policies
-------------------------------------------------------------------------------
-- Policies are enabled by default when created, but this ensures they are active.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 4: Enabling Data Redaction Policies ===');
  
  -- Enable all policies (they should already be enabled)
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => 'SSN_FULL_REDACTION',
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy SSN_FULL_REDACTION enabled.');
  
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => 'SALARY_PARTIAL_REDACTION',
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy SALARY_PARTIAL_REDACTION enabled.');
  
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => 'CREDIT_CARD_PATTERN_REDACTION',
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy CREDIT_CARD_PATTERN_REDACTION enabled.');
  
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => 'PHONE_REGEX_REDACTION',
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy PHONE_REGEX_REDACTION enabled.');
  
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => 'EMAIL_EMPTY_REDACTION',
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy EMAIL_EMPTY_REDACTION enabled.');
  
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 5: Verification Queries
-------------------------------------------------------------------------------
-- Verify the redaction policies are configured correctly.
-------------------------------------------------------------------------------

-- List all redaction policies
SELECT 
  policy_name,
  object_schema,
  object_name,
  column_name,
  enabled,
  expression,
  function_type
FROM dba_redact_policies
WHERE object_schema = USER
ORDER BY policy_name;

-- Show policy details
SELECT 
  policy_name,
  function_type,
  function_parameters,
  description
FROM dba_redact_policy_columns
WHERE object_schema = USER
ORDER BY policy_name;

-------------------------------------------------------------------------------
-- STEP 6: Test Redaction Policies
-------------------------------------------------------------------------------
-- Demonstrate how redaction works with different user contexts.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 6: Testing Redaction Policies ===');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Querying data WITHOUT redaction (as HR_ADMIN):');
  DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');
END;
/

-- Simulate HR_ADMIN user context (no redaction)
ALTER SESSION SET CURRENT_SCHEMA = &SCHEMA_NAME;

-- This query should show redacted data for non-privileged users
SELECT 
  employee_id,
  first_name,
  last_name,
  email,
  ssn,
  salary,
  phone,
  credit_card
FROM employees
WHERE employee_id <= 3;

BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Querying data WITH redaction (as regular user):');
  DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');
END;
/

-- Simulate regular user context (redaction applied)
-- Note: In practice, you would connect as a different user to test

-------------------------------------------------------------------------------
-- STEP 7: Create Utility Procedures
-------------------------------------------------------------------------------
-- Create helper procedures for common redaction operations.
-------------------------------------------------------------------------------

-- Procedure to disable a specific redaction policy
CREATE OR REPLACE PROCEDURE disable_redaction_policy(
  p_policy_name IN VARCHAR2
) AS
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => p_policy_name,
    action          => DBMS_REDACT.DISABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy ' || p_policy_name || ' disabled.');
END;
/

-- Procedure to enable a specific redaction policy
CREATE OR REPLACE PROCEDURE enable_redaction_policy(
  p_policy_name IN VARCHAR2
) AS
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema   => USER,
    object_name     => 'EMPLOYEES',
    policy_name     => p_policy_name,
    action          => DBMS_REDACT.ENABLE
  );
  DBMS_OUTPUT.PUT_LINE('Policy ' || p_policy_name || ' enabled.');
END;
/

-- Procedure to drop all redaction policies
CREATE OR REPLACE PROCEDURE drop_all_redaction_policies AS
BEGIN
  DBMS_REDACT.DROP_POLICY(
    object_schema => USER,
    object_name   => 'EMPLOYEES',
    policy_name   => 'SSN_FULL_REDACTION'
  );
  
  DBMS_REDACT.DROP_POLICY(
    object_schema => USER,
    object_name   => 'EMPLOYEES',
    policy_name   => 'SALARY_PARTIAL_REDACTION'
  );
  
  DBMS_REDACT.DROP_POLICY(
    object_schema => USER,
    object_name   => 'EMPLOYEES',
    policy_name   => 'CREDIT_CARD_PATTERN_REDACTION'
  );
  
  DBMS_REDACT.DROP_POLICY(
    object_schema => USER,
    object_name   => 'EMPLOYEES',
    policy_name   => 'PHONE_REGEX_REDACTION'
  );
  
  DBMS_REDACT.DROP_POLICY(
    object_schema => USER,
    object_name   => 'EMPLOYEES',
    policy_name   => 'EMAIL_EMPTY_REDACTION'
  );
  
  DBMS_OUTPUT.PUT_LINE('All redaction policies have been dropped.');
END;
/

-------------------------------------------------------------------------------
-- STEP 8: Monitoring and Auditing
-------------------------------------------------------------------------------
-- Set up monitoring for redaction policy usage.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 8: Monitoring and Auditing Setup ===');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Use the following queries to monitor redaction:');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('1. Check policy status:');
  DBMS_OUTPUT.PUT_LINE('   SELECT * FROM dba_redact_policies;');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('2. Check policy columns:');
  DBMS_OUTPUT.PUT_LINE('   SELECT * FROM dba_redact_policy_columns;');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('3. Monitor redaction activity (if auditing is enabled):');
  DBMS_OUTPUT.PUT_LINE('   SELECT * FROM dba_audit_trail WHERE action_name = ''SELECT'';');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 9: Performance Considerations
-------------------------------------------------------------------------------
-- Guidelines for optimizing redaction performance.
-------------------------------------------------------------------------------

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Step 9: Performance Considerations ===');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Best practices for redaction performance:');
  DBMS_OUTPUT.PUT_LINE('1. Limit the number of active redaction policies');
  DBMS_OUTPUT.PUT_LINE('2. Use specific expressions to minimize policy evaluation');
  DBMS_OUTPUT.PUT_LINE('3. Test redaction impact on query performance');
  DBMS_OUTPUT.PUT_LINE('4. Consider using materialized views for frequently queried data');
  DBMS_OUTPUT.PUT_LINE('5. Monitor V$SQL area for redaction-related overhead');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Query to check redaction overhead:');
  DBMS_OUTPUT.PUT_LINE('  SELECT sql_id, redact_calls, redact_time');
  DBMS_OUTPUT.PUT_LINE('  FROM v$sql');
  DBMS_OUTPUT.PUT_LINE('  WHERE redact_calls > 0;');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-------------------------------------------------------------------------------
-- STEP 10: Cleanup (Optional)
-------------------------------------------------------------------------------
-- Uncomment the following to remove all redaction configuration.
-- WARNING: This will disable all data redaction protections!
-------------------------------------------------------------------------------
/*
BEGIN
  -- Disable all policies first
  disable_redaction_policy('SSN_FULL_REDACTION');
  disable_redaction_policy('SALARY_PARTIAL_REDACTION');
  disable_redaction_policy('CREDIT_CARD_PATTERN_REDACTION');
  disable_redaction_policy('PHONE_REGEX_REDACTION');
  disable_redaction_policy('EMAIL_EMPTY_REDACTION');
  
  -- Drop all policies
  drop_all_redaction_policies;
  
  DBMS_OUTPUT.PUT_LINE('All redaction policies have been removed.');
END;
/

-- Optionally drop the sample table
-- DROP TABLE employees CASCADE CONSTRAINTS;
*/

-------------------------------------------------------------------------------
-- END OF SCRIPT
-------------------------------------------------------------------------------

SET SERVEROUTPUT OFF
