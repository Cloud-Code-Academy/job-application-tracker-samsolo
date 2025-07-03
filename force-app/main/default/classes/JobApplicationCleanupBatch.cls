public with sharing class JobApplicationCleanupBatch implements Database.Batchable<SObject> {

    // START METHOD: The start() method gathers all the records that the job will process.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        // Define our stale date criteria (30 days or more in the past)
        Date thirtyDaysAgo = Date.today().addDays(-30);
        
        // The SOQL query finds all job applications that are not yet closed/accepted
        // and have a follow-up date that is 30 or more days ago.
        String query = 'SELECT Id, Status_Pckl__c, Notes_Txt__c FROM Job_Application__c ' +
                       'WHERE Status_Pckl__c NOT IN (\'Closed\', \'Accepted\') ' +
                       'AND Follow_Up_Date__c <= :thirtyDaysAgo';
        
        return Database.getQueryLocator(query);
    }

    // EXECUTE METHOD: The execute() method runs for each "chunk" of records (usually 200 at a time).
    public void execute(Database.BatchableContext bc, List<Job_Application__c> scope) {
        
        String automatedNote = 'Application closed by automated process on ' + Date.today().format() + '.';

        // Loop through the chunk of records provided by the start() method.
        for (Job_Application__c app : scope) {
            app.Status_Pckl__c = 'Closed';
            
            // This safely appends the new note to any existing notes.
            if (String.isNotBlank(app.Notes_Txt__c)) {
                app.Notes_Txt__c = app.Notes_Txt__c + '\n\n' + automatedNote;
            } else {
                // If the notes are blank, just set the new note directly.
                app.Notes_Txt__c = automatedNote;
            }
        }
        
        // Update the entire chunk of records in one DML operation.
        update scope;
    }

    // FINISH METHOD: The finish() method runs once after all batches have been processed.
    public void finish(Database.BatchableContext bc) {
        // This method is required by the Batchable interface,
        // but it can be left empty if you have no final actions to perform. 
    }

}