import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getChecklistItems from '@salesforce/apex/ChecklistManagerController.getChecklistItems';
import toggleChecklistItem from '@salesforce/apex/ChecklistManagerController.toggleChecklistItem';

export default class ChecklistManager extends LightningElement {
    @api recordId; // Task ID
    @track checklistItems = [];
    @track isLoading = true;
    wiredChecklistResult;

    @wire(getChecklistItems, { taskId: '$recordId' })
    wiredChecklist(result) {
        this.wiredChecklistResult = result;
        if (result.data) {
            this.checklistItems = result.data.map(item => ({
                ...item,
                checked: item.Is_Completed__c
            }));
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading checklist:', result.error);
            this.isLoading = false;
        }
    }

    handleCheckboxChange(event) {
        const itemId = event.target.dataset.id;
        const isChecked = event.target.checked;
        
        this.isLoading = true;
        
        toggleChecklistItem({ checklistItemId: itemId, isCompleted: isChecked })
            .then(() => {
                this.showToast('Success', 'Checklist item updated', 'success');
                return refreshApex(this.wiredChecklistResult);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to update checklist', 'error');
                // Revert checkbox
                event.target.checked = !isChecked;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get completedCount() {
        return this.checklistItems.filter(item => item.checked).length;
    }

    get totalCount() {
        return this.checklistItems.length;
    }

    get progressPercentage() {
        if (this.totalCount === 0) return 0;
        return Math.round((this.completedCount / this.totalCount) * 100);
    }

    get hasItems() {
        return this.checklistItems.length > 0;
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
}
