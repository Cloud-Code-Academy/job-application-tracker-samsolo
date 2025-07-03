public with sharing class EventReminderScheduler implements Schedulable {
    
    // EXECUTE METHOD: This method is called when the scheduler runs.
    public void execute(SchedulableContext sc) {
        
        // Create a Date variable for 10 days in the future.
        Date targetDate = Date.today().addDays(10);

        // Query all Events that start 10 days from today:
        List<Event> eventsToRemind = [
            SELECT Id, Subject, StartDateTime, Owner.Name, Owner.Email 
            FROM Event 
            WHERE ActivityDate = :targetDate
        ];

        EventService.sendReminders(eventsToRemind);
    }
}