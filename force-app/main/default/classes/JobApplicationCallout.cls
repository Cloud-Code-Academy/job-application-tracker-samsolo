public with sharing class JobApplicationCallout {
    
    public static void getJobApplication() {
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://jooble.org/api/785906bc-d06a-46b2-b037-e74c5b097f62');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        // Set the request body with keywords and location
        String requestBody = '{"keywords":"Salesforce","location":"United States", "salary":90000,"page":2,"resultonpage":1}';
        req.setBody(requestBody);

        // Send the request
        Http http = new Http();
        HttpResponse res = http.send(req);

        // Get body of the response
        String responseBody = res.getBody();

        // Handle the response
        if (res.getStatusCode() == 200) {
            //Create a new Job_Application__c record from the response
            List<Job_Application__c> createdJobApplications = createJobApplicationsFromResponse(responseBody);
            for (Job_Application__c jobApplication : createdJobApplications) {
                System.debug('Job Application Created: ' + jobApplication.Id);
            }
        } 
    }

    private static List<Job_Application__c> createJobApplicationsFromResponse(String jsonResponse) {

        // This list will hold all the new records we want to insert
        List<Job_Application__c> jobApplicationsToInsert = new List<Job_Application__c>();

        // The top-level JSON is an object that contains a key called "jobs", which holds the list
        Map<String, Object> topLevelMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        List<Object> jobList = (List<Object>) topLevelMap.get('jobs');

        // Loop through each job returned in the API response
        for (Object jobObj : jobList) {
            Map<String, Object> jobMap = (Map<String, Object>) jobObj;

            // Create a new Job_Application__c record for EACH job in the list
            Job_Application__c jobApplication = new Job_Application__c();
            
            // Assign values from the JSON to the record's fields
            jobApplication.Position_Title_Txt__c = (String) jobMap.get('title');
            jobApplication.Job_Posting_URL__c = (String) jobMap.get('link');
            jobApplication.Location_Txt__c = (String) jobMap.get('location');
            jobApplication.Description_Txt__c = (String) jobMap.get('snippet');
            
            // Add the newly created record to our list
            jobApplicationsToInsert.add(jobApplication);
        }

        // Insert the records in bulk
        if (!jobApplicationsToInsert.isEmpty()) {
            insert jobApplicationsToInsert;
        }

        return jobApplicationsToInsert;
    }

}