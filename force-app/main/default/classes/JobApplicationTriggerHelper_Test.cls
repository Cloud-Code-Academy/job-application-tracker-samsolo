@isTest
private class JobApplicationTriggerHelper_Test {

    // Test setup method to create reusable test data
    @testSetup
    static void makeData(){
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;

        Contact testContact = new Contact(FirstName='John', LastName='Doe', AccountId=testAccount.Id);
        insert testContact;
        
        Job_Application__c testJobApp = new Job_Application__c(
            Status_Pckl__c = 'Saved', // Using your picklist value
            Salary_Curr__c = 60000,
            Tax_Filing_Status_Pckl__c = 'Single'
        );
        insert testJobApp;
    }

    // Test method for creating a task when the status changes
    @isTest
    static void testCreateTaskOnStatusChange() {
        Job_Application__c jobApp = [SELECT Id, Status_Pckl__c FROM Job_Application__c LIMIT 1];
        
        jobApp.Status_Pckl__c = 'Applying'; // Using your picklist value
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
        
        jobApp.Salary_Curr__c = 70000;
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

    // Test method for income calculation processing ('Head of Household')
    @isTest
    static void testProcessIncomeCalculations() {
        Job_Application__c jobApp = [SELECT Id, Salary_Curr__c FROM Job_Application__c LIMIT 1];
        
        jobApp.Salary_Curr__c = 80000;
        jobApp.Tax_Filing_Status_Pckl__c = 'Head of Household';

        Test.startTest();
        update jobApp;
        Test.stopTest();
        
        Job_Application__c updatedJobApp = [
            SELECT Annual_Gross_Income_Curr__c, Taxable_Income_Curr__c, Estimated_Federal_Tax_Curr__c 
            FROM Job_Application__c WHERE Id = :jobApp.Id
        ];
        
        System.assertEquals(80000, updatedJobApp.Annual_Gross_Income_Curr__c, 'Annual Gross Income should be updated.');
        System.assertEquals(57500, updatedJobApp.Taxable_Income_Curr__c, 'Taxable Income should be recalculated.');
        System.assertEquals(6560, updatedJobApp.Estimated_Federal_Tax_Curr__c, 'Estimated Federal Tax should be recalculated.');
    }

    // New test for 'Married, filing jointly' with Itemized Deductions
    @isTest
    static void testIncomeCalc_MarriedJointly_Itemized() {
        Job_Application__c jobApp = new Job_Application__c(Status_Pckl__c = 'Saved', Salary_Curr__c = 150000, Tax_Filing_Status_Pckl__c = 'Single');
        insert jobApp;

        // Query all fields needed for comparison in the helper method
        Job_Application__c oldJobApp = [
            SELECT Id, Annual_Gross_Income_Curr__c, Salary_Curr__c, Tax_Filing_Status_Pckl__c,
                   Deduction_Type_Pckl__c, Itemized_Deductions_Curr__c, Taxes_Withheld_Curr__c
            FROM Job_Application__c WHERE Id = :jobApp.Id
        ];

        jobApp.Tax_Filing_Status_Pckl__c = 'Married, filing jointly';
        jobApp.Deduction_Type_Pckl__c = 'Itemized Deductions';
        jobApp.Itemized_Deductions_Curr__c = 40000;

        Test.startTest();
        JobApplicationTriggerHelper.processIncomeCalculations(new List<Job_Application__c>{ jobApp }, new Map<Id, Job_Application__c>{ oldJobApp.Id => oldJobApp });
        Test.stopTest();

        System.assertEquals(110000, jobApp.Taxable_Income_Curr__c, 'Taxable income for Married/Itemized is incorrect.');
        System.assertEquals(12723, jobApp.Estimated_Federal_Tax_Curr__c.setScale(0, RoundingMode.HALF_UP), 'Estimated tax for Married/Itemized is incorrect.');
    }

    // New test for the edge case where taxable income could be negative
    @isTest
    static void testIncomeCalc_NegativeTaxableIncome() {
        Job_Application__c jobApp = new Job_Application__c(Status_Pckl__c = 'Saved', Salary_Curr__c = 20000, Tax_Filing_Status_Pckl__c = 'Married, filing jointly');
        insert jobApp;

        // Query all fields needed for comparison in the helper method
        Job_Application__c oldJobApp = [
            SELECT Id, Annual_Gross_Income_Curr__c, Salary_Curr__c, Tax_Filing_Status_Pckl__c,
                   Deduction_Type_Pckl__c, Itemized_Deductions_Curr__c, Taxes_Withheld_Curr__c
            FROM Job_Application__c WHERE Id = :jobApp.Id
        ];

        jobApp.Deduction_Type_Pckl__c = 'Standard Deduction';

        Test.startTest();
        JobApplicationTriggerHelper.processIncomeCalculations(new List<Job_Application__c>{ jobApp }, new Map<Id, Job_Application__c>{ oldJobApp.Id => oldJobApp });
        Test.stopTest();

        System.assertEquals(0, jobApp.Taxable_Income_Curr__c, 'Taxable income should be 0 when deductions exceed income.');
        System.assertEquals(0, jobApp.Estimated_Federal_Tax_Curr__c, 'Estimated tax should be 0 when taxable income is 0.');
    }

    // New test for the 'Married, filing separately' filing status
    @isTest
    static void testIncomeCalc_MarriedSeparately() {
        Job_Application__c jobApp = new Job_Application__c(Status_Pckl__c = 'Saved', Salary_Curr__c = 90000, Tax_Filing_Status_Pckl__c = 'Single');
        insert jobApp;

        // Query all fields needed for comparison in the helper method
        Job_Application__c oldJobApp = [
            SELECT Id, Annual_Gross_Income_Curr__c, Salary_Curr__c, Tax_Filing_Status_Pckl__c,
                   Deduction_Type_Pckl__c, Itemized_Deductions_Curr__c, Taxes_Withheld_Curr__c
            FROM Job_Application__c WHERE Id = :jobApp.Id
        ];

        jobApp.Tax_Filing_Status_Pckl__c = 'Married, filing separately';
        jobApp.Deduction_Type_Pckl__c = 'Standard Deduction';

        Test.startTest();
        JobApplicationTriggerHelper.processIncomeCalculations(new List<Job_Application__c>{ jobApp }, new Map<Id, Job_Application__c>{ oldJobApp.Id => oldJobApp });
        Test.stopTest();

        System.assertEquals(75000, jobApp.Taxable_Income_Curr__c, 'Taxable income for Married/Separately is incorrect.');
        System.assertEquals(11414, jobApp.Estimated_Federal_Tax_Curr__c.setScale(0, RoundingMode.HALF_UP), 'Estimated tax for Married/Separately is incorrect.');
    }
}