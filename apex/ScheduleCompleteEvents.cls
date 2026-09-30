global class ScheduleCompleteEvents implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new BatchCompleteEvents(), 200);
    }
}
