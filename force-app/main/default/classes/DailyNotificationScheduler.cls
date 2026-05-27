/**
 * @description Schedulable class for daily notifications
 * Schedule: Daily at 5 PM - "0 0 17 * * ?"
 */
public class DailyNotificationScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        // Send daily progress reminders
        NotificationService.sendDailyProgressReminder();
        
        // Notify about overdue tasks
        NotificationService.notifyOverdueTasks();
        
        // Notify about sprints ending soon
        NotificationService.notifySprintEndingSoon();
    }
}
