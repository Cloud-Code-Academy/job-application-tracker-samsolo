@isTest
private class EventTriggerHelper_Test {

    // Helper method to find the next occurrence of a specific day of the week
    private static Date getNextDateForDay(String dayAbbreviation) {
        Date today = Date.today();
        // Loop until we find the target day (e.g., 'Sat', 'Mon')
        // We must create a Datetime to use the format() method to find the day name
        while (Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0)).format('E') != dayAbbreviation) {
            today = today.addDays(1);
        }
        return today;
    }

    // Test that an error is added when an event is created on a weekend
    @isTest
    static void testWeekendEventError() {
        // 1. Setup: Create a date that falls on a Saturday
        Date weekendDay = getNextDateForDay('Sat');
        Datetime weekendStart = Datetime.newInstance(weekendDay, Time.newInstance(9, 0, 0, 0));

        Event weekendEvent = new Event(
            StartDateTime = weekendStart,
            EndDateTime = weekendStart.addHours(1)
        );

        // 2. Execution & Verification
        Test.startTest();
        try {
            insert weekendEvent;
            System.assert(false, 'An exception should have been thrown for a weekend event.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Events cannot be scheduled on a weekend'),
                         'The error message for weekend events is incorrect.');
        }
        Test.stopTest();
    }

    // Test that an event can be successfully created on a weekday
    @isTest
    static void testWeekdayEventSuccess() {
        // 1. Setup: Create a date that falls on a Monday
        Date weekday = getNextDateForDay('Mon');
        Datetime weekdayStart = Datetime.newInstance(weekday, Time.newInstance(9, 0, 0, 0));

        Event weekdayEvent = new Event(
            StartDateTime = weekdayStart,
            EndDateTime = weekdayStart.addHours(1)
        );

        // 2. Execution
        Test.startTest();
        Database.SaveResult result = Database.insert(weekdayEvent, false);
        Test.stopTest();

        // 3. Verification: Assert that the insert was successful
        System.assert(result.isSuccess(), 'The event should have been created successfully on a weekday.');
        
        Integer eventCount = [SELECT COUNT() FROM Event WHERE Id = :weekdayEvent.Id];
        System.assertEquals(1, eventCount, 'The event was not found in the database after insert.');
    }

    // Test that an error is added when an event is double-booked
    @isTest
    static void testDoubleBookingError() {
        // 1. Setup: Create and insert an initial event
        Date eventDate = getNextDateForDay('Tue');
        Datetime eventTime = Datetime.newInstance(eventDate, Time.newInstance(10, 0, 0, 0));
        
        Event existingEvent = new Event(
            StartDateTime = eventTime,
            EndDateTime = eventTime.addHours(1)
        );
        insert existingEvent;

        // Create a new event for the exact same time
        Event conflictingEvent = new Event(
            StartDateTime = eventTime,
            EndDateTime = eventTime.addHours(1)
        );

        // 2. Execution & Verification
        Test.startTest();
        try {
            insert conflictingEvent;
            System.assert(false, 'An exception should have been thrown for a double-booked event.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('This time slot is already booked'),
                         'The error message for a double-booked event is incorrect.');
        }
        Test.stopTest();
    }

    // Test that events at different times on the same day can be created
    @isTest
    static void testNoDoubleBookingOnDifferentTimes() {
        // 1. Setup: Create and insert an initial event
        Date eventDate = getNextDateForDay('Wed');
        Datetime firstEventTime = Datetime.newInstance(eventDate, Time.newInstance(9, 0, 0, 0));
        
        Event existingEvent = new Event(
            StartDateTime = firstEventTime,
            EndDateTime = firstEventTime.addHours(1)
        );
        insert existingEvent;

        // Create a new event for a different time on the same day
        Event nonConflictingEvent = new Event(
            StartDateTime = firstEventTime.addHours(2), // 2 hours later
            EndDateTime = firstEventTime.addHours(3)
        );

        // 2. Execution
        Test.startTest();
        Database.SaveResult result = Database.insert(nonConflictingEvent, false);
        Test.stopTest();
        
        // 3. Verification
        System.assert(result.isSuccess(), 'The second event should have been created successfully.');
    }
}