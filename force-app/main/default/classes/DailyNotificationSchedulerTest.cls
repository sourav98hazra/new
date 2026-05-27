/**
 * @description Test class for DailyNotificationScheduler
 */
@isTest
private class DailyNotificationSchedulerTest {
    
    @testSetup
    static void setup() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);
        Task__c task = TriggerTestHelper.createTask(story.Id);
        task.Assigned_To__c = UserInfo.getUserId();
        task.Due_Date__c = Date.today().addDays(-1);
        update task;
    }
    
    @isTest
    static void testSchedulerExecution() {
        Test.startTest();
        
        String cronExp = '0 0 17 * * ?';
        String jobId = System.schedule('Daily Notification Test', cronExp, new DailyNotificationScheduler());
        
        // Verify job scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled');
        
        // Execute the job immediately for testing
        DailyNotificationScheduler scheduler = new DailyNotificationScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify no exceptions thrown
        System.assert(true, 'Scheduler should execute successfully');
    }
}
