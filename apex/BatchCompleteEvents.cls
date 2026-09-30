global class BatchCompleteEvents implements Database.Batchable<sObject> {

    // Canceled / Pending Cancellation are excluded so the nightly job cannot
    // overwrite the outcome of a cancellation approval.
    private static final String QUERY =
        'SELECT Id, Event_Date__c, Event_Status__c FROM Event__c ' +
        'WHERE Event_Date__c < TODAY ' +
        'AND (Event_Status__c = null ' +
        '     OR Event_Status__c NOT IN (\'Completed\', \'Canceled\', \'Pending Cancellation\'))';

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(QUERY);
    }

    global void execute(Database.BatchableContext bc, List<Event__c> scope) {
        for (Event__c ev : scope) {
            ev.Event_Status__c = 'Completed';
        }
        update scope;
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Past events marked as Completed');
    }
}
