public with sharing class JobApplicationTriggerHelper {

    // --- Constants for Tax Calculations (as of 2023/2024) ---

    private static final Decimal SOCIAL_SECURITY_RATE = 0.062;
    private static final Decimal SOCIAL_SECURITY_LIMIT = 168600; // 2024 limit
    private static final Decimal MEDICARE_RATE = 0.0145;

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

       Set<Id> jobAppIds = new Set<Id>();
        for (Job_Application__c jobApp : jobApps) {
            if (jobApp.Primary_Contact_Id__c == null && jobApp.Number_of_Related_Contacts_Rollup__c > 0) {
                jobAppIds.add(jobApp.Id);
            }
        }
        
        if (jobAppIds.isEmpty()) {
            return;
        }

        List<Job_Application_Contact__c> jobApplicationContacts = [
            SELECT Job_Application_Id__c, Contact_Id__c
            FROM Job_Application_Contact__c 
            WHERE Job_Application_Id__c IN :jobAppIds 
            ORDER BY CreatedDate ASC
        ];

        Map<Id, Id> primaryContactMap = new Map<Id, Id>();
        for (Job_Application_Contact__c jac : jobApplicationContacts) {
            if(!primaryContactMap.containsKey(jac.Job_Application_Id__c)) {
                primaryContactMap.put(jac.Job_Application_Id__c, jac.Contact_Id__c);
            }
        }

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

            if (jobApp.Annual_Gross_Income_Curr__c == oldJobApp.Annual_Gross_Income_Curr__c) {
                if (jobApp.Salary_Curr__c != oldJobApp.Salary_Curr__c) {
                    jobApp.Annual_Gross_Income_Curr__c = jobApp.Salary_Curr__c;
                }
            }

            Boolean needsRecalculation = (
                jobApp.Salary_Curr__c != oldJobApp.Salary_Curr__c ||
                jobApp.Tax_Filing_Status_Pckl__c != oldJobApp.Tax_Filing_Status_Pckl__c ||
                jobApp.Annual_Gross_Income_Curr__c != oldJobApp.Annual_Gross_Income_Curr__c ||
                jobApp.Deduction_Type_Pckl__c != oldJobApp.Deduction_Type_Pckl__c ||
                jobApp.Itemized_Deductions_Curr__c != oldJobApp.Itemized_Deductions_Curr__c ||
                jobApp.Taxes_Withheld_Curr__c != oldJobApp.Taxes_Withheld_Curr__c
            );

            if (needsRecalculation && jobApp.Annual_Gross_Income_Curr__c != null) {

                // --- Federal Tax Calculation ---
                Decimal totalDeductions = 0;
                if (jobApp.Deduction_Type_Pckl__c == 'Standard Deduction') {
                    if (jobApp.Tax_Filing_Status_Pckl__c == 'Single' || jobApp.Tax_Filing_Status_Pckl__c == 'Married, filing separately') {
                        totalDeductions = 15000;
                    } else if (jobApp.Tax_Filing_Status_Pckl__c == 'Married, filing jointly') {
                        totalDeductions = 30000;
                    } else if (jobApp.Tax_Filing_Status_Pckl__c == 'Head of Household') {
                        totalDeductions = 22500;
                    }
                } else {
                    totalDeductions = (jobApp.Itemized_Deductions_Curr__c == null) ? 0 : jobApp.Itemized_Deductions_Curr__c;
                }

                jobApp.Taxable_Income_Curr__c = Math.max(0, jobApp.Annual_Gross_Income_Curr__c - totalDeductions);
                
                jobApp.Estimated_Federal_Tax_Curr__c = calculateFederalTax(
                    jobApp.Taxable_Income_Curr__c, jobApp.Tax_Filing_Status_Pckl__c
                ).setScale(2, RoundingMode.HALF_UP);

                // --- FICA Tax Calculations (Social Security & Medicare) ---
                Decimal grossIncome = jobApp.Annual_Gross_Income_Curr__c;
                Decimal socialSecurityEligibleIncome = Math.min(grossIncome, SOCIAL_SECURITY_LIMIT);
                jobApp.Social_Security_Tax_Curr__c = (socialSecurityEligibleIncome * SOCIAL_SECURITY_RATE).setScale(2, RoundingMode.HALF_UP);
                jobApp.Medicare_Tax_Curr__c = (grossIncome * MEDICARE_RATE).setScale(2, RoundingMode.HALF_UP);

                // --- Take-Home Pay Calculations ---
                Decimal totalTaxes = jobApp.Estimated_Federal_Tax_Curr__c + jobApp.Social_Security_Tax_Curr__c + jobApp.Medicare_Tax_Curr__c;
                jobApp.Take_Home_Pay_Yearly_Curr__c = grossIncome - totalTaxes;
                jobApp.Take_Home_Pay_Monthly_Curr__c = jobApp.Take_Home_Pay_Yearly_Curr__c / 12;

                // --- Original Tax Due/Refund Calculation ---
                Decimal withheldAmount = (jobApp.Taxes_Withheld_Curr__c == null) ? 0 : jobApp.Taxes_Withheld_Curr__c;
                jobApp.Tax_Due_Refund_Curr__c = jobApp.Estimated_Federal_Tax_Curr__c - withheldAmount;
            }
        }
    }

    // --- PRIVATE HELPER METHODS FOR TAX CALCULATIONS ---
    private static Decimal calculateFederalTax(Decimal taxableIncome, String filingStatus) {
        if (filingStatus == 'Single') {
            return calculateSingleFilerTaxes(taxableIncome);
        } else if (filingStatus == 'Married, filing jointly') {
            return calculateMarriedJointlyTaxes(taxableIncome);
        } else if (filingStatus == 'Married, filing separately') {
            return calculateMarriedSeparatelyTaxes(taxableIncome);
        } else if (filingStatus == 'Head of Household') {
            return calculateHeadOfHouseholdTaxes(taxableIncome);
        }
        return 0;
    }

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
