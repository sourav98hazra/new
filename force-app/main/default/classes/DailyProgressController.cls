/**
 * @description Controller for Daily Progress Modal LWC
 */
public with sharing class DailyProgressController {
    
    /**
     * @description Get tasks assigned to current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Task__c> getUserTasks() {
        return [
            SELECT Id, Name, Task_Title__c, Estimated_Hours__c, Actual_Hours__c, Task_Progress__c, Status__c
            FROM Task__c
            WHERE Assigned_To__c = :UserInfo.getUserId()
                AND Status__c != 'Completed'
            ORDER BY Due_Date__c ASC NULLS LAST, CreatedDate DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description Create daily progress entry
     */
    @AuraEnabled
    public static void createDailyProgress(String progressData) {
        try {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(progressData);
            
            Daily_Progress__c progress = new Daily_Progress__c(
                Task__c = (String)data.get('taskId'),
                Hours_Worked__c = (Decimal)data.get('hoursWorked'),
                Progress_Percentage__c = (Decimal)data.get('progressPercentage'),
                Notes__c = (String)data.get('notes'),
                Progress_Date__c = Date.valueOf((String)data.get('progressDate')),
                Developer__c = UserInfo.getUserId()
            );
            
            insert progress;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating daily progress: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get recent progress entries for a task
     */
    @AuraEnabled(cacheable=true)
    public static List<Daily_Progress__c> getTaskProgress(Id taskId) {
        return [
            SELECT Id, Progress_Date__c, Hours_Worked__c, Progress_Percentage__c, Notes__c, Developer__r.Name
            FROM Daily_Progress__c
            WHERE Task__c = :taskId
            ORDER BY Progress_Date__c DESC
            LIMIT 10
        ];
    }
}
