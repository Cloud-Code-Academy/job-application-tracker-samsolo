public with sharing class EventTriggerHandler extends TriggerHandler {

    // Class members: lists and maps that store the values of the trigger context
    private List<Event> newEvents;
    private List<Event> oldEvents;
    private Map<Id, Event> newEventMap;
    private Map<Id, Event> oldEventMap;

    // Constructor
    public EventTriggerHandler () {
        this.newEvents = (List<Event>) Trigger.new;
        this.oldEvents = (List<Event>) Trigger.old;
        this.newEventMap = (Map<Id, Event>) Trigger.newMap;
        this.oldEventMap = (Map<Id, Event>) Trigger.oldMap;
        }

    // Call helper methods
    public override void beforeInsert() {
        EventTriggerHelper.validateEvents(this.newEvents);
    }
    public override void beforeUpdate() {
        EventTriggerHelper.validateEvents(this.newEvents);
    }

}

