public with sharing class JobApplicationTriggerHandler extends TriggerHandler {

    // class members: lists and maps that store the values of the trigger context
    private List<Job_Application__c> newJobApplications;
    private List<Job_Application__c> oldJobApplications;
    private Map<Id, Job_Application__c> newJobApplicationMap;
    private Map<Id, Job_Application__c> oldJobApplicationMap;

    // constructor
    public JobApplicationTriggerHandler () {
        this.newJobApplications = (List<Job_Application__c>) Trigger.new;
        this.oldJobApplications = (List<Job_Application__c>) Trigger.old;
        this.newJobApplicationMap = (Map<Id, Job_Application__c>) Trigger.newMap;
        this.oldJobApplicationMap = (Map<Id, Job_Application__c>) Trigger.oldMap;
        }

    // call helper methods 
    public override void afterUpdate() {
        JobApplicationTriggerHelper.createTask(this.newJobApplications, this.oldJobApplicationMap);
    }

    public override void beforeUpdate() {
        JobApplicationTriggerHelper.setPrimaryContactOnFirstRelation(this.newJobApplications);
        JobApplicationTriggerHelper.processIncomeCalculations(this.newJobApplications, this.oldJobApplicationMap);
    }

    public override void beforeInsert() {
        JobApplicationTriggerHelper.setAnnualGrossIncomeField(this.newJobApplications);
    }

}

