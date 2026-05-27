/**
 * @description Controller for Sprint Dashboard LWC
 */
public with sharing class SprintDashboardController {
    
    /**
     * @description Get sprint metrics and statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getSprintMetrics(Id sprintId) {
        Map<String, Integer> metrics = new Map<String, Integer>();
        
        // Story metrics
        List<AggregateResult> storyStats = [
            SELECT Status__c, COUNT(Id) cnt
            FROM User_Story__c
            WHERE Sprint__c = :sprintId
            GROUP BY Status__c
        ];
        
        Integer totalStories = 0;
        Integer completedStories = 0;
        Integer inProgressStories = 0;
        Integer notStartedStories = 0;
        
        for (AggregateResult ar : storyStats) {
            String status = (String)ar.get('Status__c');
            Integer count = (Integer)ar.get('cnt');
            totalStories += count;
            
            if (status == 'Done' || status == 'SIT Approved') {
                completedStories += count;
            } else if (status == 'In Progress' || status == 'In QA' || status == 'In SIT' || status == 'Ready for QA' || status == 'Ready for SIT') {
                inProgressStories += count;
            } else if (status == 'New') {
                notStartedStories += count;
            }
        }
        
        // Task metrics
        List<AggregateResult> taskStats = [
            SELECT Status__c, COUNT(Id) cnt
            FROM Task__c
            WHERE User_Story__r.Sprint__c = :sprintId
            GROUP BY Status__c
        ];
        
        Integer totalTasks = 0;
        Integer completedTasks = 0;
        
        for (AggregateResult ar : taskStats) {
            String status = (String)ar.get('Status__c');
            Integer count = (Integer)ar.get('cnt');
            totalTasks += count;
            
            if (status == 'Completed') {
                completedTasks += count;
            }
        }
        
        // Overdue tasks
        Integer overdueTasks = [
            SELECT COUNT()
            FROM Task__c
            WHERE User_Story__r.Sprint__c = :sprintId
                AND Is_Overdue__c = true
        ];
        
        metrics.put('totalStories', totalStories);
        metrics.put('completedStories', completedStories);
        metrics.put('inProgressStories', inProgressStories);
        metrics.put('notStartedStories', notStartedStories);
        metrics.put('totalTasks', totalTasks);
        metrics.put('completedTasks', completedTasks);
        metrics.put('overdueTasks', overdueTasks);
        
        return metrics;
    }
}
