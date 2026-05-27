/**
 * @description Service class for managing Salesforce notifications
 * Handles both Bell notifications and Email notifications
 * All emails include direct links to the relevant records for one-click access
 */
public with sharing class NotificationService {
    
    /**
     * @description Get the base URL of the org for building record links
     * Returns Lightning Experience URL by default
     */
    public static String getOrgBaseUrl() {
        try {
            return URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            // Fallback if getOrgDomainUrl is not available
            return URL.getSalesforceBaseUrl().toExternalForm();
        }
    }
    
    /**
     * @description Build a Lightning record URL for the given record ID
     * Format: https://yourorg.lightning.force.com/lightning/r/ObjectName/RecordId/view
     */
    public static String buildRecordUrl(Id recordId) {
        if (recordId == null) return getOrgBaseUrl();
        return getOrgBaseUrl() + '/lightning/r/' + recordId + '/view';
    }
    
    /**
     * @description Build a Lightning app home URL
     */
    public static String buildAppUrl() {
        return getOrgBaseUrl() + '/lightning/app/c__Agile_Delivery_Management';
    }
    
    /**
     * @description Send bell notification to specific user
     */
    public static void sendBellNotification(Id userId, String title, String body, Id targetId) {
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
     * @description Send email notification with record link
     */
    public static void sendEmailNotification(Id userId, String subject, String body, Id targetId) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userId);
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            mail.setSaveAsActivity(false);
            if (targetId != null) {
                mail.setWhatId(targetId);
            }
            
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
     * @description Build a styled email button with record link
     */
    private static String buildButton(String label, String url) {
        return '<p style="margin-top:20px;">' +
               '<a href="' + url + '" style="background-color:#1B5297;color:#FFFFFF;padding:10px 20px;' +
               'text-decoration:none;border-radius:4px;display:inline-block;font-weight:bold;">' +
               label + '</a></p>';
    }
    
    /**
     * @description Build a standard email footer with helpful links
     */
    private static String buildEmailFooter() {
        String footer = '<hr style="margin-top:30px;border:none;border-top:1px solid #ddd;"/>';
        footer += '<p style="font-size:12px;color:#888;">';
        footer += 'This is an automated message from the Agile Delivery Management System.<br/>';
        footer += '<a href="' + buildAppUrl() + '">Open Agile Delivery Management App</a>';
        footer += '</p>';
        return footer;
    }
    
    /**
     * @description Notify assigned user when task is assigned
     * Email includes direct link to the task record
     */
    public static void notifyTaskAssignment(Id taskId, Id assignedUserId) {
        Task__c task = [
            SELECT Id, Name, Task_Title__c, Due_Date__c, Priority__c, Description__c,
                   User_Story__r.Story_Title__c, User_Story__r.Sprint__r.Name
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
        
        // Build email with record link
        String taskUrl = buildRecordUrl(taskId);
        String emailBody = '<p>Hello,</p>';
        emailBody += '<p>You have been assigned to a new task in the Agile Delivery Management system:</p>';
        emailBody += '<table style="border-collapse:collapse;margin:15px 0;">';
        emailBody += '<tr><td style="padding:5px 10px;"><strong>Task:</strong></td><td style="padding:5px 10px;">' + task.Task_Title__c + '</td></tr>';
        emailBody += '<tr><td style="padding:5px 10px;"><strong>Story:</strong></td><td style="padding:5px 10px;">' + task.User_Story__r.Story_Title__c + '</td></tr>';
        if (task.User_Story__r.Sprint__r != null) {
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Sprint:</strong></td><td style="padding:5px 10px;">' + task.User_Story__r.Sprint__r.Name + '</td></tr>';
        }
        if (task.Priority__c != null) {
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Priority:</strong></td><td style="padding:5px 10px;">' + task.Priority__c + '</td></tr>';
        }
        if (task.Due_Date__c != null) {
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Due Date:</strong></td><td style="padding:5px 10px;">' + task.Due_Date__c.format() + '</td></tr>';
        }
        emailBody += '</table>';
        if (task.Description__c != null) {
            emailBody += '<p><strong>Description:</strong><br/>' + task.Description__c + '</p>';
        }
        emailBody += buildButton('View Task', taskUrl);
        emailBody += '<p>Click the button above to view the task and start logging your progress.</p>';
        emailBody += buildEmailFooter();
        
        sendEmailNotification(assignedUserId, title, emailBody, taskId);
    }
    
    /**
     * @description Notify when story is ready for QA
     * Email includes direct link to the story record
     */
    public static void notifyStoryReadyForQA(Id storyId) {
        User_Story__c story = [
            SELECT Id, Name, Story_Title__c, Acceptance_Criteria__c, Sprint__r.Name
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
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
            
            // Build email with record link
            String storyUrl = buildRecordUrl(storyId);
            String emailBody = '<p>Hello QA Team,</p>';
            emailBody += '<p>The following user story is ready for QA testing:</p>';
            emailBody += '<table style="border-collapse:collapse;margin:15px 0;">';
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Story:</strong></td><td style="padding:5px 10px;">' + story.Story_Title__c + '</td></tr>';
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Sprint:</strong></td><td style="padding:5px 10px;">' + story.Sprint__r.Name + '</td></tr>';
            emailBody += '</table>';
            if (story.Acceptance_Criteria__c != null) {
                emailBody += '<p><strong>Acceptance Criteria:</strong><br/>' + story.Acceptance_Criteria__c + '</p>';
            }
            emailBody += buildButton('Review Story', storyUrl);
            emailBody += '<p>Please review the story details and begin testing.</p>';
            emailBody += buildEmailFooter();
            
            sendEmailNotificationBulk(qaUserIds, title, emailBody);
        }
    }
    
    /**
     * @description Notify developer when story is rejected by QA
     * Email includes direct link to the story record so dev can review and fix
     */
    public static void notifyStoryRejected(Id storyId, String rejectionReason) {
        User_Story__c story = [
            SELECT Id, Name, Story_Title__c, Assigned_To__c, Sprint__r.Name
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        if (story.Assigned_To__c != null) {
            String title = 'Story Rejected: ' + story.Story_Title__c;
            String body = 'Your story ' + story.Name + ' has been rejected by QA. Reason: ' + rejectionReason;
            
            sendBellNotification(story.Assigned_To__c, title, body, storyId);
            
            String storyUrl = buildRecordUrl(storyId);
            String emailBody = '<p>Hello,</p>';
            emailBody += '<p>Your user story has been rejected by QA and requires attention:</p>';
            emailBody += '<table style="border-collapse:collapse;margin:15px 0;">';
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Story:</strong></td><td style="padding:5px 10px;">' + story.Story_Title__c + '</td></tr>';
            emailBody += '<tr><td style="padding:5px 10px;"><strong>Sprint:</strong></td><td style="padding:5px 10px;">' + story.Sprint__r.Name + '</td></tr>';
            emailBody += '</table>';
            emailBody += '<div style="background-color:#FFF4F4;border-left:4px solid #C25454;padding:10px 15px;margin:15px 0;">';
            emailBody += '<p style="margin:0;"><strong>Rejection Reason:</strong></p>';
            emailBody += '<p style="margin:5px 0 0 0;">' + rejectionReason + '</p>';
            emailBody += '</div>';
            emailBody += buildButton('Review and Fix Story', storyUrl);
            emailBody += '<p>Please review the feedback, make the necessary corrections, and resubmit for QA.</p>';
            emailBody += buildEmailFooter();
            
            sendEmailNotification(story.Assigned_To__c, title, emailBody, storyId);
        }
    }
    
    /**
     * @description Notify when task becomes overdue
     * Email includes direct links to each overdue task
     */
    public static void notifyOverdueTasks() {
        List<Task__c> overdueTasks = [
            SELECT Id, Name, Task_Title__c, Assigned_To__c, Due_Date__c, Priority__c, Status__c,
                   User_Story__r.Story_Title__c
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
            
            sendBellNotification(userId, title, body, userTasks[0].Id);
            
            // Build email with links to each overdue task
            String emailBody = '<p>Hello,</p>';
            emailBody += '<p>You have <strong>' + count + ' overdue task' + (count > 1 ? 's' : '') + '</strong> that need your attention:</p>';
            emailBody += '<table style="border-collapse:collapse;width:100%;margin:15px 0;border:1px solid #ddd;">';
            emailBody += '<tr style="background-color:#f4f4f4;">';
            emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Task</th>';
            emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Story</th>';
            emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Due Date</th>';
            emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Priority</th>';
            emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Action</th>';
            emailBody += '</tr>';
            for (Task__c task : userTasks) {
                String taskUrl = buildRecordUrl(task.Id);
                emailBody += '<tr>';
                emailBody += '<td style="padding:8px;border:1px solid #ddd;"><strong>' + task.Task_Title__c + '</strong></td>';
                emailBody += '<td style="padding:8px;border:1px solid #ddd;">' + task.User_Story__r.Story_Title__c + '</td>';
                emailBody += '<td style="padding:8px;border:1px solid #ddd;color:#C25454;">' + task.Due_Date__c.format() + '</td>';
                emailBody += '<td style="padding:8px;border:1px solid #ddd;">' + (task.Priority__c != null ? task.Priority__c : '-') + '</td>';
                emailBody += '<td style="padding:8px;border:1px solid #ddd;"><a href="' + taskUrl + '">Open Task</a></td>';
                emailBody += '</tr>';
            }
            emailBody += '</table>';
            emailBody += '<p>Please update your progress, adjust due dates if needed, or mark tasks as blocked with reasons.</p>';
            emailBody += buildEmailFooter();
            
            sendEmailNotification(userId, title, emailBody, userTasks[0].Id);
        }
    }
    
    /**
     * @description Remind developers to log daily progress
     * Email includes link to the app to easily log progress
     */
    public static void sendDailyProgressReminder() {
        Date today = Date.today();
        
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
        
        Set<Id> developersWithProgressToday = new Set<Id>();
        for (Daily_Progress__c progress : [
            SELECT Developer__c
            FROM Daily_Progress__c
            WHERE Progress_Date__c = :today
            AND Developer__c IN :developersWithTasks
        ]) {
            developersWithProgressToday.add(progress.Developer__c);
        }
        
        Set<Id> developersNeedingReminder = new Set<Id>();
        for (Id devId : developersWithTasks) {
            if (!developersWithProgressToday.contains(devId)) {
                developersNeedingReminder.add(devId);
            }
        }
        
        // Get task list per developer for personalized email
        Map<Id, List<Task__c>> activeTasksByDeveloper = new Map<Id, List<Task__c>>();
        for (Task__c task : [
            SELECT Id, Task_Title__c, Status__c, Task_Progress__c, Due_Date__c, Assigned_To__c
            FROM Task__c
            WHERE Assigned_To__c IN :developersNeedingReminder
            AND Status__c IN ('In Progress', 'Blocked')
        ]) {
            if (!activeTasksByDeveloper.containsKey(task.Assigned_To__c)) {
                activeTasksByDeveloper.put(task.Assigned_To__c, new List<Task__c>());
            }
            activeTasksByDeveloper.get(task.Assigned_To__c).add(task);
        }
        
        if (!developersNeedingReminder.isEmpty()) {
            String title = 'Daily Progress Reminder';
            String body = 'Don\'t forget to log your daily progress for today!';
            
            for (Id userId : developersNeedingReminder) {
                sendBellNotification(userId, title, body, null);
                
                List<Task__c> userTasks = activeTasksByDeveloper.get(userId);
                String emailBody = '<p>Hello,</p>';
                emailBody += '<p>This is a friendly reminder to log your daily progress in the Agile Delivery Management system.</p>';
                
                if (userTasks != null && !userTasks.isEmpty()) {
                    emailBody += '<p>Your active tasks awaiting an update:</p>';
                    emailBody += '<table style="border-collapse:collapse;width:100%;margin:15px 0;border:1px solid #ddd;">';
                    emailBody += '<tr style="background-color:#f4f4f4;">';
                    emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Task</th>';
                    emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Status</th>';
                    emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Progress</th>';
                    emailBody += '<th style="padding:8px;text-align:left;border:1px solid #ddd;">Action</th>';
                    emailBody += '</tr>';
                    for (Task__c task : userTasks) {
                        String taskUrl = buildRecordUrl(task.Id);
                        Decimal progress = task.Task_Progress__c != null ? task.Task_Progress__c : 0;
                        emailBody += '<tr>';
                        emailBody += '<td style="padding:8px;border:1px solid #ddd;"><strong>' + task.Task_Title__c + '</strong></td>';
                        emailBody += '<td style="padding:8px;border:1px solid #ddd;">' + task.Status__c + '</td>';
                        emailBody += '<td style="padding:8px;border:1px solid #ddd;">' + progress.intValue() + '%</td>';
                        emailBody += '<td style="padding:8px;border:1px solid #ddd;"><a href="' + taskUrl + '">Log Progress</a></td>';
                        emailBody += '</tr>';
                    }
                    emailBody += '</table>';
                }
                
                emailBody += buildButton('Open Agile Delivery Management', buildAppUrl());
                emailBody += '<p>Keeping your progress up-to-date helps the team stay informed and ensures accurate sprint tracking.</p>';
                emailBody += buildEmailFooter();
                
                sendEmailNotification(userId, title, emailBody, null);
            }
        }
    }
    
    /**
     * @description Notify project manager when sprint is ending soon
     * Email includes direct link to the sprint
     */
    public static void notifySprintEndingSoon() {
        Date threeDaysFromNow = Date.today().addDays(3);
        
        List<Sprint__c> endingSprints = [
            SELECT Id, Name, End_Date__c, Sprint_Progress__c, Total_Story_Points__c, 
                   Completed_Story_Points__c, Project__r.Name, Project__r.Project_Manager__c
            FROM Sprint__c
            WHERE Status__c = 'Active'
            AND End_Date__c <= :threeDaysFromNow
            AND End_Date__c >= :Date.today()
        ];
        
        for (Sprint__c sprint : endingSprints) {
            if (sprint.Project__r.Project_Manager__c != null) {
                Integer daysRemaining = Date.today().daysBetween(sprint.End_Date__c);
                String title = 'Sprint Ending Soon: ' + sprint.Name;
                Decimal progress = sprint.Sprint_Progress__c != null ? sprint.Sprint_Progress__c : 0;
                String body = sprint.Name + ' ends in ' + daysRemaining + ' day' + (daysRemaining != 1 ? 's' : '') + '. Current progress: ' + progress.intValue() + '%';
                
                sendBellNotification(sprint.Project__r.Project_Manager__c, title, body, sprint.Id);
                
                // Build email with sprint link
                String sprintUrl = buildRecordUrl(sprint.Id);
                String emailBody = '<p>Hello,</p>';
                emailBody += '<p>The following sprint is ending soon and may need attention:</p>';
                emailBody += '<table style="border-collapse:collapse;margin:15px 0;">';
                emailBody += '<tr><td style="padding:5px 10px;"><strong>Sprint:</strong></td><td style="padding:5px 10px;">' + sprint.Name + '</td></tr>';
                emailBody += '<tr><td style="padding:5px 10px;"><strong>Project:</strong></td><td style="padding:5px 10px;">' + sprint.Project__r.Name + '</td></tr>';
                emailBody += '<tr><td style="padding:5px 10px;"><strong>End Date:</strong></td><td style="padding:5px 10px;">' + sprint.End_Date__c.format() + '</td></tr>';
                emailBody += '<tr><td style="padding:5px 10px;"><strong>Days Remaining:</strong></td><td style="padding:5px 10px;color:#C25454;"><strong>' + daysRemaining + '</strong></td></tr>';
                emailBody += '<tr><td style="padding:5px 10px;"><strong>Progress:</strong></td><td style="padding:5px 10px;">' + progress.intValue() + '%</td></tr>';
                if (sprint.Total_Story_Points__c != null && sprint.Completed_Story_Points__c != null) {
                    emailBody += '<tr><td style="padding:5px 10px;"><strong>Story Points:</strong></td><td style="padding:5px 10px;">' + sprint.Completed_Story_Points__c.intValue() + ' / ' + sprint.Total_Story_Points__c.intValue() + '</td></tr>';
                }
                emailBody += '</table>';
                emailBody += buildButton('View Sprint Dashboard', sprintUrl);
                emailBody += '<p>Review the sprint and take any necessary action to ensure on-time delivery.</p>';
                emailBody += buildEmailFooter();
                
                sendEmailNotification(sprint.Project__r.Project_Manager__c, title, emailBody, sprint.Id);
            }
        }
    }
}
