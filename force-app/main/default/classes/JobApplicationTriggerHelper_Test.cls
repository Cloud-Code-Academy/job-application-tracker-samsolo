@isTest
private class JobApplicationTriggerHelper_Test {

    // Test setup method to create reusable test data
    @testSetup
    static void makeData(){
        // Create a test Account
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;

        // Create a test Contact
        Contact testContact = new Contact(
            FirstName='John',
            LastName='Doe',
            AccountId=testAccount.Id
        );
        insert testContact;

        // Create a test Job Application
        Job_Application__c testJobApp = new Job_Application__c(
            Status_Pckl__c = 'Saved',
            Salary_Curr__c = 60000,
            Tax_Filing_Status_Pckl__c = 'Single'
        );
        insert testJobApp;
    }

    // Test method for creating a task when the status changes
    @isTest
    static void testCreateTaskOnStatusChange() {
        Job_Application__c jobApp = [SELECT Id, Status_Pckl__c FROM Job_Application__c LIMIT 1];
        
        // Update the status
        jobApp.Status_Pckl__c = 'In Progress';
        Test.startTest();
        update jobApp;
        Test.stopTest();

        // Verify that a new task was created
        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :jobApp.Id];
        System.assertEquals(1, createdTasks.size(), 'A task should be created when the status changes.');
    }

    // Test method to ensure no task is created if the status doesn't change
    @isTest
    static void testNoTaskCreatedWithoutStatusChange() {
        Job_Application__c jobApp = [SELECT Id, Status_Pckl__c FROM Job_Application__c LIMIT 1];
        
        // Update a different field
        jobApp.Salary_Curr__c = 70000;
        Test.startTest();
        update jobApp;
        Test.stopTest();

        // Verify that no new task was created
        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :jobApp.Id];
        System.assertEquals(0, createdTasks.size(), 'A task should not be created if the status does not change.');
    }

    // Test method for setting the primary contact
    @isTest
    static void testSetPrimaryContact() {
        Job_Application__c jobApp = [SELECT Id FROM Job_Application__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        // Create a Job_Application_Contact__c record
        Job_Application_Contact__c jac = new Job_Application_Contact__c(
            Job_Application_Id__c = jobApp.Id,
            Contact_Id__c = con.Id
        );
        
        Test.startTest();
        insert jac;
        Test.stopTest();

        // Verify that the primary contact was set
        Job_Application__c updatedJobApp = [SELECT Primary_Contact_Id__c FROM Job_Application__c WHERE Id = :jobApp.Id];
        System.assertEquals(con.Id, updatedJobApp.Primary_Contact_Id__c, 'The primary contact should be set.');
    }

    // Test method for setting the annual gross income on insert
    @isTest
    static void testSetAnnualGrossIncome() {
        Job_Application__c jobApp = [SELECT Annual_Gross_Income_Curr__c, Salary_Curr__c FROM Job_Application__c LIMIT 1];

        // Verify that the annual gross income is set from the salary
        System.assertEquals(jobApp.Salary_Curr__c, jobApp.Annual_Gross_Income_Curr__c, 'Annual Gross Income should be set from Salary on insert.');
    }

    // Test method for income calculation processing
    @isTest
    static void testProcessIncomeCalculations() {
        Job_Application__c jobApp = [SELECT Id, Salary_Curr__c FROM Job_Application__c LIMIT 1];
        
        // Update the salary and filing status
        jobApp.Salary_Curr__c = 80000;
        jobApp.Tax_Filing_Status_Pckl__c = 'Head of Household';

        Test.startTest();
        update jobApp;
        Test.stopTest();
        
        // Verify the calculated fields
        Job_Application__c updatedJobApp = [
            SELECT Annual_Gross_Income_Curr__c, Taxable_Income_Curr__c, Estimated_Federal_Tax_Curr__c 
            FROM Job_Application__c 
            WHERE Id = :jobApp.Id
        ];
        
        System.assertEquals(80000, updatedJobApp.Annual_Gross_Income_Curr__c, 'Annual Gross Income should be updated.');
        System.assertEquals(57500, updatedJobApp.Taxable_Income_Curr__c, 'Taxable Income should be recalculated.');
        System.assertEquals(6822, updatedJobApp.Estimated_Federal_Tax_Curr__c, 'Estimated Federal Tax should be recalculated.');
    }
}