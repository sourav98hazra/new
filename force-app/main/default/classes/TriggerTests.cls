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

        Task__c updatedTask = [SELECT Task_Progress__c, Actual_Hours__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(4, updatedTask.Actual_Hours__c, 'Actual hours should be updated');

        User_Story__c updatedStory = [SELECT Story_Progress__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertNotEquals(null, updatedStory.Story_Progress__c, 'Story progress should be calculated');
    }

    @isTest
    static void testTaskTriggerInsert() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);

        Test.startTest();
        Task__c task = TriggerTestHelper.createTask(story.Id);
        Test.stopTest();

        // Task should be created with status New
        Task__c createdTask = [SELECT Status__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals('New', createdTask.Status__c, 'Task should be created with New status');
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

        Project__c updatedProject = [SELECT Overall_Progress__c FROM Project__c WHERE Id = :project.Id];
        System.assertNotEquals(null, updatedProject.Overall_Progress__c, 'Project progress should be calculated');
    }

    @isTest
    static void testFormalitiesActivityTaskCreation() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, null);

        Test.startTest();
        // Move story to Dev In Progress - should auto-create Unit Testing activity
        story.Status__c = 'Dev In Progress';
        update story;
        Test.stopTest();

        // Verify Unit Testing activity was created
        List<Task> activities = [
            SELECT Id, Subject FROM Task
            WHERE WhatId = :story.Id
            AND Status != 'Completed'
        ];
        System.assert(activities.size() > 0, 'Unit Testing activity should be auto-created');
        System.assert(activities[0].Subject.contains('Unit Testing'), 'Activity should be for Unit Testing');
    }

    @isTest
    static void testProgressCascade() {
        Project__c project = TriggerTestHelper.createProject();
        Sprint__c sprint = TriggerTestHelper.createSprint(project.Id);
        Feature__c feature = TriggerTestHelper.createFeature(sprint.Id);
        User_Story__c story = TriggerTestHelper.createUserStory(sprint.Id, feature.Id);
        Task__c task = TriggerTestHelper.createTask(story.Id);

        Test.startTest();
        Daily_Progress__c progress = new Daily_Progress__c(
            Task__c = task.Id,
            Hours_Worked__c = 8,
            Progress_Percentage__c = 100,
            Progress_Date__c = Date.today(),
            Developer__c = UserInfo.getUserId()
        );
        insert progress;
        Test.stopTest();

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
