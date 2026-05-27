import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import createDailyProgress from '@salesforce/apex/DailyProgressController.createDailyProgress';
import getUserTasks from '@salesforce/apex/DailyProgressController.getUserTasks';

const TASK_FIELDS = ['Task__c.Name', 'Task__c.Task_Title__c', 'Task__c.Estimated_Hours__c', 'Task__c.Actual_Hours__c', 'Task__c.Task_Progress__c'];

export default class DailyProgressModal extends LightningElement {
    @api recordId; // Task ID if opened from task record
    @track showModal = false;
    @track selectedTaskId;
    @track hoursWorked = 0;
    @track progressPercentage = 0;
    @track notes = '';
    @track progressDate;
    @track tasks = [];
    @track isLoading = false;

    connectedCallback() {
        this.progressDate = new Date().toISOString().split('T')[0];
        this.loadUserTasks();
    }

    @wire(getRecord, { recordId: '$recordId', fields: TASK_FIELDS })
    wiredTask({ error, data }) {
        if (data) {
            this.selectedTaskId = this.recordId;
        }
    }

    loadUserTasks() {
        this.isLoading = true;
        getUserTasks()
            .then(result => {
                this.tasks = result.map(task => ({
                    label: `${task.Name} - ${task.Task_Title__c}`,
                    value: task.Id
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load tasks', 'error');
                this.isLoading = false;
            });
    }

    @api
    openModal() {
        this.showModal = true;
        if (this.recordId) {
            this.selectedTaskId = this.recordId;
        }
    }

    closeModal() {
        this.showModal = false;
        this.resetForm();
    }

    handleTaskChange(event) {
        this.selectedTaskId = event.detail.value;
    }

    handleHoursChange(event) {
        this.hoursWorked = event.detail.value;
        // Auto-calculate progress percentage if we know the task
        this.calculateProgressPercentage();
    }

    handleProgressChange(event) {
        this.progressPercentage = event.detail.value;
    }

    handleNotesChange(event) {
        this.notes = event.detail.value;
    }

    handleDateChange(event) {
        this.progressDate = event.detail.value;
    }

    calculateProgressPercentage() {
        // This could be enhanced to auto-calculate based on task estimates
        // For now, user manually enters percentage
    }

    handleSubmit() {
        // Validation
        if (!this.selectedTaskId) {
            this.showToast('Error', 'Please select a task', 'error');
            return;
        }
        if (!this.hoursWorked || this.hoursWorked <= 0) {
            this.showToast('Error', 'Please enter hours worked', 'error');
            return;
        }
        if (this.progressPercentage < 0 || this.progressPercentage > 100) {
            this.showToast('Error', 'Progress percentage must be between 0 and 100', 'error');
            return;
        }

        this.isLoading = true;

        const progressData = {
            taskId: this.selectedTaskId,
            hoursWorked: this.hoursWorked,
            progressPercentage: this.progressPercentage,
            notes: this.notes,
            progressDate: this.progressDate
        };

        createDailyProgress({ progressData: JSON.stringify(progressData) })
            .then(() => {
                this.showToast('Success', 'Daily progress logged successfully!', 'success');
                this.closeModal();
                // Refresh the page or dispatch event
                this.dispatchEvent(new CustomEvent('progresssaved'));
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to save progress', 'error');
                this.isLoading = false;
            });
    }

    resetForm() {
        this.hoursWorked = 0;
        this.progressPercentage = 0;
        this.notes = '';
        this.progressDate = new Date().toISOString().split('T')[0];
        if (!this.recordId) {
            this.selectedTaskId = null;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    get modalClass() {
        return this.showModal ? 'slds-modal slds-fade-in-open' : 'slds-modal';
    }

    get backdropClass() {
        return this.showModal ? 'slds-backdrop slds-backdrop_open' : 'slds-backdrop';
    }
}
