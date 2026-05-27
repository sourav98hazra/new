/**
 * @description Service class for calculating progress across all hierarchy levels
 * Implements weighted average calculations for Task, Story, Feature, Sprint, and Project
 */
public with sharing class ProgressCalculationService {
    
    /**
     * @description Calculate task progress from daily progress entries
     * Task Progress = Sum of all daily progress percentages
     */
    public static void calculateTaskProgress(Set<Id> taskIds) {
        if (taskIds == null || taskIds.isEmpty()) return;
        
        List<Task__c> tasksToUpdate = new List<Task__c>();
        
        // Aggregate daily progress by task
        Map<Id, AggregateResult> progressByTask = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Task__c, 
                   SUM(Hours_Worked__c) totalHours,
                   SUM(Progress_Percentage__c) totalProgress
            FROM Daily_Progress__c
            WHERE Task__c IN :taskIds
            GROUP BY Task__c
        ]) {
            progressByTask.put((Id)ar.get('Task__c'), ar);
        }
        
        // Query tasks with their estimated hours
        for (Task__c task : [
            SELECT Id, Task_Progress__c, Actual_Hours__c, Estimated_Hours__c
            FROM Task__c
            WHERE Id IN :taskIds
        ]) {
            Decimal newProgress = 0;
            Decimal newActualHours = 0;
            
            if (progressByTask.containsKey(task.Id)) {
                AggregateResult ar = progressByTask.get(task.Id);
                newActualHours = (Decimal)ar.get('totalHours');
                
                // Calculate progress based on actual vs estimated hours
                if (task.Estimated_Hours__c != null && task.Estimated_Hours__c > 0) {
                    newProgress = (newActualHours / task.Estimated_Hours__c) * 100;
                    // Cap at 100%
                    newProgress = Math.min(newProgress, 100);
                } else {
                    // If no estimate, use sum of progress percentages (legacy method)
                    newProgress = (Decimal)ar.get('totalProgress');
                    newProgress = Math.min(newProgress, 100);
                }
            }
            
            if (task.Task_Progress__c != newProgress || task.Actual_Hours__c != newActualHours) {
                task.Task_Progress__c = newProgress.setScale(2);
                task.Actual_Hours__c = newActualHours.setScale(2);
                tasksToUpdate.add(task);
            }
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
    
    /**
     * @description Calculate story progress as weighted average of tasks using Estimated Hours
     * Story Progress = Weighted average using Estimated Hours
     */
    public static void calculateStoryProgress(Set<Id> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) return;
        
        List<User_Story__c> storiesToUpdate = new List<User_Story__c>();
        
        // Get all stories with their tasks
        Map<Id, List<Task__c>> tasksByStory = new Map<Id, List<Task__c>>();
        for (Task__c task : [
            SELECT Id, Task_Progress__c, Estimated_Hours__c, User_Story__c
            FROM Task__c
            WHERE User_Story__c IN :storyIds
        ]) {
            if (!tasksByStory.containsKey(task.User_Story__c)) {
                tasksByStory.put(task.User_Story__c, new List<Task__c>());
            }
            tasksByStory.get(task.User_Story__c).add(task);
        }
        
        for (User_Story__c story : [
            SELECT Id, Story_Progress__c, Estimated_Hours__c
            FROM User_Story__c
            WHERE Id IN :storyIds
        ]) {
            Decimal newProgress = 0;
            
            if (tasksByStory.containsKey(story.Id)) {
                List<Task__c> tasks = tasksByStory.get(story.Id);
                Decimal totalWeightedProgress = 0;
                Decimal totalEstimatedHours = 0;
                
                for (Task__c task : tasks) {
                    Decimal taskProgress = task.Task_Progress__c != null ? task.Task_Progress__c : 0;
                    Decimal estimatedHours = task.Estimated_Hours__c != null ? task.Estimated_Hours__c : 0;
                    
                    if (estimatedHours > 0) {
                        totalWeightedProgress += (taskProgress * estimatedHours);
                        totalEstimatedHours += estimatedHours;
                    }
                }
                
                if (totalEstimatedHours > 0) {
                    newProgress = totalWeightedProgress / totalEstimatedHours;
                } else {
                    // If no estimates, use simple average
                    if (!tasks.isEmpty()) {
                        Decimal sumProgress = 0;
                        for (Task__c task : tasks) {
                            sumProgress += (task.Task_Progress__c != null ? task.Task_Progress__c : 0);
                        }
                        newProgress = sumProgress / tasks.size();
                    }
                }
            }
            
            if (story.Story_Progress__c != newProgress) {
                story.Story_Progress__c = newProgress.setScale(2);
                storiesToUpdate.add(story);
            }
        }
        
        if (!storiesToUpdate.isEmpty()) {
            update storiesToUpdate;
        }
    }
    
    /**
     * @description Calculate feature progress as average of story progress
     * Feature Progress = Average of story progress
     */
    public static void calculateFeatureProgress(Set<Id> featureIds) {
        if (featureIds == null || featureIds.isEmpty()) return;
        
        List<Feature__c> featuresToUpdate = new List<Feature__c>();
        
        // Get all features with their stories
        Map<Id, List<User_Story__c>> storiesByFeature = new Map<Id, List<User_Story__c>>();
        for (User_Story__c story : [
            SELECT Id, Story_Progress__c, Feature__c
            FROM User_Story__c
            WHERE Feature__c IN :featureIds
        ]) {
            if (!storiesByFeature.containsKey(story.Feature__c)) {
                storiesByFeature.put(story.Feature__c, new List<User_Story__c>());
            }
            storiesByFeature.get(story.Feature__c).add(story);
        }
        
        for (Feature__c feature : [
            SELECT Id, Feature_Progress__c
            FROM Feature__c
            WHERE Id IN :featureIds
        ]) {
            Decimal newProgress = 0;
            
            if (storiesByFeature.containsKey(feature.Id)) {
                List<User_Story__c> stories = storiesByFeature.get(feature.Id);
                Decimal sumProgress = 0;
                
                for (User_Story__c story : stories) {
                    sumProgress += (story.Story_Progress__c != null ? story.Story_Progress__c : 0);
                }
                
                if (!stories.isEmpty()) {
                    newProgress = sumProgress / stories.size();
                }
            }
            
            if (feature.Feature_Progress__c != newProgress) {
                feature.Feature_Progress__c = newProgress.setScale(2);
                featuresToUpdate.add(feature);
            }
        }
        
        if (!featuresToUpdate.isEmpty()) {
            update featuresToUpdate;
        }
    }
    
    /**
     * @description Calculate sprint progress as weighted average using Story Points
     * Sprint Progress = Weighted average using Story Points
     */
    public static void calculateSprintProgress(Set<Id> sprintIds) {
        if (sprintIds == null || sprintIds.isEmpty()) return;
        
        List<Sprint__c> sprintsToUpdate = new List<Sprint__c>();
        
        // Get all sprints with their stories
        Map<Id, List<User_Story__c>> storiesBySprint = new Map<Id, List<User_Story__c>>();
        for (User_Story__c story : [
            SELECT Id, Story_Progress__c, Story_Points__c, Sprint__c, Status__c
            FROM User_Story__c
            WHERE Sprint__c IN :sprintIds
        ]) {
            if (!storiesBySprint.containsKey(story.Sprint__c)) {
                storiesBySprint.put(story.Sprint__c, new List<User_Story__c>());
            }
            storiesBySprint.get(story.Sprint__c).add(story);
        }
        
        for (Sprint__c sprint : [
            SELECT Id, Sprint_Progress__c, Total_Story_Points__c, Completed_Story_Points__c, Velocity__c
            FROM Sprint__c
            WHERE Id IN :sprintIds
        ]) {
            Decimal newProgress = 0;
            Decimal totalStoryPoints = 0;
            Decimal completedStoryPoints = 0;
            
            if (storiesBySprint.containsKey(sprint.Id)) {
                List<User_Story__c> stories = storiesBySprint.get(sprint.Id);
                Decimal totalWeightedProgress = 0;
                
                for (User_Story__c story : stories) {
                    Decimal storyProgress = story.Story_Progress__c != null ? story.Story_Progress__c : 0;
                    Decimal storyPoints = story.Story_Points__c != null ? story.Story_Points__c : 0;
                    
                    totalStoryPoints += storyPoints;
                    
                    if (storyPoints > 0) {
                        totalWeightedProgress += (storyProgress * storyPoints);
                    }
                    
                    // Calculate completed story points (stories at 100%)
                    if (storyProgress == 100 || story.Status__c == 'Done') {
                        completedStoryPoints += storyPoints;
                    }
                }
                
                if (totalStoryPoints > 0) {
                    newProgress = totalWeightedProgress / totalStoryPoints;
                } else {
                    // If no story points, use simple average
                    if (!stories.isEmpty()) {
                        Decimal sumProgress = 0;
                        for (User_Story__c story : stories) {
                            sumProgress += (story.Story_Progress__c != null ? story.Story_Progress__c : 0);
                        }
                        newProgress = sumProgress / stories.size();
                    }
                }
            }
            
            Boolean needsUpdate = false;
            if (sprint.Sprint_Progress__c != newProgress) {
                sprint.Sprint_Progress__c = newProgress.setScale(2);
                needsUpdate = true;
            }
            if (sprint.Total_Story_Points__c != totalStoryPoints) {
                sprint.Total_Story_Points__c = totalStoryPoints;
                needsUpdate = true;
            }
            if (sprint.Completed_Story_Points__c != completedStoryPoints) {
                sprint.Completed_Story_Points__c = completedStoryPoints;
                sprint.Velocity__c = completedStoryPoints; // Velocity = completed story points
                needsUpdate = true;
            }
            
            if (needsUpdate) {
                sprintsToUpdate.add(sprint);
            }
        }
        
        if (!sprintsToUpdate.isEmpty()) {
            update sprintsToUpdate;
        }
    }
    
    /**
     * @description Calculate project progress as average of sprint progress
     * Project Progress = Average of sprint progress
     */
    public static void calculateProjectProgress(Set<Id> projectIds) {
        if (projectIds == null || projectIds.isEmpty()) return;
        
        List<Project__c> projectsToUpdate = new List<Project__c>();
        
        // Get all projects with their sprints
        Map<Id, List<Sprint__c>> sprintsByProject = new Map<Id, List<Sprint__c>>();
        for (Sprint__c sprint : [
            SELECT Id, Sprint_Progress__c, Total_Story_Points__c, Status__c, Project__c
            FROM Sprint__c
            WHERE Project__c IN :projectIds
        ]) {
            if (!sprintsByProject.containsKey(sprint.Project__c)) {
                sprintsByProject.put(sprint.Project__c, new List<Sprint__c>());
            }
            sprintsByProject.get(sprint.Project__c).add(sprint);
        }
        
        for (Project__c project : [
            SELECT Id, Overall_Progress__c, Total_Story_Points__c, Active_Sprint_Count__c
            FROM Project__c
            WHERE Id IN :projectIds
        ]) {
            Decimal newProgress = 0;
            Decimal totalStoryPoints = 0;
            Integer activeSprintCount = 0;
            
            if (sprintsByProject.containsKey(project.Id)) {
                List<Sprint__c> sprints = sprintsByProject.get(project.Id);
                Decimal sumProgress = 0;
                
                for (Sprint__c sprint : sprints) {
                    sumProgress += (sprint.Sprint_Progress__c != null ? sprint.Sprint_Progress__c : 0);
                    totalStoryPoints += (sprint.Total_Story_Points__c != null ? sprint.Total_Story_Points__c : 0);
                    
                    if (sprint.Status__c == 'Active') {
                        activeSprintCount++;
                    }
                }
                
                if (!sprints.isEmpty()) {
                    newProgress = sumProgress / sprints.size();
                }
            }
            
            Boolean needsUpdate = false;
            if (project.Overall_Progress__c != newProgress) {
                project.Overall_Progress__c = newProgress.setScale(2);
                needsUpdate = true;
            }
            if (project.Total_Story_Points__c != totalStoryPoints) {
                project.Total_Story_Points__c = totalStoryPoints;
                needsUpdate = true;
            }
            if (project.Active_Sprint_Count__c != activeSprintCount) {
                project.Active_Sprint_Count__c = activeSprintCount;
                needsUpdate = true;
            }
            
            if (needsUpdate) {
                projectsToUpdate.add(project);
            }
        }
        
        if (!projectsToUpdate.isEmpty()) {
            update projectsToUpdate;
        }
    }
    
    /**
     * @description Cascade progress calculation from task level up to project
     * This is the main entry point for full hierarchy recalculation
     */
    public static void cascadeProgressCalculation(Set<Id> taskIds) {
        if (taskIds == null || taskIds.isEmpty()) return;
        
        // Step 1: Calculate task progress
        calculateTaskProgress(taskIds);
        
        // Step 2: Get affected stories and calculate story progress
        Set<Id> storyIds = new Set<Id>();
        for (Task__c task : [SELECT User_Story__c FROM Task__c WHERE Id IN :taskIds]) {
            storyIds.add(task.User_Story__c);
        }
        if (!storyIds.isEmpty()) {
            calculateStoryProgress(storyIds);
        }
        
        // Step 3: Get affected features and calculate feature progress
        Set<Id> featureIds = new Set<Id>();
        for (User_Story__c story : [SELECT Feature__c FROM User_Story__c WHERE Id IN :storyIds AND Feature__c != null]) {
            featureIds.add(story.Feature__c);
        }
        if (!featureIds.isEmpty()) {
            calculateFeatureProgress(featureIds);
        }
        
        // Step 4: Get affected sprints and calculate sprint progress
        Set<Id> sprintIds = new Set<Id>();
        for (User_Story__c story : [SELECT Sprint__c FROM User_Story__c WHERE Id IN :storyIds]) {
            sprintIds.add(story.Sprint__c);
        }
        if (!sprintIds.isEmpty()) {
            calculateSprintProgress(sprintIds);
        }
        
        // Step 5: Get affected projects and calculate project progress
        Set<Id> projectIds = new Set<Id>();
        for (Sprint__c sprint : [SELECT Project__c FROM Sprint__c WHERE Id IN :sprintIds]) {
            projectIds.add(sprint.Project__c);
        }
        if (!projectIds.isEmpty()) {
            calculateProjectProgress(projectIds);
        }
    }
}
