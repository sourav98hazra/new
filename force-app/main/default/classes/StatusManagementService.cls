/**
 * @description Service class for managing status transitions and automation
 * Handles auto-status updates based on progress and business rules
 */
public without sharing class StatusManagementService {
    
    /**
     * @description Auto-update task status based on progress
     */
    public static void updateTaskStatus(List<Task__c> tasks) {
        List<Task__c> tasksToUpdate = new List<Task__c>();
        
        for (Task__c task : tasks) {
            String newStatus = null;
            
            // Auto-transition logic
            if (task.Task_Progress__c == 100 && task.Status__c != 'Completed') {
                newStatus = 'Completed';
            } else if (task.Task_Progress__c > 0 && task.Task_Progress__c < 100 && task.Status__c == 'New') {
                newStatus = 'In Progress';
            }
            
            if (newStatus != null && newStatus != task.Status__c) {
                Task__c taskToUpdate = new Task__c(
                    Id = task.Id,
                    Status__c = newStatus
                );
                tasksToUpdate.add(taskToUpdate);
            }
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
    
    /**
     * @description Auto-update story status based on task completion.
     * Key automation:
     * - All tasks Completed AND Unit Testing Complete → auto "Dev Completed"
     * - Story in Dev In Progress with progress > 0 → stays in Dev In Progress
     */
    public static void updateStoryStatus(Set<Id> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) return;

        List<User_Story__c> storiesToUpdate = new List<User_Story__c>();

        Map<Id, Integer> totalTasksByStory     = new Map<Id, Integer>();
        Map<Id, Integer> completedTasksByStory = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT User_Story__c, COUNT(Id) taskCount
            FROM Task__c
            WHERE User_Story__c IN :storyIds
            GROUP BY User_Story__c
        ]) {
            totalTasksByStory.put((Id)ar.get('User_Story__c'), (Integer)ar.get('taskCount'));
        }

        for (AggregateResult ar : [
            SELECT User_Story__c, COUNT(Id) completedCount
            FROM Task__c
            WHERE User_Story__c IN :storyIds AND Status__c = 'Completed'
            GROUP BY User_Story__c
        ]) {
            completedTasksByStory.put((Id)ar.get('User_Story__c'), (Integer)ar.get('completedCount'));
        }

        for (User_Story__c story : [
            SELECT Id, Status__c, Story_Progress__c, Unit_Testing_Complete__c
            FROM User_Story__c
            WHERE Id IN :storyIds
        ]) {
            String newStatus = null;
            Integer totalTasks     = totalTasksByStory.get(story.Id);
            Integer completedTasks = completedTasksByStory.get(story.Id);

            if (totalTasks     == null) totalTasks     = 0;
            if (completedTasks == null) completedTasks = 0;

            Boolean allTasksDone = (totalTasks > 0 && completedTasks == totalTasks);

            // AUTO-ADVANCE: all tasks done + unit testing complete = Dev Completed
            if (allTasksDone
                && story.Unit_Testing_Complete__c == true
                && (story.Status__c == 'Dev In Progress' || story.Status__c == 'Pending')) {
                newStatus = 'Dev Completed';
            }
            // Still in progress
            else if (story.Story_Progress__c > 0 && story.Status__c == 'New') {
                newStatus = 'Dev In Progress';
            }

            if (newStatus != null && newStatus != story.Status__c) {
                storiesToUpdate.add(new User_Story__c(Id = story.Id, Status__c = newStatus));
            }
        }

        if (!storiesToUpdate.isEmpty()) {
            update storiesToUpdate;
        }
    }
    
    /**
     * @description Auto-update feature status based on story completion
     */
    public static void updateFeatureStatus(Set<Id> featureIds) {
        if (featureIds == null || featureIds.isEmpty()) return;
        
        List<Feature__c> featuresToUpdate = new List<Feature__c>();
        
        for (Feature__c feature : [
            SELECT Id, Status__c, Feature_Progress__c,
                   (SELECT Id, Status__c FROM User_Stories__r)
            FROM Feature__c
            WHERE Id IN :featureIds
        ]) {
            String newStatus = null;
            
            if (feature.User_Stories__r.isEmpty()) {
                continue;
            }
            
            Boolean allCompleted = true;
            Boolean anyInProgress = false;
            
            for (User_Story__c story : feature.User_Stories__r) {
                if (story.Status__c != 'Done') {
                    allCompleted = false;
                }
                if (story.Status__c == 'In Progress' || story.Status__c == 'In QA') {
                    anyInProgress = true;
                }
            }
            
            // Auto-transition logic
            if (allCompleted && feature.Status__c != 'Completed') {
                newStatus = 'Completed';
            } else if (anyInProgress && feature.Status__c == 'Not Started') {
                newStatus = 'In Progress';
            }
            
            if (newStatus != null && newStatus != feature.Status__c) {
                Feature__c featureToUpdate = new Feature__c(
                    Id = feature.Id,
                    Status__c = newStatus
                );
                featuresToUpdate.add(featureToUpdate);
            }
        }
        
        if (!featuresToUpdate.isEmpty()) {
            update featuresToUpdate;
        }
    }
    
    /**
     * @description Handle QA approval process
     */
    public static void handleQAApproval(Id storyId, Boolean approved, String notes) {
        User_Story__c story = [
            SELECT Id, Status__c, QA_Notes__c
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        if (approved) {
            story.Status__c = 'QA Approved';
            story.QA_Notes__c = notes;
        } else {
            story.Status__c = 'Rejected';
            story.Rejection_Reason__c = notes;
        }
        
        update story;
    }
    
    /**
     * @description Handle SIT approval process
     */
    public static void handleSITApproval(Id storyId, Boolean approved, String notes) {
        User_Story__c story = [
            SELECT Id, Status__c
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        if (approved) {
            story.Status__c = 'SIT Approved';
        } else {
            story.Status__c = 'Rejected';
            story.Rejection_Reason__c = notes;
        }
        
        update story;
    }
    
    /**
     * @description Reopen story (QA rejection)
     */
    public static void reopenStory(Id storyId, String rejectionReason) {
        User_Story__c story = [
            SELECT Id, Status__c
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        story.Status__c = 'In Progress';
        story.Rejection_Reason__c = rejectionReason;
        
        update story;
    }
    
    /**
     * @description Mark story as Done
     */
    public static void markStoryAsDone(Id storyId) {
        User_Story__c story = [
            SELECT Id, Status__c
            FROM User_Story__c
            WHERE Id = :storyId
            LIMIT 1
        ];
        
        story.Status__c = 'Done';
        update story;
    }
}
