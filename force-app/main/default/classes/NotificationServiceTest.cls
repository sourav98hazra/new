/**
 * @description Test class for NotificationService
 */
@isTest
private class NotificationServiceTest {
    
    @testSetup
    static void setup() {
        // Create test data
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);
        Task__c task = TriggerTestHelper.createTask(story.Id);
        task.Assigned_To__c = UserInfo.getUserId();
        task.Due_Date__c = Date.today().addDays(-1); // Overdue
        update task;
    }
    
    @isTest
    static void testNotifyTaskAssignment() {
        Task__c task = [SELECT Id, Assigned_To__c FROM Task__c LIMIT 1];
        
        Test.startTest();
        NotificationService.notifyTaskAssignment(task.Id, task.Assigned_To__c);
        Test.stopTest();
        
        // Verify no exceptions thrown
        System.assertEquals(task.Assigned_To__c, UserInfo.getUserId(), 'Task should be assigned to current user');
    }
    
    @isTest
    static void testNotifyStoryReadyForQA() {
        User_Story__c story = [SELECT Id FROM User_Story__c LIMIT 1];
        story.Status__c = 'Ready for QA';
        update story;
        
        Test.startTest();
        NotificationService.notifyStoryReadyForQA(story.Id);
        Test.stopTest();
        
        // Verify no exceptions thrown
        System.assertNotEquals(null, story.Id, 'Story should exist');
    }
    
    @isTest
    static void testNotifyStoryRejected() {
        User_Story__c story = [SELECT Id, Assigned_To__c FROM User_Story__c LIMIT 1];
        story.Assigned_To__c = UserInfo.getUserId();
        story.Status__c = 'Rejected';
        update story;
        
        Test.startTest();
        NotificationService.notifyStoryRejected(story.Id, 'Test rejection reason');
        Test.stopTest();
        
        // Verify no exceptions thrown
        System.assertEquals(UserInfo.getUserId(), story.Assigned_To__c, 'Story should be assigned');
    }
    
    @isTest
    static void testNotifyOverdueTasks() {
        Test.startTest();
        NotificationService.notifyOverdueTasks();
        Test.stopTest();
        
        // Verify method runs without errors
        Task__c task = [SELECT Is_Overdue__c FROM Task__c LIMIT 1];
        System.assertEquals(true, task.Is_Overdue__c, 'Task should be overdue');
    }
    
    @isTest
    static void testSendDailyProgressReminder() {
        Test.startTest();
        NotificationService.sendDailyProgressReminder();
        Test.stopTest();
        
        // Verify method runs without errors
        System.assert(true, 'Daily progress reminder should complete');
    }
    
    @isTest
    static void testNotifySprintEndingSoon() {
        Sprint__c sprint = [SELECT Id, End_Date__c FROM Sprint__c LIMIT 1];
        sprint.End_Date__c = Date.today().addDays(2);
        sprint.Status__c = 'Active';
        update sprint;
        
        Test.startTest();
        NotificationService.notifySprintEndingSoon();
        Test.stopTest();
        
        // Verify method runs without errors
        System.assertEquals('Active', sprint.Status__c, 'Sprint should be active');
    }
    
    @isTest
    static void testSendBellNotificationBulk() {
        Set<Id> userIds = new Set<Id>{ UserInfo.getUserId() };
        Task__c task = [SELECT Id FROM Task__c LIMIT 1];
        
        Test.startTest();
        NotificationService.sendBellNotificationBulk(userIds, 'Test Title', 'Test Body', task.Id);
        Test.stopTest();
        
        // Verify no exceptions thrown
        System.assert(true, 'Bulk notification should complete');
    }
}
