public class SeedEventForceData {

    // Change this to an inbox you can open. The 3-day reminder flow and the
    // cancellation approval both send client emails to Anita Desai.
    private static final String DEMO_INBOX = 'put.your.email@example.com';

    public static void seed() {
        if ([SELECT COUNT() FROM Event__c] > 0) {
            throw new SeedException('Event records already exist. Run SeedEventForceData.wipe() first.');
        }

        Date today = Date.today();

        List<Client__c> clients = new List<Client__c>{
            new Client__c(Name = 'Priya Sharma', Email__c = 'priya.sharma@novatech.in',
                          Phone__c = '9876543210', Address__c = '12 Anna Nagar East',
                          City__c = 'Chennai', Country__c = 'India'),
            new Client__c(Name = 'Rahul Verma', Email__c = 'rahul.verma@brightweddings.in',
                          Phone__c = '9812345678', Address__c = '45 Marine Drive',
                          City__c = 'Mumbai', Country__c = 'India'),
            new Client__c(Name = 'Anita Desai', Email__c = DEMO_INBOX,
                          Phone__c = '9900112233', Address__c = '7 MG Road',
                          City__c = 'Bengaluru', Country__c = 'India'),
            new Client__c(Name = 'Karan Malhotra', Email__c = 'karan.m@freshersmeet.org',
                          Phone__c = '9765432109', Address__c = '22 Connaught Place',
                          City__c = 'Delhi', Country__c = 'India')
        };
        insert clients;

        List<Venue__c> venues = new List<Venue__c>{
            new Venue__c(Name = 'Grand Convention Hall', Address__c = 'Anna Salai, Chennai',
                         Location__c = 'https://maps.google.com/?q=Anna+Salai+Chennai',
                         Capacity__c = 500, Availability_Status__c = 'Available'),
            new Venue__c(Name = 'Seaside Resort Lawns', Address__c = 'East Coast Road, Chennai',
                         Location__c = 'https://maps.google.com/?q=ECR+Chennai',
                         Capacity__c = 250, Availability_Status__c = 'Available'),
            new Venue__c(Name = 'Metro Business Centre', Address__c = 'Bandra Kurla Complex, Mumbai',
                         Location__c = 'https://maps.google.com/?q=BKC+Mumbai',
                         Capacity__c = 180, Availability_Status__c = 'Available'),
            new Venue__c(Name = 'Palace Grounds Pavilion', Address__c = 'Palace Road, Bengaluru',
                         Location__c = 'https://maps.google.com/?q=Palace+Grounds+Bengaluru',
                         Capacity__c = 800, Availability_Status__c = 'Available')
        };
        insert venues;

        List<Vendor__c> vendors = new List<Vendor__c>{
            new Vendor__c(Name = 'Spice Route Caterers', Email__c = 'bookings@spiceroute.in',
                          Phone__c = '9840011223', Service_Type__c = 'Catering', Status__c = 'Active'),
            new Vendor__c(Name = 'Bloom Decor Studio', Email__c = 'hello@bloomdecor.in',
                          Phone__c = '9840022334', Service_Type__c = 'Decor', Status__c = 'Active'),
            new Vendor__c(Name = 'QuickMove Logistics', Email__c = 'ops@quickmove.in',
                          Phone__c = '9840033445', Service_Type__c = 'Logistics', Status__c = 'Active'),
            new Vendor__c(Name = 'PixelFrame Photography', Email__c = 'studio@pixelframe.in',
                          Phone__c = '9840044556', Service_Type__c = 'Photography', Status__c = 'Active'),
            new Vendor__c(Name = 'BassLine DJ Services', Email__c = 'book@bassline.in',
                          Phone__c = '9840055667', Service_Type__c = 'Music/DJ', Status__c = 'Active'),
            new Vendor__c(Name = 'Legacy Sound & Light', Email__c = 'info@legacysl.in',
                          Phone__c = '9840066778', Service_Type__c = 'Lighting', Status__c = 'Inactive')
        };
        insert vendors;

        Map<String, Client__c> clientByName = new Map<String, Client__c>();
        for (Client__c c : clients) {
            clientByName.put(c.Name, c);
        }
        Map<String, Venue__c> venueByName = new Map<String, Venue__c>();
        for (Venue__c v : venues) {
            venueByName.put(v.Name, v);
        }
        Map<String, Vendor__c> vendorByName = new Map<String, Vendor__c>();
        for (Vendor__c v : vendors) {
            vendorByName.put(v.Name, v);
        }

        List<Event__c> events = new List<Event__c>{
            new Event__c(Name = 'TechNova Annual Summit', Event_Date__c = today.addDays(-107),
                         Event_Type__c = 'Conference', Event_Status__c = 'Planned', Event_Budget__c = 850000,
                         Client__c = clientByName.get('Anita Desai').Id,
                         Venue__c = venueByName.get('Metro Business Centre').Id),
            new Event__c(Name = 'Verma Wedding Reception', Event_Date__c = today.addDays(-72),
                         Event_Type__c = 'Wedding', Event_Status__c = 'Planned', Event_Budget__c = 1200000,
                         Client__c = clientByName.get('Rahul Verma').Id,
                         Venue__c = venueByName.get('Palace Grounds Pavilion').Id),
            new Event__c(Name = 'Freshers Meet 2026', Event_Date__c = today.addDays(-51),
                         Event_Type__c = 'Seminar', Event_Status__c = 'Planned', Event_Budget__c = 150000,
                         Client__c = clientByName.get('Karan Malhotra').Id,
                         Venue__c = venueByName.get('Grand Convention Hall').Id),
            new Event__c(Name = 'Startup Networking Night', Event_Date__c = today.addDays(-5),
                         Event_Type__c = 'Corporate', Event_Status__c = 'Canceled', Event_Budget__c = 180000,
                         Client__c = clientByName.get('Rahul Verma').Id,
                         Venue__c = venueByName.get('Grand Convention Hall').Id),
            new Event__c(Name = 'Product Launch Nova X', Event_Date__c = today.addDays(3),
                         Event_Type__c = 'Corporate', Event_Status__c = 'Planned', Event_Budget__c = 600000,
                         Client__c = clientByName.get('Priya Sharma').Id,
                         Venue__c = venueByName.get('Seaside Resort Lawns').Id),
            new Event__c(Name = 'Sharma Anniversary Dinner', Event_Date__c = today.addDays(18),
                         Event_Type__c = 'Birthday', Event_Status__c = 'Planned', Event_Budget__c = 250000,
                         Client__c = clientByName.get('Priya Sharma').Id,
                         Venue__c = venueByName.get('Grand Convention Hall').Id),
            new Event__c(Name = 'GlobalCorp Leadership Offsite', Event_Date__c = today.addDays(39),
                         Event_Type__c = 'Corporate', Event_Status__c = 'Planned', Event_Budget__c = 950000,
                         Client__c = clientByName.get('Anita Desai').Id,
                         Venue__c = venueByName.get('Metro Business Centre').Id),
            new Event__c(Name = 'Winter Music Festival', Event_Date__c = today.addDays(53),
                         Event_Type__c = 'Concert', Event_Status__c = 'Planned', Event_Budget__c = 1500000,
                         Client__c = clientByName.get('Karan Malhotra').Id,
                         Venue__c = venueByName.get('Palace Grounds Pavilion').Id),
            new Event__c(Name = 'Tech Expo 2026', Event_Date__c = today.addDays(66),
                         Event_Type__c = 'Exhibition', Event_Status__c = 'Planned', Event_Budget__c = 700000,
                         Client__c = clientByName.get('Priya Sharma').Id,
                         Venue__c = venueByName.get('Grand Convention Hall').Id),
            new Event__c(Name = 'Desai Silver Jubilee', Event_Date__c = today.addDays(108),
                         Event_Type__c = 'Wedding', Event_Status__c = 'Planned', Event_Budget__c = 1100000,
                         Client__c = clientByName.get('Anita Desai').Id,
                         Venue__c = venueByName.get('Seaside Resort Lawns').Id)
        };
        insert events;

        Map<String, Event__c> eventByName = new Map<String, Event__c>();
        for (Event__c e : events) {
            eventByName.put(e.Name, e);
        }

        List<EventVendor__c> assignments = new List<EventVendor__c>{
            assignment(eventByName, vendorByName, 'TechNova Annual Summit', 'Spice Route Caterers', 320000),
            assignment(eventByName, vendorByName, 'TechNova Annual Summit', 'Bloom Decor Studio', 140000),
            assignment(eventByName, vendorByName, 'TechNova Annual Summit', 'QuickMove Logistics', 60000),
            assignment(eventByName, vendorByName, 'Verma Wedding Reception', 'Spice Route Caterers', 480000),
            assignment(eventByName, vendorByName, 'Verma Wedding Reception', 'Bloom Decor Studio', 260000),
            assignment(eventByName, vendorByName, 'Verma Wedding Reception', 'PixelFrame Photography', 150000),
            assignment(eventByName, vendorByName, 'Verma Wedding Reception', 'BassLine DJ Services', 90000),
            assignment(eventByName, vendorByName, 'Freshers Meet 2026', 'Spice Route Caterers', 55000),
            assignment(eventByName, vendorByName, 'Freshers Meet 2026', 'Legacy Sound & Light', 25000),
            assignment(eventByName, vendorByName, 'Product Launch Nova X', 'Bloom Decor Studio', 210000),
            assignment(eventByName, vendorByName, 'Product Launch Nova X', 'PixelFrame Photography', 120000),
            assignment(eventByName, vendorByName, 'Product Launch Nova X', 'QuickMove Logistics', 70000),
            assignment(eventByName, vendorByName, 'Winter Music Festival', 'BassLine DJ Services', 750000),
            assignment(eventByName, vendorByName, 'Winter Music Festival', 'Legacy Sound & Light', 400000),
            assignment(eventByName, vendorByName, 'Winter Music Festival', 'QuickMove Logistics', 250000),
            assignment(eventByName, vendorByName, 'Winter Music Festival', 'Bloom Decor Studio', 200000),
            assignment(eventByName, vendorByName, 'Tech Expo 2026', 'Spice Route Caterers', 150000),
            assignment(eventByName, vendorByName, 'Tech Expo 2026', 'Bloom Decor Studio', 190000),
            assignment(eventByName, vendorByName, 'Tech Expo 2026', 'PixelFrame Photography', 95000),
            assignment(eventByName, vendorByName, 'Desai Silver Jubilee', 'Spice Route Caterers', 520000),
            assignment(eventByName, vendorByName, 'Desai Silver Jubilee', 'Bloom Decor Studio', 300000),
            assignment(eventByName, vendorByName, 'Desai Silver Jubilee', 'BassLine DJ Services', 120000)
        };
        insert assignments;

        List<Feedback__c> feedback = new List<Feedback__c>{
            new Feedback__c(Rating__c = 5, Event__c = eventByName.get('TechNova Annual Summit').Id,
                            Client__c = clientByName.get('Anita Desai').Id,
                            Comments__c = 'Seamless coordination; the venue and catering were excellent.'),
            new Feedback__c(Rating__c = 4, Event__c = eventByName.get('Verma Wedding Reception').Id,
                            Client__c = clientByName.get('Rahul Verma').Id,
                            Comments__c = 'Beautiful decor, but photography delivery was slightly delayed.'),
            new Feedback__c(Rating__c = 2, Event__c = eventByName.get('Freshers Meet 2026').Id,
                            Client__c = clientByName.get('Karan Malhotra').Id,
                            Comments__c = 'The sound system failed during the opening session.'),
            new Feedback__c(Rating__c = 5, Event__c = eventByName.get('Product Launch Nova X').Id,
                            Client__c = clientByName.get('Priya Sharma').Id,
                            Comments__c = 'The coordinator team was responsive throughout the planning phase.'),
            new Feedback__c(Rating__c = 3, Event__c = eventByName.get('Startup Networking Night').Id,
                            Client__c = clientByName.get('Rahul Verma').Id,
                            Comments__c = 'The event was canceled late and the refund process was unclear.')
        };
        insert feedback;

        System.debug('Seeded ' + clients.size() + ' clients, ' + venues.size() + ' venues, '
            + vendors.size() + ' vendors, ' + events.size() + ' events, '
            + assignments.size() + ' vendor assignments and ' + feedback.size() + ' feedback records.');
    }

    // Destructive: clears every EventForce record so seed() can run again.
    public static void wipe() {
        delete [SELECT Id FROM EventVendor__c];
        delete [SELECT Id FROM Feedback__c];
        delete [SELECT Id FROM Event__c];
        delete [SELECT Id FROM Venue__c];
        delete [SELECT Id FROM Vendor__c];
        delete [SELECT Id FROM Client__c];
    }

    private static EventVendor__c assignment(Map<String, Event__c> events, Map<String, Vendor__c> vendors,
                                             String eventName, String vendorName, Decimal cost) {
        return new EventVendor__c(Event__c = events.get(eventName).Id,
                                  Vendor__c = vendors.get(vendorName).Id,
                                  Estimated_Cost__c = cost);
    }

    public class SeedException extends Exception {}
}
