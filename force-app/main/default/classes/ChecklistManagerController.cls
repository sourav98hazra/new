/**
 * @description Controller for Checklist Manager LWC
 */
public with sharing class ChecklistManagerController {
    
    /**
     * @description Get checklist items for a task
     */
    @AuraEnabled(cacheable=true)
    public static List<Task_Checklist_Item__c> getChecklistItems(Id taskId) {
        return [
            SELECT Id, Name, Description__c, Is_Completed__c, Completed_Date__c, 
                   Completed_By__r.Name, Sequence__c
            FROM Task_Checklist_Item__c
            WHERE Task__c = :taskId
            ORDER BY Sequence__c ASC NULLS LAST, CreatedDate ASC
        ];
    }
    
    /**
     * @description Toggle checklist item completion status
     */
    @AuraEnabled
    public static void toggleChecklistItem(Id checklistItemId, Boolean isCompleted) {
        try {
            Task_Checklist_Item__c item = [
                SELECT Id, Is_Completed__c
                FROM Task_Checklist_Item__c
                WHERE Id = :checklistItemId
                LIMIT 1
            ];
            
            item.Is_Completed__c = isCompleted;
            
            if (isCompleted) {
                item.Completed_Date__c = System.now();
                item.Completed_By__c = UserInfo.getUserId();
            } else {
                item.Completed_Date__c = null;
                item.Completed_By__c = null;
            }
            
            update item;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating checklist item: ' + e.getMessage());
        }
    }
}
