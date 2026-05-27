/**
 * @description Trigger on Salesforce native Task (Activity) object
 * When a formality/unit-testing Activity Task is completed,
 * syncs the completion back to the parent User Story checkbox
 */
trigger ActivityTaskTrigger on Task (after update) {
    if (Trigger.isUpdate) {
        List<Task> justCompleted = new List<Task>();

        for (Task t : Trigger.new) {
            Task oldTask = Trigger.oldMap.get(t.Id);
            // Only care about tasks that just became Completed
            if (t.Status == 'Completed' && oldTask.Status != 'Completed') {
                justCompleted.add(t);
            }
        }

        if (!justCompleted.isEmpty()) {
            FormalitiesService.syncTaskCompletionToStory(justCompleted);
        }
    }
}
