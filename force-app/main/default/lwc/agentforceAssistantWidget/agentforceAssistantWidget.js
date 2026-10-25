import { LightningElement, track } from 'lwc';
import processQuery from '@salesforce/apex/CareNestAssistantUIController.processQuery';

export default class AgentforceAssistantWidget extends LightningElement {
    @track messages = [];
    @track inputPrompt = '';
    @track isThinking = false;
    messageCounter = 0;

    get isSendDisabled() {
        return !this.inputPrompt || this.inputPrompt.trim().length === 0 || this.isThinking;
    }

    handleInputChange(event) {
        this.inputPrompt = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !this.isSendDisabled) {
            this.handleSend();
        }
    }

    handleQuickPrompt(event) {
        const prompt = event.currentTarget.dataset.prompt;
        this.inputPrompt = prompt;
        this.handleSend();
    }

    async handleSend() {
        const query = this.inputPrompt.trim();
        if (!query) return;

        // Add user message
        this.messageCounter++;
        const userMsg = {
            id: `msg-${this.messageCounter}`,
            text: query,
            isBot: false,
            wrapperClass: 'message-bubble-wrapper message-user slds-m-bottom_medium',
            bubbleClass: 'message-bubble message-bubble-user',
            hasDoctors: false,
            hasWards: false,
            hasAppointment: false,
            isEmergency: false
        };
        this.messages = [...this.messages, userMsg];
        this.inputPrompt = '';
        this.isThinking = true;

        try {
            const resp = await processQuery({ promptText: query });
            this.messageCounter++;

            let doctors = [];
            let wards = [];
            let appointment = null;

            if (resp.payloadJson) {
                try {
                    const parsed = JSON.parse(resp.payloadJson);
                    if (resp.actionInvoked === 'DoctorSearchAction' && Array.isArray(parsed)) {
                        doctors = parsed;
                    } else if (resp.actionInvoked === 'WardAvailabilityAction' && Array.isArray(parsed)) {
                        wards = parsed;
                    } else if (resp.actionInvoked === 'AppointmentStatusAction' && typeof parsed === 'object') {
                        appointment = parsed;
                    }
                } catch (e) {
                    console.error('Error parsing response payload', e);
                }
            }

            const botMsg = {
                id: `msg-${this.messageCounter}`,
                text: resp.message,
                isBot: true,
                wrapperClass: 'message-bubble-wrapper message-bot slds-m-bottom_medium',
                bubbleClass: 'message-bubble message-bubble-bot',
                hasDoctors: doctors.length > 0,
                doctors,
                hasWards: wards.length > 0,
                wards,
                hasAppointment: appointment != null,
                appointment,
                isEmergency: resp.isEmergency
            };

            this.messages = [...this.messages, botMsg];
        } catch (error) {
            this.messageCounter++;
            let errMsg = 'I encountered an error processing your inquiry.';
            if (error && error.body && error.body.message) {
                errMsg = error.body.message;
            } else if (error && error.message) {
                errMsg = error.message;
            }
            const errBotMsg = {
                id: `msg-${this.messageCounter}`,
                text: errMsg,
                isBot: true,
                wrapperClass: 'message-bubble-wrapper message-bot slds-m-bottom_medium',
                bubbleClass: 'message-bubble message-bubble-bot message-bubble-error',
                hasDoctors: false,
                hasWards: false,
                hasAppointment: false,
                isEmergency: false
            };
            this.messages = [...this.messages, errBotMsg];
        } finally {
            this.isThinking = false;
        }
    }

    handleClearChat() {
        this.messages = [];
        this.inputPrompt = '';
    }
}
