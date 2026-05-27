/**
 * @description Test class for StatusManagementService
 */
@isTest
private class StatusManagementServiceTest {
    
    @testSetup
    static void setup() {
        Project__c project = new Project__c(Name = 'Test Project', Status__c = 'Active');
        insert project;
        
        Sprint__c sprint = new Sprint__c(
            Name = 'Sprint 1',
            Project__c = project.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(14)
        );
        insert sprint;
        
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Test Story',
            Sprint__c = sprint.Id,
            Status__c = 'New',
            Story_Progress__c = 0
        );
        insert story;
        
        Task__c task = new Task__c(
            Task_Title__c = 'Test Task',
            User_Story__c = story.Id,
            Status__c = 'New',
            Task_Progress__c = 0
        );
        insert task;
    }
    
    @isTest
    static void testUpdateTaskStatus() {
        Task__c task = [SELECT Id, Status__c, Task_Progress__c FROM Task__c LIMIT 1];
        task.Task_Progress__c = 100;
        
        Test.startTest();
        StatusManagementService.updateTaskStatus(new List<Task__c>{ task });
        Test.stopTest();
        
        Task__c updatedTask = [SELECT Status__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals('Completed', updatedTask.Status__c, 'Task should be marked as completed');
    }
    
    @isTest
    static void testHandleQAApproval() {
        User_Story__c story = [SELECT Id FROM User_Story__c LIMIT 1];
        story.Status__c = 'In QA';
        update story;
        
        Test.startTest();
        StatusManagementService.handleQAApproval(story.Id, true, 'Looks good!');
        Test.stopTest();
        
        User_Story__c updatedStory = [SELECT Status__c, QA_Notes__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('QA Approved', updatedStory.Status__c, 'Story should be QA approved');
        System.assertEquals('Looks good!', updatedStory.QA_Notes__c, 'QA notes should be saved');
    }
    
    @isTest
    static void testReopenStory() {
        User_Story__c story = [SELECT Id FROM User_Story__c LIMIT 1];
        story.Status__c = 'In QA';
        update story;
        
        Test.startTest();
        StatusManagementService.reopenStory(story.Id, 'Bug found');
        Test.stopTest();
        
        User_Story__c updatedStory = [SELECT Status__c, Rejection_Reason__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('In Progress', updatedStory.Status__c, 'Story should be reopened');
        System.assertEquals('Bug found', updatedStory.Rejection_Reason__c, 'Rejection reason should be saved');
    }
}
