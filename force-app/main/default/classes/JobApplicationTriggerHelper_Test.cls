@isTest
private class JobApplicationTriggerHelper_Test {

    // Test setup method to create reusable test data
    @testSetup
    static void makeData(){
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;

        Contact testContact = new Contact(FirstName='John', LastName='Doe', AccountId=testAccount.Id);
        insert testContact;
        
        // Set a different initial salary to ensure the update test triggers a change.
        Job_Application__c testJobApp = new Job_Application__c(
            Status_Pckl__c = 'Saved',
            Salary_Curr__c = 60000, 
            Tax_Filing_Status_Pckl__c = 'Single',
            Deduction_Type_Pckl__c = 'Standard Deduction'
        );
        insert testJobApp;
    }

    // Test method for creating a task when the status changes
    @isTest
    static void testCreateTaskOnStatusChange() {
        Job_Application__c jobApp = [SELECT Id, Status_Pckl__c FROM Job_Application__c LIMIT 1];
        
        jobApp.Status_Pckl__c = 'Applying';
        Test.startTest();
        update jobApp;
        Test.stopTest();

        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :jobApp.Id];
        System.assertEquals(1, createdTasks.size(), 'A task should be created when the status changes.');
    }

    // Test method to ensure no task is created if the status doesn't change
    @isTest
    static void testNoTaskCreatedWithoutStatusChange() {
        Job_Application__c jobApp = [SELECT Id, Status_Pckl__c FROM Job_Application__c LIMIT 1];
        
        // Update a field that does not trigger task creation
        jobApp.Taxes_Withheld_Curr__c = 1000;
        Test.startTest();
        update jobApp;
        Test.stopTest();

        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :jobApp.Id];
        System.assertEquals(0, createdTasks.size(), 'A task should not be created if the status does not change.');
    }

    // Test method for setting the primary contact
    @isTest
    static void testSetPrimaryContact() {
        Job_Application__c jobApp = [SELECT Id FROM Job_Application__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        // Create a Job_Application_Contact__c record to trigger the logic
        Job_Application_Contact__c jac = new Job_Application_Contact__c(
            Job_Application_Id__c = jobApp.Id,
            Contact_Id__c = con.Id
        );
        
        Test.startTest();
        insert jac;
        Test.stopTest();

        Job_Application__c updatedJobApp = [SELECT Primary_Contact_Id__c FROM Job_Application__c WHERE Id = :jobApp.Id];
        System.assertEquals(con.Id, updatedJobApp.Primary_Contact_Id__c, 'The primary contact should be set.');
    }

    // Test method for setting the annual gross income on insert
    @isTest
    static void testSetAnnualGrossIncome() {
        Job_Application__c jobApp = [SELECT Annual_Gross_Income_Curr__c, Salary_Curr__c FROM Job_Application__c LIMIT 1];
        System.assertEquals(jobApp.Salary_Curr__c, jobApp.Annual_Gross_Income_Curr__c, 'Annual Gross Income should be set from Salary on insert.');
    }

    // Test method for all income and take-home pay calculations
    @isTest
    static void testTakeHomePayCalculations() {
        // 1. Setup: Get the record created in @testSetup
        Job_Application__c jobApp = [SELECT Id FROM Job_Application__c LIMIT 1];
        
        // 2. Execution: Update the salary to trigger the calculation logic
        jobApp.Salary_Curr__c = 100000;
        Test.startTest();
        update jobApp;
        Test.stopTest();
        
        // 3. Verification: Query all the calculated fields
        Job_Application__c result = [
            SELECT 
                Taxable_Income_Curr__c, Estimated_Federal_Tax_Curr__c, 
                Social_Security_Tax_Curr__c, Medicare_Tax_Curr__c,
                Take_Home_Pay_Yearly_Curr__c, Take_Home_Pay_Monthly_Curr__c
            FROM Job_Application__c 
            WHERE Id = :jobApp.Id
        ];
        
        // --- Assertions for $100,000 Salary, Single, Standard Deduction ---
        System.assertEquals(85000, result.Taxable_Income_Curr__c, 'Taxable Income is incorrect.');
        System.assertEquals(13614.00, result.Estimated_Federal_Tax_Curr__c, 'Estimated Federal Tax is incorrect.');
        System.assertEquals(6200.00, result.Social_Security_Tax_Curr__c, 'Social Security Tax is incorrect.');
        System.assertEquals(1450.00, result.Medicare_Tax_Curr__c, 'Medicare Tax is incorrect.');
        System.assertEquals(78736.00, result.Take_Home_Pay_Yearly_Curr__c, 'Yearly Take-Home Pay is incorrect.');
        System.assertEquals(6561.33, result.Take_Home_Pay_Monthly_Curr__c.setScale(2), 'Monthly Take-Home Pay is incorrect.');
    }

    // Test for income over the Social Security limit
    @isTest
    static void testCalculations_OverSocialSecurityLimit() {
        // 1. Setup
        Job_Application__c jobApp = [SELECT Id FROM Job_Application__c LIMIT 1];
        
        // 2. Execution
        jobApp.Salary_Curr__c = 200000; // Salary over the $168,600 limit
        jobApp.Tax_Filing_Status_Pckl__c = 'Head of Household';
        Test.startTest();
        update jobApp;
        Test.stopTest();
        
        // 3. Verification
        Job_Application__c result = [
            SELECT Social_Security_Tax_Curr__c
            FROM Job_Application__c 
            WHERE Id = :jobApp.Id
        ];
        
        // Social Security should be calculated on the limit, not the full salary: 168,600 * 6.2% = 10,453.20
        System.assertEquals(10453.20, result.Social_Security_Tax_Curr__c, 'Social Security tax should be capped at the limit.');
    }

    // **NEW TEST**: Test calculations for 'Married, filing jointly' to increase coverage.
    @isTest
    static void testCalculations_MarriedFilingJointly() {
        // 1. Setup
        Job_Application__c jobApp = [SELECT Id FROM Job_Application__c LIMIT 1];
        
        // 2. Execution: Update salary and filing status
        jobApp.Salary_Curr__c = 150000;
        jobApp.Tax_Filing_Status_Pckl__c = 'Married, filing jointly';
        Test.startTest();
        update jobApp;
        Test.stopTest();
        
        // 3. Verification
        Job_Application__c result = [
            SELECT Taxable_Income_Curr__c, Estimated_Federal_Tax_Curr__c
            FROM Job_Application__c 
            WHERE Id = :jobApp.Id
        ];
        
        // Taxable Income: 150,000 - 30,000 (standard deduction) = 120,000
        System.assertEquals(120000, result.Taxable_Income_Curr__c, 'Taxable income for Married/Jointly is incorrect.');
        
        // **FIX**: Corrected the expected tax calculation.
        // Federal Tax on 120,000 = 16,228
        System.assertEquals(16228.00, result.Estimated_Federal_Tax_Curr__c, 'Federal tax for Married/Jointly is incorrect.');
    }
}
