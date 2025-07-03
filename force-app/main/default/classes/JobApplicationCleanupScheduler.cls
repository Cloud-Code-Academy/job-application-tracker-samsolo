public with sharing class JobApplicationCleanupScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        // Create a new instance of our batch class and start it.
        Database.executeBatch(new JobApplicationCleanupBatch());
    }

}