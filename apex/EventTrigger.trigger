trigger EventTrigger on Event__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore) {
        VenueAvailabilityHandler.preventDoubleBooking(Trigger.new, Trigger.oldMap);
    } else {
        VenueAvailabilityHandler.updateVenueAvailability(Trigger.new, Trigger.oldMap);
    }
}
