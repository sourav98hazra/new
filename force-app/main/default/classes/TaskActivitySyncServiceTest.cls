/**
 * @description Tests for TaskActivitySyncService — Task__c ↔ Activity Task bi-directional sync.
 * Also covers SITDeploymentEmailQueueable execution path.
 */
@isTest
private class TaskActivitySyncServiceTest {

    @TestSetup
    static void makeData() {
        Project__c proj = new Project__c(
            Name = 'Sync Test Project', Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(60)
        );
        insert proj;

        Sprint__c sprint = new Sprint__c(
            Name = 'Sync Sprint', Project__c = proj.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(14)
        );
        insert sprint;

        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Sync Story', Sprint__c = sprint.Id,
            Status__c = 'New', Story_Info_Verified__c = true
        );
        insert story;
    }

    private static User_Story__c getStory() {
        return [SELECT Id, Story_Title__c, Status__c, Assigned_To__c FROM User_Story__c LIMIT 1];
    }

    // ─── Task__c INSERT → mirrored Activity Task created ──────────────────

    @isTest
    static void testTaskInsert_CreatesMirroredActivityTask() {
        User_Story__c story = getStory();

        Test.startTest();
        Task__c task = new Task__c(
            Task_Title__c  = 'Implement Feature X',
            User_Story__c  = story.Id,
            Status__c      = 'New',
            Estimated_Hours__c = 8,
            Task_Type__c   = 'Development'
        );
        insert task;
        Test.stopTest();

        List<Task> mirrored = [
            SELECT Subject, Status, WhatId FROM Task
            WHERE WhatId = :story.Id AND Subject = :('Implement Feature X' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX)
        ];
        System.assertEquals(1, mirrored.size(), 'Mirrored Activity Task should be created on Task__c insert');
        System.assertEquals('Not Started', mirrored[0].Status, 'Activity Task status should be Not Started');
        System.assertEquals(story.Id, mirrored[0].WhatId, 'Activity Task should be linked to the User Story');
    }

    // ─── Task__c status update → Activity Task status syncs ───────────────

    @isTest
    static void testTaskStatusUpdate_SyncsToActivityTask() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Test Task', User_Story__c = story.Id,
            Status__c = 'New', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Test.startTest();
        task.Status__c = 'In Progress';
        update task;
        Test.stopTest();

        Task mirrored = [SELECT Status FROM Task WHERE Subject = :('Test Task' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) AND WhatId = :story.Id LIMIT 1];
        System.assertEquals('In Progress', mirrored.Status, 'Activity Task should sync to In Progress');
    }

    @isTest
    static void testTaskStatusBlocked_SyncsToWaitingOnSomeoneElse() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Blocked Task', User_Story__c = story.Id,
            Status__c = 'New', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Test.startTest();
        task.Status__c = 'Blocked';
        task.Blocked_Reason__c = 'Waiting for API credentials';
        update task;
        Test.stopTest();

        Task mirrored = [SELECT Status FROM Task WHERE Subject = :('Blocked Task' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) LIMIT 1];
        System.assertEquals('Waiting on someone else', mirrored.Status, 'Blocked task should map to Waiting on someone else');
    }

    // ─── Activity Task status update → Task__c status syncs ───────────────

    @isTest
    static void testActivityTaskCompleted_SyncsToTaskCustom() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Sync Back Task', User_Story__c = story.Id,
            Status__c = 'In Progress', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Task mirrored = [SELECT Id FROM Task WHERE Subject = :('Sync Back Task' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) LIMIT 1];

        Test.startTest();
        mirrored.Status = 'Completed';
        update mirrored;
        Test.stopTest();

        Task__c updatedTask = [SELECT Status__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals('Completed', updatedTask.Status__c, 'Task__c should sync to Completed when Activity Task completed');
    }

    @isTest
    static void testActivityTaskWaiting_SyncsToPending() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Pending Sync Task', User_Story__c = story.Id,
            Status__c = 'In Progress', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Task mirrored = [SELECT Id FROM Task WHERE Subject = :('Pending Sync Task' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) LIMIT 1];

        Test.startTest();
        mirrored.Status = 'Waiting on someone else';
        update mirrored;
        Test.stopTest();

        Task__c updatedTask = [SELECT Status__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals('Pending', updatedTask.Status__c, 'Task__c should sync to Pending when Activity Task is Waiting on someone else');
    }

    @isTest
    static void testActivityTaskNotStarted_SyncsToNew() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Reset Task', User_Story__c = story.Id,
            Status__c = 'In Progress', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Task mirrored = [SELECT Id FROM Task WHERE Subject = :('Reset Task' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) AND Status = 'In Progress' LIMIT 1];

        Test.startTest();
        mirrored.Status = 'Not Started';
        update mirrored;
        Test.stopTest();

        Task__c updatedTask = [SELECT Status__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals('New', updatedTask.Status__c, 'Task__c should sync to New when Activity Task reset to Not Started (BUG14 fix)');
    }

    // ─── Task__c DELETE → mirrored Activity Task closed ───────────────────

    @isTest
    static void testTaskDelete_ClosesMirroredActivityTask() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'To Be Deleted', User_Story__c = story.Id,
            Status__c = 'New', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        // Verify mirror exists
        List<Task> before = [SELECT Id FROM Task WHERE Subject = :('To Be Deleted' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX) AND Status != 'Completed'];
        System.assertEquals(1, before.size(), 'Mirror should exist before delete');

        Test.startTest();
        delete task;
        Test.stopTest();

        List<Task> after = [SELECT Id, Status FROM Task WHERE Subject = :('To Be Deleted' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX)];
        System.assertEquals(1, after.size(), 'Mirror Activity Task should still exist');
        System.assertEquals('Completed', after[0].Status, 'Mirror Activity Task should be closed on Task__c delete (BUG17 fix)');
    }

    // ─── Title rename → Activity Task subject updated ─────────────────────

    @isTest
    static void testTaskTitleRename_UpdatesMirroredSubject() {
        User_Story__c story = getStory();
        Task__c task = new Task__c(
            Task_Title__c = 'Old Title', User_Story__c = story.Id,
            Status__c = 'New', Estimated_Hours__c = 4, Task_Type__c = 'Development'
        );
        insert task;

        Test.startTest();
        task.Task_Title__c = 'New Title';
        update task;
        Test.stopTest();

        List<Task> updated = [SELECT Subject FROM Task WHERE Subject = :('New Title' + TaskActivitySyncService.TASK_SUBJECT_SUFFIX)];
        System.assertEquals(1, updated.size(), 'Mirrored Activity Task subject should be updated on title rename');
    }

    // ─── SITDeploymentEmailQueueable ──────────────────────────────────────

    @isTest
    static void testSITDeploymentEmailQueueable_ExecutesWithoutError() {
        User_Story__c story = getStory();
        story.Status__c = 'Successfully Deployed to SIT';
        update story;

        Set<Id> storyIds = new Set<Id>{ story.Id };

        Test.startTest();
        System.enqueueJob(new SITDeploymentEmailQueueable(storyIds));
        Test.stopTest();

        // No assertion needed beyond "no exception thrown" — email sending is mocked in tests
        System.assert(true, 'SITDeploymentEmailQueueable should execute without errors');
    }

    @isTest
    static void testSITDeploymentEmailQueueable_EmptySet_NoError() {
        Test.startTest();
        System.enqueueJob(new SITDeploymentEmailQueueable(new Set<Id>()));
        Test.stopTest();
        System.assert(true, 'Empty set should not cause errors');
    }
}
