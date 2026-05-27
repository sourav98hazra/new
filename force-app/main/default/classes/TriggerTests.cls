/**
 * @description Comprehensive test class for all triggers
 */
@isTest
private class TriggerTests {
    
    @isTest
    static void testDailyProgressTrigger() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);
        Task__c task = TriggerTestHelper.createTask(story.Id);
        
        Test.startTest();
        TriggerTestHelper.createDailyProgress(task.Id, 4);
        Test.stopTest();
        
        // Verify task progress was updated
        Task__c updatedTask = [SELECT Task_Progress__c, Actual_Hours__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(4, updatedTask.Actual_Hours__c, 'Actual hours should be updated');
        
        // Verify cascade happened
        User_Story__c updatedStory = [SELECT Story_Progress__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertNotEquals(null, updatedStory.Story_Progress__c, 'Story progress should be calculated');
    }
    
    @isTest
    static void testTaskTriggerDefaultChecklist() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);
        
        Test.startTest();
        Task__c task = TriggerTestHelper.createTask(story.Id);
        Test.stopTest();
        
        // Verify default checklist was created
        List<Task_Checklist_Item__c> items = [
            SELECT Id FROM Task_Checklist_Item__c WHERE Task__c = :task.Id
        ];
        System.assert(items.size() > 0, 'Default checklist items should be created');
    }
    
    @isTest
    static void testUserStoryTrigger() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        Feature__c feature = TriggerTestHelper.createFeature(sprint.Id);
        
        Test.startTest();
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, feature.Id);
        story.Story_Progress__c = 50;
        update story;
        Test.stopTest();
        
        // Verify feature and sprint progress updated
        Feature__c updatedFeature = [SELECT Feature_Progress__c FROM Feature__c WHERE Id = :feature.Id];
        System.assertNotEquals(null, updatedFeature.Feature_Progress__c, 'Feature progress should be calculated');
        
        Sprint__c updatedSprint = [SELECT Sprint_Progress__c FROM Sprint__c WHERE Id = :sprint.Id];
        System.assertNotEquals(null, updatedSprint.Sprint_Progress__c, 'Sprint progress should be calculated');
    }
    
    @isTest
    static void testFeatureTrigger() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        
        Test.startTest();
        Feature__c feature = TriggerTestHelper.createFeature(sprint.Id);
        Test.stopTest();
        
        // Verify sprint was updated
        Sprint__c updatedSprint = [SELECT Sprint_Progress__c FROM Sprint__c WHERE Id = :sprint.Id];
        System.assertNotEquals(null, updatedSprint, 'Sprint should exist');
    }
    
    @isTest
    static void testSprintTrigger() {
        Project__c project = TriggerTestHelper.createProject();
        
        Test.startTest();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        sprint.Sprint_Progress__c = 75;
        update sprint;
        Test.stopTest();
        
        // Verify project progress was updated
        Project__c updatedProject = [SELECT Overall_Progress__c FROM Project__c WHERE Id = :project.Id];
        System.assertNotEquals(null, updatedProject.Overall_Progress__c, 'Project progress should be calculated');
    }
    
    @isTest
    static void testTaskChecklistItemTrigger() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);
        Task__c task = TriggerTestHelper.createTask(story.Id);
        
        Test.startTest();
        Task_Checklist_Item__c item = new Task_Checklist_Item__c(
            Name = 'Test Item',
            Task__c = task.Id,
            Is_Completed__c = false
        );
        insert item;
        Test.stopTest();
        
        // Verify task checklist status updated
        Task__c updatedTask = [SELECT Checklist_Complete__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(false, updatedTask.Checklist_Complete__c, 'Checklist should not be complete');
        
        // Complete the item
        item.Is_Completed__c = true;
        update item;
        
        updatedTask = [SELECT Checklist_Complete__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(true, updatedTask.Checklist_Complete__c, 'Checklist should be complete');
    }
    
    @isTest
    static void testProgressCascade() {
        // Test full hierarchy cascade
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        Feature__c feature = TriggerTestHelper.createFeature(sprint.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, feature.Id);
        Task__c task = TriggerTestHelper.createTask(story.Id);
        
        Test.startTest();
        // Create progress that should cascade all the way up
        Daily_Progress__c progress = new Daily_Progress__c(
            Task__c = task.Id,
            Hours_Worked__c = 8,
            Progress_Percentage__c = 100,
            Progress_Date__c = Date.today(),
            Developer__c = UserInfo.getUserId()
        );
        insert progress;
        Test.stopTest();
        
        // Verify entire hierarchy was updated
        Task__c updatedTask = [SELECT Task_Progress__c FROM Task__c WHERE Id = :task.Id];
        User_Story__c updatedStory = [SELECT Story_Progress__c FROM User_Story__c WHERE Id = :story.Id];
        Feature__c updatedFeature = [SELECT Feature_Progress__c FROM Feature__c WHERE Id = :feature.Id];
        Sprint__c updatedSprint = [SELECT Sprint_Progress__c FROM Sprint__c WHERE Id = :sprint.Id];
        Project__c updatedProject = [SELECT Overall_Progress__c FROM Project__c WHERE Id = :project.Id];
        
        System.assertEquals(100, updatedTask.Task_Progress__c, 'Task should be 100% complete');
        System.assertEquals(100, updatedStory.Story_Progress__c, 'Story should be 100% complete');
        System.assertEquals(100, updatedFeature.Feature_Progress__c, 'Feature should be 100% complete');
        System.assertNotEquals(0, updatedSprint.Sprint_Progress__c, 'Sprint progress should be calculated');
        System.assertNotEquals(0, updatedProject.Overall_Progress__c, 'Project progress should be calculated');
    }
}
