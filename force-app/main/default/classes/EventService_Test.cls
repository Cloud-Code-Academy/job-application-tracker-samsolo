@isTest
private class EventService_Test {

    // Test the positive case where an email reminder should be sent.
    @isTest
    static void testSendRemindersSuccess() {
        // 1. Setup: Create a User and an Event they own.
        User testUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User'].Id,
            LastName = 'Doe',
            FirstName = 'John',
            Email = 'john.doe@test.com',
            Username = 'john.doe@test.com' + System.currentTimeMillis(),
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        insert testUser;

        Event testEvent = new Event(
            OwnerId = testUser.Id,
            Subject = 'Project Kickoff',
            StartDateTime = Datetime.now().addDays(1),
            EndDateTime = Datetime.now().addDays(1).addHours(1)
        );
        insert testEvent;

        List<Event> eventsToRemind = [
            SELECT Id, Subject, StartDateTime, Owner.Name, Owner.Email 
            FROM Event 
            WHERE Id = :testEvent.Id
        ];
        
        Test.startTest();
        
        Integer emailsBefore = Limits.getEmailInvocations();

        // 2. Execution: Call the service method.
        EventService.sendReminders(eventsToRemind);

        Integer emailsAfter = Limits.getEmailInvocations();
        
        Test.stopTest();

        // 3. Verification: Assert that exactly one email was sent.
        System.assertEquals(1, emailsAfter - emailsBefore, 'One email should have been prepared and sent.');
    }

    // Test the case where the event owner has no email address.
    @isTest
    static void testSendReminders_NoOwnerEmail() {
        // Create a Queue as the owner since Queues don't have emails.
        Group testQueue = new Group(Name = 'Test Event Queue', Type = 'Queue');
        insert testQueue;

        System.assert(testQueue.Email == null, 'The test queue should not have an email address.');

        // 1. Setup: Create an Event owned by the Queue.
        Event testEvent = new Event(
            OwnerId = testQueue.Id,
            Subject = 'Team Lunch',
            StartDateTime = Datetime.now().addDays(1),
            EndDateTime = Datetime.now().addDays(1).addHours(1)
        );
        insert testEvent;

        List<Event> eventsToRemind = [
            SELECT Id, Subject, StartDateTime, Owner.Name, Owner.Email 
            FROM Event 
            WHERE Id = :testEvent.Id
        ];
        
        Test.startTest();

        Integer emailsBefore = Limits.getEmailInvocations();
        // 2. Execution: Call the service method.
        EventService.sendReminders(eventsToRemind);
        Integer emailsAfter = Limits.getEmailInvocations();
        
        Test.stopTest();

        // 3. Verification: Assert that no email was sent.
        System.assertEquals(0, emailsAfter - emailsBefore, 'No email should be sent if the owner is a Queue.');
    }

    // Test the edge case where the input list is empty.
    @isTest
    static void testSendReminders_EmptyList() {
        Test.startTest();

        Integer emailsBefore = Limits.getEmailInvocations();
        // 2. Execution: Call the service method with an empty list.
        EventService.sendReminders(new List<Event>());
        Integer emailsAfter = Limits.getEmailInvocations();
        
        Test.stopTest();

        // 3. Verification: Assert that no email was sent and no errors occurred.
        System.assertEquals(0, emailsAfter - emailsBefore, 'No email should be sent for an empty list.');
    }
}