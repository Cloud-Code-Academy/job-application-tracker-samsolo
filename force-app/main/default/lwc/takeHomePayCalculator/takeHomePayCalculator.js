import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SALARY_FIELD from '@salesforce/schema/Job_Application__c.Salary_Curr__c';

// --- Constants for Tax Calculations ---
// Note: These values should be reviewed and updated annually.
const SOCIAL_SECURITY_RATE = 0.062;
const SOCIAL_SECURITY_LIMIT = 177900; // Estimated for 2025
const MEDICARE_RATE = 0.0145;

export default class TakeHomePayCalculator extends LightningElement {
    @api recordId;

    // --- Input Properties ---
    @track salary = 50000; // Default salary for new records
    @track filingStatus = 'Single';

    // --- Calculated Properties ---
    @track federalTax = 0;
    @track socialSecurity = 0;
    @track medicare = 0;
    @track netYearlyPay = 0;
    @track netSixMonthPay = 0;
    @track netMonthlyPay = 0;
    @track netBiWeeklyPay = 0;

    // --- Picklist Options ---
    filingStatusOptions = [
        { label: 'Single', value: 'Single' },
        { label: 'Married, filing jointly', value: 'Married, filing jointly' },
        { label: 'Married, filing separately', value: 'Married, filing separately' },
        { label: 'Head of Household', value: 'Head of Household' },
    ];

    // --- Lifecycle Hooks ---
    connectedCallback() {
        this.recalculate();
    }

    // Optional: Wire service to default salary from the record
    @wire(getRecord, { recordId: '$recordId', fields: [SALARY_FIELD] })
    wiredJobApplication({ error, data }) {
        if (data) {
            const recordSalary = getFieldValue(data, SALARY_FIELD);
            if (recordSalary) {
                this.salary = recordSalary;
                this.recalculate();
            }
        } else if (error) {
            console.error('Error loading salary:', JSON.stringify(error));
        }
    }

    // --- Event Handlers ---
    handleSalaryChange(event) {
        this.salary = parseFloat(event.detail.value) || 0;
        this.recalculate();
    }

    handleFilingStatusChange(event) {
        this.filingStatus = event.detail.value;
        this.recalculate();
    }

    // --- Core Calculation Logic ---
    recalculate() {
        // --- FICA Taxes ---
        const socialSecurityEligibleIncome = Math.min(this.salary, SOCIAL_SECURITY_LIMIT);
        this.socialSecurity = socialSecurityEligibleIncome * SOCIAL_SECURITY_RATE;
        this.medicare = this.salary * MEDICARE_RATE;

        // --- Federal Income Tax ---
        // For simplicity, this uses a standard deduction. A full implementation
        // would include the itemized vs. standard deduction choice.
        let standardDeduction = 0;
        switch (this.filingStatus) {
            case 'Single':
            case 'Married, filing separately':
                standardDeduction = 15000;
                break;
            case 'Married, filing jointly':
                standardDeduction = 30000;
                break;
            case 'Head of Household':
                standardDeduction = 22500;
                break;
        }
        const taxableIncome = Math.max(0, this.salary - standardDeduction);
        this.federalTax = this._calculateFederalTax(taxableIncome, this.filingStatus);

        // --- Net Pay Calculations ---
        const totalDeductions = this.federalTax + this.socialSecurity + this.medicare;
        this.netYearlyPay = this.salary - totalDeductions;
        this.netSixMonthPay = this.netYearlyPay / 2;
        this.netMonthlyPay = this.netYearlyPay / 12;
        this.netBiWeeklyPay = this.netYearlyPay / 26;
    }

    // --- Private Helper for Federal Tax ---
    _calculateFederalTax(income, status) {
        if (status === 'Single') {
            if (income <= 11925) return income * 0.10;
            if (income <= 48475) return 1192.50 + (income - 11925) * 0.12;
            if (income <= 103350) return 5578.50 + (income - 48475) * 0.22;
            if (income <= 197300) return 17651 + (income - 103350) * 0.24;
            if (income <= 250525) return 40199 + (income - 197300) * 0.32;
            if (income <= 626350) return 57231 + (income - 250525) * 0.35;
            return 188769.75 + (income - 626350) * 0.37;
        }
        if (status === 'Married, filing jointly') {
            if (income <= 23850) return income * 0.10;
            if (income <= 96950) return 2385 + (income - 23850) * 0.12;
            if (income <= 206700) return 11157 + (income - 96950) * 0.22;
            if (income <= 394600) return 35302 + (income - 206700) * 0.24;
            if (income <= 501050) return 80398 + (income - 394600) * 0.32;
            if (income <= 751600) return 114462 + (income - 501050) * 0.35;
            return 202154.50 + (income - 751600) * 0.37;
        }
        if (status === 'Married, filing separately') {
            if (income <= 11925) return income * 0.10;
            if (income <= 48475) return 1192.50 + (income - 11925) * 0.12;
            if (income <= 103350) return 5578.50 + (income - 48475) * 0.22;
            if (income <= 197300) return 17651 + (income - 103350) * 0.24;
            if (income <= 250525) return 40199 + (income - 197300) * 0.32;
            if (income <= 375800) return 57231 + (income - 250525) * 0.35;
            return 101077.25 + (income - 375800) * 0.37;
        }
        if (status === 'Head of Household') {
            if (income <= 17000) return income * 0.10;
            if (income <= 64850) return 1700 + (income - 17000) * 0.12;
            if (income <= 103350) return 7442 + (income - 64850) * 0.22;
            if (income <= 197300) return 15912 + (income - 103350) * 0.24;
            if (income <= 250500) return 38460 + (income - 197300) * 0.32;
            if (income <= 626350) return 55484 + (income - 250500) * 0.35;
            return 187031.50 + (income - 626350) * 0.37;
        }
        return 0; // Default case
    }
}
