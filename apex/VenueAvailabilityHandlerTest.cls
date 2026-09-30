@isTest
private class VenueAvailabilityHandlerTest {

    private static Venue__c createVenue(String venueName, Decimal capacity) {
        Venue__c venue = new Venue__c(
            Name = venueName,
            Capacity__c = capacity,
            Availability_Status__c = 'Available'
        );
        insert venue;
        return venue;
    }

    private static Event__c newEvent(String eventName, Date eventDate, String status, Id venueId) {
        return new Event__c(
            Name = eventName,
            Event_Date__c = eventDate,
            Event_Status__c = status,
            Venue__c = venueId
        );
    }

    private static String venueStatus(Id venueId) {
        return [SELECT Availability_Status__c FROM Venue__c WHERE Id = :venueId].Availability_Status__c;
    }

    @isTest
    static void newEventReservesItsVenue() {
        Venue__c venue = createVenue('Grand Hall', 300);

        Test.startTest();
        insert newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);
        Test.stopTest();

        System.assertEquals('Reserved', venueStatus(venue.Id));
    }

    @isTest
    static void cancelingEventReleasesTheVenue() {
        Venue__c venue = createVenue('Grand Hall', 300);
        Event__c ev = newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);
        insert ev;

        Test.startTest();
        ev.Event_Status__c = 'Canceled';
        update ev;
        Test.stopTest();

        System.assertEquals('Available', venueStatus(venue.Id));
    }

    @isTest
    static void completingEventReleasesTheVenue() {
        Venue__c venue = createVenue('Grand Hall', 300);
        Event__c ev = newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);
        insert ev;

        Test.startTest();
        ev.Event_Status__c = 'Completed';
        update ev;
        Test.stopTest();

        System.assertEquals('Available', venueStatus(venue.Id));
    }

    @isTest
    static void movingAnEventReleasesTheOldVenueAndReservesTheNewOne() {
        Venue__c first = createVenue('Grand Hall', 300);
        Venue__c second = createVenue('Beach Resort', 150);
        Event__c ev = newEvent('Annual Day', Date.today().addDays(30), 'Planned', first.Id);
        insert ev;

        Test.startTest();
        ev.Venue__c = second.Id;
        update ev;
        Test.stopTest();

        System.assertEquals('Available', venueStatus(first.Id));
        System.assertEquals('Reserved', venueStatus(second.Id));
    }

    @isTest
    static void editingAnUnrelatedFieldKeepsTheVenueReserved() {
        Venue__c venue = createVenue('Grand Hall', 300);
        Event__c ev = newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);
        insert ev;

        Test.startTest();
        ev.Name = 'Annual Day 2026';
        update ev;
        Test.stopTest();

        System.assertEquals('Reserved', venueStatus(venue.Id));
    }

    @isTest
    static void secondActiveEventOnTheSameVenueAndDateIsBlocked() {
        Venue__c venue = createVenue('Grand Hall', 300);
        insert newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);

        Test.startTest();
        try {
            insert newEvent('Product Launch', Date.today().addDays(30), 'Planned', venue.Id);
            System.assert(false, 'Expected the double booking to be blocked');
        } catch (DmlException e) {
            System.assert(e.getDmlMessage(0).contains('double booked'), e.getDmlMessage(0));
        }
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Event__c]);
    }

    @isTest
    static void sameVenueOnDifferentDatesIsAllowed() {
        Venue__c venue = createVenue('Grand Hall', 300);
        insert newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id);

        Test.startTest();
        insert newEvent('Product Launch', Date.today().addDays(60), 'Planned', venue.Id);
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Event__c]);
        System.assertEquals('Reserved', venueStatus(venue.Id));
    }

    @isTest
    static void sameVenueTwiceInOneSaveIsBlocked() {
        Venue__c venue = createVenue('Grand Hall', 300);

        Test.startTest();
        try {
            insert new List<Event__c>{
                newEvent('Annual Day', Date.today().addDays(30), 'Planned', venue.Id),
                newEvent('Product Launch', Date.today().addDays(30), 'Planned', venue.Id)
            };
            System.assert(false, 'Expected the duplicate venue in the same save to be blocked');
        } catch (DmlException e) {
            System.assert(e.getDmlMessage(0).contains('same save'), e.getDmlMessage(0));
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Event__c]);
    }

    @isTest
    static void canceledEventDoesNotBlockANewBooking() {
        Venue__c venue = createVenue('Grand Hall', 300);
        insert newEvent('Annual Day', Date.today().addDays(30), 'Canceled', venue.Id);

        Test.startTest();
        insert newEvent('Product Launch', Date.today().addDays(30), 'Planned', venue.Id);
        Test.stopTest();

        System.assertEquals('Reserved', venueStatus(venue.Id));
    }

    @isTest
    static void eventWithoutAVenueIsSavedWithoutAnyVenueUpdate() {
        Test.startTest();
        insert newEvent('Offsite Meetup', Date.today().addDays(15), 'Planned', null);
        Test.stopTest();

        Event__c ev = [SELECT Venue__c FROM Event__c LIMIT 1];
        System.assertEquals(null, ev.Venue__c);
    }

    @isTest
    static void batchMarksOnlyPastLiveEventsAsCompleted() {
        Venue__c venue = createVenue('Grand Hall', 300);
        Event__c past = newEvent('Past Expo', Date.today().addDays(-5), 'Planned', venue.Id);
        Event__c future = newEvent('Upcoming Expo', Date.today().addDays(20), 'Planned', null);
        Event__c oldCanceled = newEvent('Canceled Expo', Date.today().addDays(-10), 'Canceled', null);
        insert new List<Event__c>{ past, future, oldCanceled };

        Test.startTest();
        Database.executeBatch(new BatchCompleteEvents(), 200);
        Test.stopTest();

        Map<Id, Event__c> after = new Map<Id, Event__c>(
            [SELECT Id, Event_Status__c FROM Event__c]
        );
        System.assertEquals('Completed', after.get(past.Id).Event_Status__c);
        System.assertEquals('Planned', after.get(future.Id).Event_Status__c);
        System.assertEquals('Canceled', after.get(oldCanceled.Id).Event_Status__c);
        System.assertEquals('Available', venueStatus(venue.Id), 'The completed event should free its venue');
    }

    @isTest
    static void schedulableRunsTheBatch() {
        Venue__c venue = createVenue('Grand Hall', 300);
        insert newEvent('Past Expo', Date.today().addDays(-5), 'Planned', venue.Id);

        Test.startTest();
        System.schedule('Daily Event Completion Test', '0 0 20 * * ?', new ScheduleCompleteEvents());
        Test.stopTest();

        System.assertEquals('Completed', [SELECT Event_Status__c FROM Event__c LIMIT 1].Event_Status__c);
    }
}
