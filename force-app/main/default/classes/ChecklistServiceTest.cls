/**
 * @description Test class for ChecklistService
 */
@isTest
private class ChecklistServiceTest {
    
    @testSetup
    static void setup() {
        Project__c project = new Project__c(Name = 'Test Project', Status__c = 'Active');
        insert project;
        
        Sprint__c sprint = new Sprint__c(
            Name = 'Sprint 1',
            Project__c = project.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(14)
        );
        insert sprint;
        
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Test Story',
            Sprint__c = sprint.Id,
            Status__c = 'New'
        );
        insert story;
        
        Task__c task = new Task__c(
            Task_Title__c = 'Test Task',
            User_Story__c = story.Id,
            Status__c = 'New',
            Task_Type__c = 'Development'
        );
        insert task;
    }
    
    @isTest
    static void testUpdateTaskChecklistStatus() {
        Task__c task = [SELECT Id FROM Task__c LIMIT 1];
        
        // Create checklist items
        List<Task_Checklist_Item__c> items = new List<Task_Checklist_Item__c>{
            new Task_Checklist_Item__c(Name = 'Item 1', Task__c = task.Id, Is_Completed__c = true),
            new Task_Checklist_Item__c(Name = 'Item 2', Task__c = task.Id, Is_Completed__c = false)
        };
        insert items;
        
        Test.startTest();
        ChecklistService.updateTaskChecklistStatus(new Set<Id>{ task.Id });
        Test.stopTest();
        
        Task__c updatedTask = [SELECT Checklist_Complete__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(false, updatedTask.Checklist_Complete__c, 'Checklist should not be complete');
        
        // Complete all items
        items[1].Is_Completed__c = true;
        update items[1];
        
        ChecklistService.updateTaskChecklistStatus(new Set<Id>{ task.Id });
        updatedTask = [SELECT Checklist_Complete__c FROM Task__c WHERE Id = :task.Id];
        System.assertEquals(true, updatedTask.Checklist_Complete__c, 'Checklist should be complete');
    }
    
    @isTest
    static void testCreateDefaultChecklistItems() {
        Task__c task = [SELECT Id, Task_Type__c FROM Task__c LIMIT 1];
        
        Test.startTest();
        ChecklistService.createDefaultChecklistItems(new List<Task__c>{ task });
        Test.stopTest();
        
        List<Task_Checklist_Item__c> items = [
            SELECT Id, Name
            FROM Task_Checklist_Item__c
            WHERE Task__c = :task.Id
        ];
        
        System.assert(items.size() > 0, 'Default checklist items should be created');
    }
}
