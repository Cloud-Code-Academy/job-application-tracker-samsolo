public with sharing class EventService {

    public static void sendReminders(List<Event> eventsToRemind) {
        
        if (eventsToRemind.isEmpty()){
            return;
        }
    
        // Create a list to hold the email messages we are going to build.
        List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();

        // Get the Salesforce org's unique base URL once, outside the loop.
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        for (Event event : eventsToRemind) {
            
            if (event.Owner.Email != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                // Set email details
                List<String> recipientList = new List<String>();
                recipientList.add(event.Owner.Email);
                
                mail.setToAddresses(recipientList);
                mail.setSenderDisplayName('Salesforce Event Reminders');
                mail.setSubject('Reminder: ' + event.Subject);

                // Construct the full record link
                String recordLink = baseUrl + '/' + event.Id;
                
                // Create the HTML email body
                String htmlBody = 'Hi ' + event.Owner.Name + ',<br/><br/>';
                htmlBody += 'This is a reminder for your upcoming event:<br/><br/>';
                htmlBody += '<b>Event:</b> ' + event.Subject + '<br/>';
                htmlBody += '<b>Date:</b> ' + event.StartDateTime.format('MMMMM dd, yyyy') + '<br/>';
                htmlBody += '<b>Time:</b> ' + event.StartDateTime.format('h:mm a z') + '<br/><br/>';
                htmlBody += '<a href="' + recordLink + '">Click here to view the event in Salesforce.</a>';
                
                mail.setHtmlBody(htmlBody);

                // Add the prepared email to our 'emailMessages' list
                emailMessages.add(mail);
            }
        }

        // Send the final list of email messages
        if (!emailMessages.isEmpty()) {
            Messaging.sendEmail(emailMessages);
        }
    }
}