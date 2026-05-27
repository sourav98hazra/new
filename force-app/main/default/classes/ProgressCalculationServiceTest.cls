/**
 * @description Test class for ProgressCalculationService
 */
@isTest
private class ProgressCalculationServiceTest {
    
    @testSetup
    static void setup() {
        // Create test data hierarchy
        Project__c project = new Project__c(
            Name = 'Test Project',
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30)
        );
        insert project;
        
        Sprint__c sprint = new Sprint__c(
            Name = 'Sprint 1',
            Project__c = project.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(14)
        );
        insert sprint;
        
        Feature__c feature = new Feature__c(
            Name = 'Test Feature',
            Sprint__c = sprint.Id,
            Status__c = 'In Progress'
        );
        insert feature;
        
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Test Story',
            Sprint__c = sprint.Id,
            Feature__c = feature.Id,
            Status__c = 'In Progress',
            Story_Points__c = 5,
            Estimated_Hours__c = 40
        );
        insert story;
        
        Task__c task = new Task__c(
            Task_Title__c = 'Test Task',
            User_Story__c = story.Id,
            Status__c = 'In Progress',
            Estimated_Hours__c = 20,
            Assigned_To__c = UserInfo.getUserId()
        );
        insert task;
    }
    
    @isTest
    static void testCalculateTaskProgress() {
        Task__c task = [SELECT Id FROM Task__c LIMIT 1];
        
        // Create daily progress entry
        Daily_Progress__c progress = new Daily_Progress__c(
            Task__c = task.Id,
            Hours_Worked__c = 10,
            Progress_Percentage__c = 50,
            Progress_Date__c = Date.today(),
            Developer__c = UserInfo.getUserId()
        );
        insert progress;
        
        Test.startTest();
        ProgressCalculationService.calculateTaskProgress(new Set<Id>{ task.Id });
        Test.stopTest();
        
        Task__c updatedTask = [SELECT Task_Progress__c, Actual_Hours__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(10, updatedTask.Actual_Hours__c, 'Actual hours should be 10');
        System.assertEquals(50, updatedTask.Task_Progress__c, 'Task progress should be 50%');
    }
    
    @isTest
    static void testCalculateStoryProgress() {
        User_Story__c story = [SELECT Id FROM User_Story__c LIMIT 1];
        Task__c task = [SELECT Id FROM Task__c LIMIT 1];
        
        // Update task progress
        task.Task_Progress__c = 50;
        update task;
        
        Test.startTest();
        ProgressCalculationService.calculateStoryProgress(new Set<Id>{ story.Id });
        Test.stopTest();
        
        User_Story__c updatedStory = [SELECT Story_Progress__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals(50, updatedStory.Story_Progress__c, 'Story progress should be 50%');
    }
    
    @isTest
    static void testCascadeProgressCalculation() {
        Task__c task = [SELECT Id FROM Task__c LIMIT 1];
        
        // Create daily progress
        Daily_Progress__c progress = new Daily_Progress__c(
            Task__c = task.Id,
            Hours_Worked__c = 20,
            Progress_Percentage__c = 100,
            Progress_Date__c = Date.today()
        );
        insert progress;
        
        Test.startTest();
        ProgressCalculationService.cascadeProgressCalculation(new Set<Id>{ task.Id });
        Test.stopTest();
        
        // Verify cascade
        Project__c project = [SELECT Overall_Progress__c FROM Project__c LIMIT 1];
        System.assertNotEquals(null, project.Overall_Progress__c, 'Project progress should be calculated');
    }
}
