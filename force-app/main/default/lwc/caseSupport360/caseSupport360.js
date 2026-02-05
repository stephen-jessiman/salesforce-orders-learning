import { LightningElement, api, wire } from 'lwc';
import getSupport360 from '@salesforce/apex/CaseSupport360Controller.getSupport360';

export default class CaseSupport360 extends LightningElement {
    @api recordId;

    data;
    loading = true;
    errorMessage;

    orderItemColumns = [
        { label: 'Product', fieldName: 'productName', type: 'text' },
        { label: 'Qty', fieldName: 'quantity', type: 'number' },
        { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
        { label: 'Total', fieldName: 'totalPrice', type: 'currency' }
    ];

    returnLineColumns = [
        { label: 'Product', fieldName: 'productName', type: 'text' },
        { label: 'Qty', fieldName: 'quantity', type: 'number' },
        { label: 'Condition', fieldName: 'condition', type: 'text' },
        { label: 'Notes', fieldName: 'notes', type: 'text' }
    ];

    @wire(getSupport360, { caseId: '$recordId' })
    wiredSupport360({ data, error }) {
        this.loading = false;
        if (data) {
            this.data = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.data = undefined;
            this.errorMessage = this.normalizeError(error);
        }
    }

    get hasOrderItems() {
        return this.data?.orderItems?.length > 0;
    }

    get hasReturnLines() {
        return this.data?.returnLines?.length > 0;
    }

    normalizeError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error.body?.message || error.message || 'Unknown error';
    }
}

