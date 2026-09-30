public class VenueAvailabilityHandler {

    private static final String STATUS_CANCELED  = 'Canceled';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String VENUE_RESERVED   = 'Reserved';
    private static final String VENUE_AVAILABLE  = 'Available';

    private static final Set<String> FREEING_STATUSES =
        new Set<String>{ STATUS_CANCELED, STATUS_COMPLETED };

    // A venue can host many events, but never two live ones on the same day.
    public static void preventDoubleBooking(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        Set<Id> venueIds = new Set<Id>();
        Set<Id> scopeIds = new Set<Id>();
        for (Event__c ev : newEvents) {
            if (ev.Id != null) {
                scopeIds.add(ev.Id);
            }
            if (ev.Venue__c != null && isActive(ev.Event_Status__c)) {
                venueIds.add(ev.Venue__c);
            }
        }
        if (venueIds.isEmpty()) {
            return;
        }

        Set<String> alreadyBooked = new Set<String>();
        for (Event__c booked : [SELECT Venue__c, Event_Date__c
                                FROM Event__c
                                WHERE Venue__c IN :venueIds
                                  AND Id NOT IN :scopeIds
                                  AND (Event_Status__c = null
                                       OR Event_Status__c NOT IN :FREEING_STATUSES)]) {
            alreadyBooked.add(bookingKey(booked.Venue__c, booked.Event_Date__c));
        }

        Set<String> claimedInThisSave = new Set<String>();
        for (Event__c ev : newEvents) {
            if (ev.Venue__c == null || !isActive(ev.Event_Status__c)) {
                continue;
            }
            String key = bookingKey(ev.Venue__c, ev.Event_Date__c);
            if (alreadyBooked.contains(key)) {
                ev.addError('This venue is already booked by another event on '
                    + String.valueOf(ev.Event_Date__c) + ' and cannot be double booked.');
            } else if (!claimedInThisSave.add(key)) {
                ev.addError('This venue is selected by more than one event on the same date in this same save.');
            }
        }
    }

    public static void updateVenueAvailability(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        Set<Id> toReserve = new Set<Id>();
        Set<Id> toRelease = new Set<Id>();

        for (Event__c ev : newEvents) {
            Event__c old = oldMap == null ? null : oldMap.get(ev.Id);
            if (old != null
                    && old.Venue__c == ev.Venue__c
                    && old.Event_Status__c == ev.Event_Status__c) {
                continue;
            }

            if (ev.Venue__c != null) {
                if (isActive(ev.Event_Status__c)) {
                    toReserve.add(ev.Venue__c);
                } else {
                    toRelease.add(ev.Venue__c);
                }
            }
            if (old != null && old.Venue__c != null && old.Venue__c != ev.Venue__c) {
                toRelease.add(old.Venue__c);
            }
        }

        toRelease.removeAll(toReserve);
        toRelease.removeAll(venuesStillBookedElsewhere(toRelease, newEvents));

        Set<Id> allVenueIds = new Set<Id>(toReserve);
        allVenueIds.addAll(toRelease);
        if (allVenueIds.isEmpty()) {
            return;
        }

        List<Venue__c> changes = new List<Venue__c>();
        for (Venue__c venue : [SELECT Id, Availability_Status__c
                               FROM Venue__c
                               WHERE Id IN :allVenueIds]) {
            String target = toReserve.contains(venue.Id) ? VENUE_RESERVED : VENUE_AVAILABLE;
            if (venue.Availability_Status__c != target) {
                venue.Availability_Status__c = target;
                changes.add(venue);
            }
        }
        if (!changes.isEmpty()) {
            update changes;
        }
    }

    private static Set<Id> venuesStillBookedElsewhere(Set<Id> venueIds, List<Event__c> newEvents) {
        Set<Id> stillBooked = new Set<Id>();
        if (venueIds.isEmpty()) {
            return stillBooked;
        }

        Set<Id> scopeIds = new Set<Id>();
        for (Event__c ev : newEvents) {
            if (ev.Id != null) {
                scopeIds.add(ev.Id);
            }
        }

        for (Event__c other : [SELECT Venue__c
                               FROM Event__c
                               WHERE Venue__c IN :venueIds
                                 AND Id NOT IN :scopeIds
                                 AND (Event_Status__c = null
                                      OR Event_Status__c NOT IN :FREEING_STATUSES)]) {
            stillBooked.add(other.Venue__c);
        }
        return stillBooked;
    }

    private static String bookingKey(Id venueId, Date eventDate) {
        return venueId + '|' + String.valueOf(eventDate);
    }

    private static Boolean isActive(String status) {
        return status == null || !FREEING_STATUSES.contains(status);
    }
}
