public with sharing class JobApplicationTriggerHelper {

    // CREATE TASK METHOD: Create a new task when the status of a Job Application changes
    public static void createTask(List<Job_Application__c> jobApps, Map<Id, Job_Application__c> oldJobApps) {
        
        List<Task> tasksToCreate = new List<Task>();
        
        for (Job_Application__c jobApp : jobApps) {
            Job_Application__c oldJobApp = oldJobApps.get(jobApp.Id);
            if ( jobApp != null && oldJobApp != null && jobApp.Status_Pckl__c != oldJobApp.Status_Pckl__c ) {
                Task newTask = new Task(
                    ActivityDate = Date.today().addDays(3), 
                    WhatId = jobApp.Id, 
                    Subject = jobApp.Status_Pckl__c + ': Next Steps', 
                    Priority = 'Normal');
                tasksToCreate.add(newTask);
            }
        }

        if ( !tasksToCreate.isEmpty() ) {
            insert tasksToCreate;
        }
    }

    // SET PRIMARY CONTACT METHOD: Sets the Job Application Primary Contact
    public static void setPrimaryContactOnFirstRelation(List<Job_Application__c> jobApps) {

       // Collect Job Application IDs that need a primary contact
       Set<Id> jobAppIds = new Set<Id>();
        for (Job_Application__c jobApp : jobApps) {
            if (jobApp.Primary_Contact_Id__c == null && jobApp.Number_of_Related_Contacts_Rollup__c > 0) {
                jobAppIds.add(jobApp.Id);
            }
        }
        
        // If no Job Applications need a primary contact, exit early
        if (jobAppIds.isEmpty()) {
            return;
        }

        // Query for Job Application Contacts related to the identified Job Applications
        List<Job_Application_Contact__c> jobApplicationContacts = [
            SELECT Job_Application_Id__c, Contact_Id__c
            FROM Job_Application_Contact__c 
            WHERE Job_Application_Id__c IN :jobAppIds 
            ORDER BY CreatedDate ASC
        ];

        // Create a map to hold the first contact for each Job Application
        Map<Id, Id> primaryContactMap = new Map<Id, Id>();
        for (Job_Application_Contact__c jac : jobApplicationContacts) {
            if(!primaryContactMap.containsKey(jac.Job_Application_Id__c)) {
                primaryContactMap.put(jac.Job_Application_Id__c, jac.Contact_Id__c);
            }
        }

        // Update the Job Applications with the primary contact
        // If a Job Application already has a primary contact, it will not be overwritten
        for (Job_Application__c jobApp : jobApps) {
            if (primaryContactMap.containsKey(jobApp.Id)) {
                jobApp.Primary_Contact_Id__c = primaryContactMap.get(jobApp.Id);
            }
        }
    }

    // SET ANNUAL GROSS INCOME FIELD METHOD: Set annual gross income field default for new records
    public static void setAnnualGrossIncomeField(List<Job_Application__c> jobApps) {
        for (Job_Application__c jobApp : jobApps) {
            if (jobApp.Salary_Curr__c != null ) {
                jobApp.Annual_Gross_Income_Curr__c = jobApp.Salary_Curr__c;
            } else {
                jobApp.Annual_Gross_Income_Curr__c = null;
            }
        }
    }

    // Calculate all income and tax fields for updated records
    public static void processIncomeCalculations(List<Job_Application__c> jobApps, Map<Id, Job_Application__c> oldJobApps) {
        
        for (Job_Application__c jobApp : jobApps) {
            Job_Application__c oldJobApp = oldJobApps.get(jobApp.Id);

            // Sync Annual Gross Income from Salary (If it wasn't manually changed)
            if (jobApp.Annual_Gross_Income_Curr__c == oldJobApp.Annual_Gross_Income_Curr__c) {
                if (jobApp.Salary_Curr__c != oldJobApp.Salary_Curr__c) {
                    jobApp.Annual_Gross_Income_Curr__c = jobApp.Salary_Curr__c;
                }
            }

            // Determine if a Tax Recalculation is Needed 
            Boolean needsRecalculation = (
                
                jobApp.Salary_Curr__c != oldJobApp.Salary_Curr__c ||
                jobApp.Tax_Filing_Status_Pckl__c != oldJobApp.Tax_Filing_Status_Pckl__c ||
                jobApp.Annual_Gross_Income_Curr__c != oldJobApp.Annual_Gross_Income_Curr__c ||
                jobApp.Deduction_Type_Pckl__c != oldJobApp.Deduction_Type_Pckl__c ||
                jobApp.Itemized_Deductions_Curr__c != oldJobApp.Itemized_Deductions_Curr__c ||
                jobApp.Taxes_Withheld_Curr__c != oldJobApp.Taxes_Withheld_Curr__c
                
            );

            // Run ALL calculations only if needed
            if (needsRecalculation && jobApp.Annual_Gross_Income_Curr__c != null) {

                // Calculate Taxable Income
                Decimal totalDeductions = 0;
                if (jobApp.Deduction_Type_Pckl__c == 'Standard Deduction') {
                    // Standard Deduction amount depends on filing status
                    if (jobApp.Tax_Filing_Status_Pckl__c == 'Single' || jobApp.Tax_Filing_Status_Pckl__c == 'Married, filing separately') {
                        totalDeductions = 15000;
                    } else if (jobApp.Tax_Filing_Status_Pckl__c == 'Married, filing jointly') {
                        totalDeductions = 30000;
                    } else if (jobApp.Tax_Filing_Status_Pckl__c == 'Head of Household') {
                        totalDeductions = 22500;
                    }
                } else {
                    // Use itemized deductions, defaulting to 0 if null
                    if (jobApp.Itemized_Deductions_Curr__c == null) {
                        totalDeductions = 0;
                    } else {
                        totalDeductions = jobApp.Itemized_Deductions_Curr__c;
                    }
                }

                jobApp.Taxable_Income_Curr__c = jobApp.Annual_Gross_Income_Curr__c - totalDeductions;

                if (jobApp.Taxable_Income_Curr__c < 0) {
                    jobApp.Taxable_Income_Curr__c = 0;
                }

                // Calculate Estimated Federal Tax
                Decimal taxableIncome = jobApp.Taxable_Income_Curr__c;
                String filingStatus = jobApp.Tax_Filing_Status_Pckl__c;
                Decimal estimatedTaxes = 0;

                if (filingStatus == 'Single') {
                    estimatedTaxes = calculateSingleFilerTaxes(taxableIncome);
                } else if (filingStatus == 'Married, filing jointly') {
                    estimatedTaxes = calculateMarriedJointlyTaxes(taxableIncome);
                } else if (filingStatus == 'Married, filing separately') {
                    estimatedTaxes = calculateMarriedSeparatelyTaxes(taxableIncome);
                } else if (filingStatus == 'Head of Household') {
                    estimatedTaxes = calculateHeadOfHouseholdTaxes(taxableIncome);
                }
                
                jobApp.Estimated_Federal_Tax_Curr__c = estimatedTaxes.setScale(2, RoundingMode.HALF_UP);

                // Calculate Final Tax Due or Refund
                Decimal withheldAmount;
                if (jobApp.Taxes_Withheld_Curr__c == null) {
                    withheldAmount = 0;
                } else {
                    withheldAmount = jobApp.Taxes_Withheld_Curr__c;
                }
                jobApp.Tax_Due_Refund_Curr__c = jobApp.Estimated_Federal_Tax_Curr__c - withheldAmount;
            }
        }
    }

    // PRIVATE HELPER METHODS FOR TAX CALCULATIONS
    private static Decimal calculateSingleFilerTaxes(Decimal taxableIncome) {
        if (taxableIncome <= 0) { return 0; }
        if (taxableIncome <= 11925) { return taxableIncome * 0.10; }
        if (taxableIncome <= 48475) { return 1192.50 + (taxableIncome - 11925) * 0.12; }
        if (taxableIncome <= 103350) { return 5578.50 + (taxableIncome - 48475) * 0.22; }
        if (taxableIncome <= 197300) { return 17651 + (taxableIncome - 103350) * 0.24; }
        if (taxableIncome <= 250525) { return 40199 + (taxableIncome - 197300) * 0.32; }
        if (taxableIncome <= 626350) { return 57231 + (taxableIncome - 250525) * 0.35; }
        return 188769.75 + (taxableIncome - 626350) * 0.37;
    }

    private static Decimal calculateMarriedJointlyTaxes(Decimal taxableIncome) {
        if (taxableIncome <= 0) { return 0; }
        if (taxableIncome <= 23850) { return taxableIncome * 0.10; }
        if (taxableIncome <= 96950) { return 2385 + (taxableIncome - 23850) * 0.12; }
        if (taxableIncome <= 206700) { return 11157 + (taxableIncome - 96950) * 0.22; }
        if (taxableIncome <= 394600) { return 35302 + (taxableIncome - 206700) * 0.24; }
        if (taxableIncome <= 501050) { return 80398 + (taxableIncome - 394600) * 0.32; }
        if (taxableIncome <= 751600) { return 114462 + (taxableIncome - 501050) * 0.35; }
        return 202154.50 + (taxableIncome - 751600) * 0.37;
    }

    private static Decimal calculateMarriedSeparatelyTaxes(Decimal taxableIncome) {
        if (taxableIncome <= 0) { return 0; }
        if (taxableIncome <= 11925) { return taxableIncome * 0.10; }
        if (taxableIncome <= 48475) { return 1192.50 + (taxableIncome - 11925) * 0.12; }
        if (taxableIncome <= 103350) { return 5578.50 + (taxableIncome - 48475) * 0.22; }
        if (taxableIncome <= 197300) { return 17651 + (taxableIncome - 103350) * 0.24; }
        if (taxableIncome <= 250525) { return 40199 + (taxableIncome - 197300) * 0.32; }
        if (taxableIncome <= 375800) { return 57231 + (taxableIncome - 250525) * 0.35; }
        return 101077.25 + (taxableIncome - 375800) * 0.37;
    }

    private static Decimal calculateHeadOfHouseholdTaxes(Decimal taxableIncome) {
        if (taxableIncome <= 0) { return 0; }
        if (taxableIncome <= 17000) { return taxableIncome * 0.10; }
        if (taxableIncome <= 64850) { return 1700 + (taxableIncome - 17000) * 0.12; }
        if (taxableIncome <= 103350) { return 7442 + (taxableIncome - 64850) * 0.22; }
        if (taxableIncome <= 197300) { return 15912 + (taxableIncome - 103350) * 0.24; }
        if (taxableIncome <= 250500) { return 38460 + (taxableIncome - 197300) * 0.32; }
        if (taxableIncome <= 626350) { return 55484 + (taxableIncome - 250500) * 0.35; }
        return 187031.50 + (taxableIncome - 626350) * 0.37;
    }
}
