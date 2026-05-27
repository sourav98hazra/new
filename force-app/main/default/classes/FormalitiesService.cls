/**
 * @description Service class for managing bi-directional sync between
 * User Story formality checkboxes and Salesforce Activity Tasks.
 *
 * DESIGN:
 * - When story moves to "Dev Completed" -> auto-create Activity Tasks for incomplete formalities
 * - When story moves to "Dev In Progress" -> auto-create Activity Task for Unit Testing
 * - When Activity Task is closed -> tick corresponding checkbox on Story
 * - When checkbox is ticked -> close corresponding Activity Task
 * - When all formalities complete -> auto-move story to "Completed - SIT Ready"
 * - When some (not all) formalities complete -> auto-move story to "Formalities InProgress"
 */
// without sharing is required because:
// 1. ActivityTaskTrigger fires when ANY user completes a task (may not own the User Story)
// 2. Developers can complete Activity Tasks they don't own (assigned to them, owned by lead)
// 3. The checkbox and status updates must propagate regardless of record ownership
public without sharing class FormalitiesService {

    // Maps each formality subject prefix to the checkbox field API name
    public static final Map<String, String> FORMALITY_SUBJECT_TO_FIELD = new Map<String, String>{
        'Unit Test Sheet'           => 'Unit_Test_Sheet_Complete__c',
        'Manual Deployment Steps'   => 'Manual_Deployment_Steps_Complete__c',
        'Business Dependency'       => 'Business_Dependency_Complete__c',
        'AC Update'                 => 'AC_Update_Complete__c',
        'Peer Review'               => 'Peer_Review_Complete__c'
    };

    // Maps each checkbox field to a human-readable activity subject
    public static final Map<String, String> FIELD_TO_FORMALITY_SUBJECT = new Map<String, String>{
        'Unit_Test_Sheet_Complete__c'           => 'Unit Test Sheet',
        'Manual_Deployment_Steps_Complete__c'   => 'Manual Deployment Steps',
        'Business_Dependency_Complete__c'       => 'Business Dependency',
        'AC_Update_Complete__c'                 => 'AC Update',
        'Peer_Review_Complete__c'               => 'Peer Review'
    };

    public static final String UNIT_TESTING_SUBJECT = 'Unit Testing';
    public static final String ACTIVITY_TYPE = 'ADM_Formality';



    /**
     * @description Called when story status changes to "Dev In Progress"
     * Creates Activity Task for Unit Testing if not already complete
     */
    public static void createUnitTestingActivityIfNeeded(List<User_Story__c> stories) {
        List<Task> tasksToCreate = new List<Task>();

        for (User_Story__c story : stories) {
            if (story.Unit_Testing_Complete__c == true) continue;

            // Check if activity already exists
            Integer existing = [
                SELECT COUNT() FROM Task
                WHERE WhatId = :story.Id
                AND Subject LIKE :('%' + UNIT_TESTING_SUBJECT + '%')
                AND Status != 'Completed'
            ];
            if (existing > 0) continue;

            tasksToCreate.add(new Task(
                Subject      = UNIT_TESTING_SUBJECT + ' - ' + story.Story_Title__c,
                WhatId       = story.Id,
                OwnerId      = story.Assigned_To__c != null ? story.Assigned_To__c : UserInfo.getUserId(),
                Status       = 'In Progress',
                Priority     = 'High',
                ActivityDate = Date.today().addDays(2),
                Description  = 'Complete unit testing for story: ' + story.Story_Title__c +
                               '. Once done, close this task or tick "Unit Testing Complete" on the story.'
            ));
        }

        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
    }



    /**
     * @description Called when story moves to "Dev Completed"
     * Creates Activity Tasks for each incomplete formality checkbox
     */
    public static void createFormalityActivitiesIfNeeded(List<User_Story__c> stories) {
        List<Task> tasksToCreate = new List<Task>();

        for (User_Story__c story : stories) {
            // Get existing open formality tasks for this story
            Set<String> existingSubjects = new Set<String>();
            for (Task t : [
                SELECT Subject FROM Task
                WHERE WhatId = :story.Id
                AND Status != 'Completed'
            ]) {
                existingSubjects.add(t.Subject);
            }

            // Create task for each incomplete formality
            for (String fieldName : FIELD_TO_FORMALITY_SUBJECT.keySet()) {
                Boolean isComplete = (Boolean) story.get(fieldName);
                if (isComplete == true) continue;

                String subject = FIELD_TO_FORMALITY_SUBJECT.get(fieldName) + ' - ' + story.Story_Title__c;
                if (existingSubjects.contains(subject)) continue;

                tasksToCreate.add(new Task(
                    Subject      = subject,
                    WhatId       = story.Id,
                    OwnerId      = story.Assigned_To__c != null ? story.Assigned_To__c : UserInfo.getUserId(),
                    Status       = 'Not Started',
                    Priority     = 'Normal',
                    ActivityDate = Date.today().addDays(3),
                    Description  = 'Complete formality "' + FIELD_TO_FORMALITY_SUBJECT.get(fieldName) +
                                   '" for story: ' + story.Story_Title__c +
                                   '. Close this task once done or tick the checkbox on the story.'
                ));
            }
        }

        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
    }



    /**
     * @description Called when a Salesforce Activity Task is completed
     * Ticks the corresponding formality checkbox on the parent User Story
     */
    public static void syncTaskCompletionToStory(List<Task> completedTasks) {
        Set<Id> storyIds = new Set<Id>();
        Map<Id, Map<String, Boolean>> storyFieldUpdates = new Map<Id, Map<String, Boolean>>();

        // Get all User Story IDs from WhatId - use ID prefix check (User_Story__c starts with 'a0' or varies)
        // Safer: query to confirm WhatId is User_Story__c since getSObjectType on polymorphic can fail
        Set<Id> whatIds = new Set<Id>();
        for (Task t : completedTasks) {
            if (t.WhatId != null) whatIds.add(t.WhatId);
        }

        // Find which WhatIds are actually User Story records
        Set<Id> userStoryWhatIds = new Set<Id>();
        for (User_Story__c us : [SELECT Id FROM User_Story__c WHERE Id IN :whatIds]) {
            userStoryWhatIds.add(us.Id);
        }

        for (Task t : completedTasks) {
            if (t.WhatId == null) continue;
            if (!userStoryWhatIds.contains(t.WhatId)) continue;

            // Match subject to formality field
            for (String subjectPrefix : FORMALITY_SUBJECT_TO_FIELD.keySet()) {
                if (t.Subject != null && t.Subject.startsWith(subjectPrefix)) {
                    storyIds.add(t.WhatId);
                    if (!storyFieldUpdates.containsKey(t.WhatId)) {
                        storyFieldUpdates.put(t.WhatId, new Map<String, Boolean>());
                    }
                    storyFieldUpdates.get(t.WhatId).put(
                        FORMALITY_SUBJECT_TO_FIELD.get(subjectPrefix), true
                    );
                    break;
                }
            }

            // Match Unit Testing subject
            if (t.Subject != null && t.Subject.startsWith(UNIT_TESTING_SUBJECT)) {
                storyIds.add(t.WhatId);
                if (!storyFieldUpdates.containsKey(t.WhatId)) {
                    storyFieldUpdates.put(t.WhatId, new Map<String, Boolean>());
                }
                storyFieldUpdates.get(t.WhatId).put('Unit_Testing_Complete__c', true);
            }
        }

        if (storyIds.isEmpty()) return;

        List<User_Story__c> storiesToUpdate = [
            SELECT Id, Status__c,
                Unit_Testing_Complete__c,
                Unit_Test_Sheet_Complete__c,
                Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c,
                AC_Update_Complete__c,
                Peer_Review_Complete__c,
                All_Formalities_Complete__c
            FROM User_Story__c
            WHERE Id IN :storyIds
        ];

        List<User_Story__c> finalUpdates = new List<User_Story__c>();

        for (User_Story__c story : storiesToUpdate) {
            Boolean changed = false;

            if (storyFieldUpdates.containsKey(story.Id)) {
                for (String fieldName : storyFieldUpdates.get(story.Id).keySet()) {
                    if ((Boolean) story.get(fieldName) != true) {
                        story.put(fieldName, true);
                        changed = true;
                    }
                }
            }

            if (changed) {
                // Recalculate status based on new checkbox values
                story = recalculateFormalitiesStatus(story);
                finalUpdates.add(story);
            }
        }

        if (!finalUpdates.isEmpty()) update finalUpdates;
    }



    /**
     * @description Called when a formality checkbox is ticked on the story
     * Closes the corresponding Activity Task
     */
    public static void syncCheckboxToActivityTask(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        Set<Id> storyIds = new Set<Id>();
        Map<Id, Set<String>> storyChangedFields = new Map<Id, Set<String>>();

        for (User_Story__c story : stories) {
            User_Story__c oldStory = oldMap.get(story.Id);
            Set<String> changedFields = new Set<String>();

            // Check Unit Testing
            if (story.Unit_Testing_Complete__c == true && oldStory.Unit_Testing_Complete__c == false) {
                changedFields.add(UNIT_TESTING_SUBJECT);
            }

            // Check each formality
            for (String fieldName : FIELD_TO_FORMALITY_SUBJECT.keySet()) {
                Boolean newVal = (Boolean) story.get(fieldName);
                Boolean oldVal = (Boolean) oldStory.get(fieldName);
                if (newVal == true && oldVal == false) {
                    changedFields.add(FIELD_TO_FORMALITY_SUBJECT.get(fieldName));
                }
            }

            if (!changedFields.isEmpty()) {
                storyIds.add(story.Id);
                storyChangedFields.put(story.Id, changedFields);
            }
        }

        if (storyIds.isEmpty()) return;

        // Find open Activity Tasks matching the changed fields
        List<Task> tasksToClose = new List<Task>();
        for (Task t : [
            SELECT Id, Subject, WhatId, Status
            FROM Task
            WHERE WhatId IN :storyIds
            AND Status != 'Completed'
        ]) {
            Set<String> changedFields = storyChangedFields.get(t.WhatId);
            if (changedFields == null) continue;

            for (String subjectPrefix : changedFields) {
                if (t.Subject != null && t.Subject.startsWith(subjectPrefix)) {
                    t.Status = 'Completed';
                    tasksToClose.add(t);
                    break;
                }
            }
        }

        if (!tasksToClose.isEmpty()) update tasksToClose;

        // Recalculate story status based on checkbox values
        updateStoryStatusFromFormalities(stories, oldMap);
    }



    /**
     * @description Auto-updates story status based on formality completion:
     * - Some done, some pending -> "Formalities InProgress"
     * - All 5 done -> "Completed - SIT Ready"
     */
    public static void updateStoryStatusFromFormalities(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        List<User_Story__c> storiesToUpdate = new List<User_Story__c>();

        for (User_Story__c story : stories) {
            User_Story__c oldStory = oldMap.get(story.Id);

            // Only process stories that are in formality-related statuses
            Boolean inFormalitiesPhase = (
                story.Status__c == 'Dev Completed' ||
                story.Status__c == 'Formalities InProgress' ||
                story.Status__c == 'Completed - SIT Ready'
            );
            if (!inFormalitiesPhase) continue;

            // Check if any formality checkbox changed
            Boolean anyChanged = (
                story.Unit_Test_Sheet_Complete__c != oldStory.Unit_Test_Sheet_Complete__c ||
                story.Manual_Deployment_Steps_Complete__c != oldStory.Manual_Deployment_Steps_Complete__c ||
                story.Business_Dependency_Complete__c != oldStory.Business_Dependency_Complete__c ||
                story.AC_Update_Complete__c != oldStory.AC_Update_Complete__c ||
                story.Peer_Review_Complete__c != oldStory.Peer_Review_Complete__c
            );
            if (!anyChanged) continue;

            story = recalculateFormalitiesStatus(story);
            storiesToUpdate.add(story);
        }

        if (!storiesToUpdate.isEmpty()) update storiesToUpdate;
    }

    /**
     * @description Calculates what the story status should be based on formality checkboxes
     * Does NOT perform DML - just sets the Status__c field on the passed record
     */
    private static User_Story__c recalculateFormalitiesStatus(User_Story__c story) {
        Integer completedCount = 0;
        if (story.Unit_Test_Sheet_Complete__c == true)           completedCount++;
        if (story.Manual_Deployment_Steps_Complete__c == true)   completedCount++;
        if (story.Business_Dependency_Complete__c == true)       completedCount++;
        if (story.AC_Update_Complete__c == true)                 completedCount++;
        if (story.Peer_Review_Complete__c == true)               completedCount++;

        String currentStatus = story.Status__c;

        if (completedCount == 5) {
            // All done - move to SIT Ready
            if (currentStatus != 'Completed - SIT Ready' &&
                currentStatus != 'PR InProgress' &&
                currentStatus != 'Sent to SIT' &&
                currentStatus != 'Sent to QA' &&
                currentStatus != 'Sent to UAT' &&
                currentStatus != 'Done') {
                story.Status__c = 'Completed - SIT Ready';
            }
        } else if (completedCount > 0) {
            // Some done - move to Formalities InProgress
            if (currentStatus == 'Dev Completed') {
                story.Status__c = 'Formalities InProgress';
            }
        }

        return story;
    }
}
