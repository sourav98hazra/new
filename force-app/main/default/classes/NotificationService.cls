/**
 * @description Service class for managing Salesforce notifications
 * Handles both Bell notifications and Email notifications
 */
public with sharing class NotificationService {
    
    /**
     * @description Send bell notification to specific user
     */
    public static void sendBellNotification(Id userId, String title, String body, Id targetId) {
        try {
            // Create custom notification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            
            // Get custom notification type
            CustomNotificationType notificationType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'ADM_Task_Notification' 
                LIMIT 1
            ];
            
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTitle(title);
            notification.setBody(body);
            notification.setTargetId(targetId);
            
            // Send to specific user
            Set<String> recipientIds = new Set<String>{ userId };
            notification.send(recipientIds);
            
        } catch (Exception e) {
            System.debug('Error sending bell notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Send bell notification to multiple users
     */
    public static void sendBellNotificationBulk(Set<Id> userIds, String title, String body, Id targetId) {
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            
            CustomNotificationType notificationType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'ADM_Task_Notification' 
                LIMIT 1
            ];
            
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTitle(title);
            notification.setBody(body);
            notification.setTargetId(targetId);
            
            // Convert Set to Set<String>
            Set<String> recipientIds = new Set<String>();
            for (Id userId : userIds) {
                recipientIds.add(String.valueOf(userId));
            }
            
            notification.send(recipientIds);
            
        } catch (Exception e) {
            System.debug('Error sending bulk bell notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Send email notification
     */
    public static void sendEmailNotification(Id userId, String subject, String body, Id targetId) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userId);
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            mail.setSaveAsActivity(false);
            mail.setWhatId(targetId);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending email notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Send email notification to multiple users
     */
    public static void sendEmailNotificationBulk(Set<Id> userIds, String subject, String body) {
        try {
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Id userId : userIds) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(userId);
                mail.setSubject(subject);
                mail.setHtmlBody(body);
                mail.setSaveAsActivity(false);
                emails.add(mail);
            }
            
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
            
        } catch (Exception e) {
            System.debug('Error sending bulk email notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Notify assigned user when task is assigned
     */
    public static void notifyTaskAssignment(Id taskId, Id assignedUserId) {
        Task__c task = [
            SELECT Id, Name, Task_Title__c, Due_Date__c, User_Story__r.Story_Title__c
            FROM Task__c
            WHERE Id = :taskId
            LIMIT 1
        ];
        
        String title = 'New Task Assigned: ' + task.Task_Title__c;
        String body = 'You have been assigned to task: ' + task.Task_Title__c;
        if (task.Due_Date__c != null) {
            body += ' (Due: ' + task.Due_Date__c.format() + ')';
        }
        
        sendBellNotification(assignedUserId, title, body, taskId);
        
        // Also send email
        String emailBody = '<p>Hello,</p>';
        emailBody += '<p>You have been assigned to the following task:</p>';
        emailBody += '<p><strong>' + task.Task_Title__c + '</strong></p>';
        emailBody += '<p>Story: ' + task.User_Story__r.Story_Title__c + '</p>';
        if (task.Due_Date__c != null) {
            emailBody += '<p>Due Date: ' + task.Due_Date__c.format() + '</p>';
        }
        emailBody += '<p>Please log in to Salesforce to view details.</p>';
        
        sendEmailNotification(assignedUserId, title, emailBody, taskId);
    }
    
    /**
     * @description Notify when story is ready for QA
     */
    public static void notifyStoryReadyForQA(Id storyId) {
        User_Story__c story = [
            SELECT Id, Name, Story_Title__c, Sprint__r.Name
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        // Get QA team members
        List<PermissionSetAssignment> qaUsers = [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'ADM_QA'
            AND Assignee.IsActive = true
        ];
        
        Set<Id> qaUserIds = new Set<Id>();
        for (PermissionSetAssignment psa : qaUsers) {
            qaUserIds.add(psa.AssigneeId);
        }
        
        if (!qaUserIds.isEmpty()) {
            String title = 'Story Ready for QA: ' + story.Story_Title__c;
            String body = story.Name + ' - ' + story.Story_Title__c + ' is ready for QA testing in ' + story.Sprint__r.Name;
            
            sendBellNotificationBulk(qaUserIds, title, body, storyId);
        }
    }
    
    /**
     * @description Notify developer when story is rejected by QA
     */
    public static void notifyStoryRejected(Id storyId, String rejectionReason) {
        User_Story__c story = [
            SELECT Id, Name, Story_Title__c, Assigned_To__c
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        if (story.Assigned_To__c != null) {
            String title = 'Story Rejected: ' + story.Story_Title__c;
            String body = 'Your story ' + story.Name + ' has been rejected by QA. Reason: ' + rejectionReason;
            
            sendBellNotification(story.Assigned_To__c, title, body, storyId);
            
            String emailBody = '<p>Hello,</p>';
            emailBody += '<p>Your story has been rejected by QA:</p>';
            emailBody += '<p><strong>' + story.Story_Title__c + '</strong></p>';
            emailBody += '<p><strong>Rejection Reason:</strong> ' + rejectionReason + '</p>';
            emailBody += '<p>Please review the feedback and make necessary corrections.</p>';
            
            sendEmailNotification(story.Assigned_To__c, title, emailBody, storyId);
        }
    }
    
    /**
     * @description Notify when task becomes overdue
     */
    public static void notifyOverdueTasks() {
        List<Task__c> overdueTasks = [
            SELECT Id, Name, Task_Title__c, Assigned_To__c, Due_Date__c, User_Story__r.Story_Title__c
            FROM Task__c
            WHERE Is_Overdue__c = true
            AND Status__c != 'Completed'
            AND Assigned_To__c != null
        ];
        
        Map<Id, List<Task__c>> tasksByUser = new Map<Id, List<Task__c>>();
        for (Task__c task : overdueTasks) {
            if (!tasksByUser.containsKey(task.Assigned_To__c)) {
                tasksByUser.put(task.Assigned_To__c, new List<Task__c>());
            }
            tasksByUser.get(task.Assigned_To__c).add(task);
        }
        
        for (Id userId : tasksByUser.keySet()) {
            List<Task__c> userTasks = tasksByUser.get(userId);
            Integer count = userTasks.size();
            
            String title = 'You have ' + count + ' overdue task' + (count > 1 ? 's' : '');
            String body = 'Please review and update your overdue tasks.';
            
            // Send notification for first task
            sendBellNotification(userId, title, body, userTasks[0].Id);
            
            // Send email with list of all overdue tasks
            String emailBody = '<p>Hello,</p>';
            emailBody += '<p>You have the following overdue tasks:</p><ul>';
            for (Task__c task : userTasks) {
                emailBody += '<li><strong>' + task.Task_Title__c + '</strong> - Due: ' + task.Due_Date__c.format() + '</li>';
            }
            emailBody += '</ul><p>Please update your progress or adjust due dates accordingly.</p>';
            
            sendEmailNotification(userId, title, emailBody, userTasks[0].Id);
        }
    }
    
    /**
     * @description Remind developers to log daily progress
     */
    public static void sendDailyProgressReminder() {
        // Get developers who haven't logged progress today
        Date today = Date.today();
        
        // Get all developers with assigned incomplete tasks
        Set<Id> developersWithTasks = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Assigned_To__c
            FROM Task__c
            WHERE Status__c IN ('In Progress', 'Blocked')
            AND Assigned_To__c != null
            GROUP BY Assigned_To__c
        ]) {
            developersWithTasks.add((Id)ar.get('Assigned_To__c'));
        }
        
        // Get developers who already logged progress today
        Set<Id> developersWithProgressToday = new Set<Id>();
        for (Daily_Progress__c progress : [
            SELECT Developer__c
            FROM Daily_Progress__c
            WHERE Progress_Date__c = :today
            AND Developer__c IN :developersWithTasks
        ]) {
            developersWithProgressToday.add(progress.Developer__c);
        }
        
        // Find developers who need reminder
        Set<Id> developersNeedingReminder = new Set<Id>();
        for (Id devId : developersWithTasks) {
            if (!developersWithProgressToday.contains(devId)) {
                developersNeedingReminder.add(devId);
            }
        }
        
        // Send reminders
        if (!developersNeedingReminder.isEmpty()) {
            String title = 'Daily Progress Reminder';
            String body = 'Don\'t forget to log your daily progress for today!';
            
            String emailBody = '<p>Hello,</p>';
            emailBody += '<p>This is a friendly reminder to log your daily progress for today.</p>';
            emailBody += '<p>Please update your task progress in the Agile Delivery Management system.</p>';
            
            for (Id userId : developersNeedingReminder) {
                sendBellNotification(userId, title, body, null);
                sendEmailNotification(userId, title, emailBody, null);
            }
        }
    }
    
    /**
     * @description Notify team lead when sprint is ending soon
     */
    public static void notifySprintEndingSoon() {
        Date threeDaysFromNow = Date.today().addDays(3);
        
        List<Sprint__c> endingSprints = [
            SELECT Id, Name, End_Date__c, Sprint_Progress__c, Project__r.Project_Manager__c
            FROM Sprint__c
            WHERE Status__c = 'Active'
            AND End_Date__c <= :threeDaysFromNow
            AND End_Date__c >= :Date.today()
        ];
        
        for (Sprint__c sprint : endingSprints) {
            if (sprint.Project__r.Project_Manager__c != null) {
                Integer daysRemaining = Date.today().daysBetween(sprint.End_Date__c);
                String title = 'Sprint Ending Soon: ' + sprint.Name;
                String body = sprint.Name + ' ends in ' + daysRemaining + ' days. Current progress: ' + sprint.Sprint_Progress__c.intValue() + '%';
                
                sendBellNotification(sprint.Project__r.Project_Manager__c, title, body, sprint.Id);
            }
        }
    }
}
