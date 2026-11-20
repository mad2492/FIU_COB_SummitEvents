import { createElement } from 'lwc';
import FiuSummitEmailSettings from 'c/fiuSummitEmailSettings';
import getSettings from '@salesforce/apex/FIU_SummitEmailSettingsController.getSettings';
import saveSelection from '@salesforce/apex/FIU_SummitEmailSettingsController.saveSelection';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

jest.mock(
    '@salesforce/apex/FIU_SummitEmailSettingsController.getSettings',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/FIU_SummitEmailSettingsController.saveSelection',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock('lightning/uiRecordApi', () => ({
    notifyRecordUpdateAvailable: jest.fn()
}));

const SAVED_SETTINGS = {
    recordId: 'record-id',
    orgWideEmailId: 'saved-sender-id',
    orgWideEmailAddress: 'events@example.com',
    letterheadId: 'saved-letterhead-id',
    letterheadName: 'FIU Events Letterhead'
};

async function openPicker(settings) {
    getSettings.mockResolvedValue(settings);
    const element = createElement('c-fiu-summit-email-settings', {
        is: FiuSummitEmailSettings
    });
    element.recordId = SAVED_SETTINGS.recordId;
    document.body.appendChild(element);
    await Promise.resolve();
    await Promise.resolve();
    return element.shadowRoot;
}

function getDropdown(root, name) {
    return [...root.querySelectorAll('lightning-combobox')].find((dropdown) => dropdown.name === name);
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.resetAllMocks();
});

it('keeps the saved selections visible when both choices are unavailable', async () => {
    const root = await openPicker(SAVED_SETTINGS);

    expect(root.textContent).toContain('Currently selected: events@example.com');
    expect(root.textContent).toContain('Currently selected: FIU Events Letterhead');
    expect(root.textContent).toContain('Sender choices are unavailable.');
    expect(root.textContent).toContain('Letterhead choices are unavailable.');
    expect(getDropdown(root, 'orgWideEmail').disabled).toBe(true);
    expect(getDropdown(root, 'letterhead').disabled).toBe(true);
});

it('saves only the changed letterhead when sender choices are unavailable', async () => {
    const root = await openPicker({
        ...SAVED_SETTINGS,
        letterheads: [{ label: 'New letterhead', value: 'new-letterhead-id' }]
    });
    saveSelection.mockResolvedValue({
        ...SAVED_SETTINGS,
        letterheadId: 'new-letterhead-id',
        letterheadName: 'New letterhead'
    });
    notifyRecordUpdateAvailable.mockResolvedValue();

    getDropdown(root, 'letterhead').dispatchEvent(
        new CustomEvent('change', { detail: { value: 'new-letterhead-id' } })
    );
    await Promise.resolve();
    await Promise.resolve();

    expect(saveSelection).toHaveBeenCalledWith({
        recordId: SAVED_SETTINGS.recordId,
        setting: 'letterhead',
        selectionId: 'new-letterhead-id'
    });
    expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{ recordId: SAVED_SETTINGS.recordId }]);
    expect(root.textContent).toContain('Currently selected: events@example.com');
    expect(root.textContent).toContain('Currently selected: New letterhead');
});
