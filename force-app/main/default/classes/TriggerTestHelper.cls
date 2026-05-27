/**
 * @description Test helper class for creating test data for trigger tests
 */
@isTest
public class TriggerTestHelper {
    
    public static Project__c createProject() {
        Project__c project = new Project__c(
            Name = 'Test Project',
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(60)
        );
        insert project;
        return project;
    }
    
    public static Sprint__c createSprint(Id projectId) {
        Sprint__c sprint = new Sprint__c(
            Name = 'Sprint ' + String.valueOf(System.currentTimeMillis()),
            Project__c = projectId,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(14)
        );
        insert sprint;
        return sprint;
    }
    
    public static Feature__c createFeature(Id sprintId) {
        Feature__c feature = new Feature__c(
            Name = 'Test Feature',
            Sprint__c = sprintId,
            Status__c = 'Not Started',
            Priority__c = 'High'
        );
        insert feature;
        return feature;
    }
    
    public static User_Story__c createUserStory(Id sprintId, Id featureId) {
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Test Story',
            Sprint__c = sprintId,
            Feature__c = featureId,
            Status__c = 'New',
            Story_Points__c = 5,
            Estimated_Hours__c = 40
        );
        insert story;
        return story;
    }
    
    public static Task__c createTask(Id storyId) {
        Task__c task = new Task__c(
            Task_Title__c = 'Test Task',
            User_Story__c = storyId,
            Status__c = 'New',
            Estimated_Hours__c = 8,
            Task_Type__c = 'Development'
        );
        insert task;
        return task;
    }
    
    public static Daily_Progress__c createDailyProgress(Id taskId, Decimal hoursWorked) {
        Daily_Progress__c progress = new Daily_Progress__c(
            Task__c = taskId,
            Hours_Worked__c = hoursWorked,
            Progress_Percentage__c = 50,
            Progress_Date__c = Date.today(),
            Developer__c = UserInfo.getUserId()
        );
        insert progress;
        return progress;
    }
}
