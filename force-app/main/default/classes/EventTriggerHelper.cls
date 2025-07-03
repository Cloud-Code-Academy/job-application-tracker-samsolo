public with sharing class EventTriggerHelper {
    
    // VALIDATE EVENTS METHOD: Method that validates if Events are on weekend days or not
    public static void validateEvents(List<Event> newEvents) {

        // Check for weekends logic
        for (Event newEvent : newEvents) {  
        // Check to make sure the date is not null
            if (newEvent.StartDateTime != null) {
                
                // Get the day of the week 
                String dayOfWeek = newEvent.StartDateTime.format('E');

                // Check for weekend meetings
                if (dayOfWeek == 'Sat' || dayOfWeek == 'Sun') {
                    newEvent.addError('Events cannot be scheduled on a weekend. Please choose a weekday.');
                }
            }
        }

        // This is the beginning of the double-booking logic
        Set<Datetime> newStartTimes = new Set<Datetime>();
    
        // Gather start times for non-all-day events
        for (Event newEvent : newEvents) {
            if (!newEvent.hasErrors() && newEvent.IsAllDayEvent == false && newEvent.StartDateTime != null) {
                newStartTimes.add(newEvent.StartDateTime);
            }
        }

        // Only run a query if there are times to check
        if (!newStartTimes.isEmpty()) {
            
            // Find existing events that conflict, but ignore the records being updated
            List<Event> conflictingEvents = [
                SELECT StartDateTime
                FROM Event
                WHERE StartDateTime IN :newStartTimes
                AND Id NOT IN :newEvents
            ];

            // Create a simple Set of the conflicting times for fast lookup
            Set<Datetime> existingStartTimes = new Set<Datetime>();
            for (Event event : conflictingEvents){
                existingStartTimes.add(event.StartDateTime);
            }

            // Final loop: Add errors to the specific records that have a conflict
            for (Event newEvent : newEvents) {
                if (existingStartTimes.contains(newEvent.StartDateTime)) {
                    newEvent.addError('This time slot is already booked. Please select a different start time.');
                }
            }
        }
    }
}