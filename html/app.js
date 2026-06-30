const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-advanced-ambulance-v2';
let state = {
    patient: null,
    billMax: 25000,
    tests: {},
    surgeries: {},
    bookingData: { bookings: [], locations: [] },
    packageAdmin: { packages: [], tests: [] },
    selectedPackage: null
};

const $ = (selector) => document.querySelector(selector);
const tablet = $('#tablet');
const death = $('#death');
const recordsList = $('#recordsList');
const healthReportsList = $('#healthReportsList');

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[character]);
}

function post(event, data = {}) {
    return fetch(`https://${resource}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json()).catch(() => null);
}

function qbNotify(message, type = 'primary') {
    return post('tabletNotify', { message, type });
}

function setTab(name) {
    document.querySelectorAll('.nav').forEach((button) => button.classList.toggle('active', button.dataset.tab === name));
    document.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('active', tab.id === name));
}

function formatTimer(seconds) {
    const mins = Math.floor(seconds / 60).toString().padStart(2, '0');
    const secs = Math.floor(seconds % 60).toString().padStart(2, '0');
    return `${mins}:${secs}`;
}

function setPatient(patient) {
    state.patient = patient || null;
    const name = patient?.name || 'No patient';
    $('#patientName').textContent = name;
    $('#patientTitle').textContent = name;
    $('#patientMeta').textContent = patient ? 'Patient loaded and ready for treatment.' : 'Use /patient [id] near a patient to load details.';
    $('#patientStatus').textContent = patient?.status || 'Unknown';
    $('#citizenId').textContent = patient?.citizenid || '-';
    $('#serverId').textContent = patient?.source || '-';
}

function renderRecords(records) {
    if (!records || records.length === 0) {
        recordsList.className = 'records empty';
        recordsList.textContent = 'No records found.';
        return;
    }
    recordsList.className = 'records';
    recordsList.innerHTML = records.map((record) => `
        <article class="record">
            <strong>$${record.bill || 0} - ${record.doctor || 'Unknown doctor'}</strong>
            <span>${record.created_at || ''}</span>
            <p>${record.notes || 'No notes.'}</p>
        </article>
    `).join('');
}

function fillProcedureSelect(selector, catalog) {
    selector.innerHTML = Object.entries(catalog || {}).map(([id, item]) =>
        `<option value="${escapeHtml(id)}">${escapeHtml(item.category ? `${item.category} - ${item.label}` : item.label)}</option>`
    ).join('');
}

function renderHealthReports(reports) {
    if (!reports?.length) {
        healthReportsList.className = 'records empty';
        healthReportsList.textContent = 'No clinical reports found.';
        return;
    }
    healthReportsList.className = 'records';
    healthReportsList.innerHTML = reports.map((report) => {
        const findings = report.findings || {};
        const values = Object.entries(findings).map(([key, value]) =>
            `<span><strong>${escapeHtml(key)}</strong><br>${escapeHtml(value)}</span>`
        ).join('');
        return `<article class="record">
            <strong>${escapeHtml(report.procedure_name)}</strong>
            <span>${escapeHtml(report.category)} &middot; ${escapeHtml(report.created_at)} &middot; ${escapeHtml(report.doctor_name)}</span>
            <p>${escapeHtml(report.summary)}</p>
            <div class="finding-grid">${values}</div>
            ${report.doctor_notes ? `<p>Notes: ${escapeHtml(report.doctor_notes)}</p>` : ''}
        </article>`;
    }).join('');
}

const bookingStatuses = ['placed', 'awaiting_visit', 'samples_collected', 'scans_completed', 'awaiting_report', 'report_published', 'completed'];
const statusLabels = {
    placed: 'Order placed', awaiting_visit: 'Awaiting hospital visit', samples_collected: 'Samples collected',
    scans_completed: 'Samples and scans completed', awaiting_report: 'Waiting for report', report_published: 'Report published', completed: 'Completed'
};

function renderBookingQueue(data) {
    state.bookingData = data || { bookings: [], locations: [] };
    const container = $('#bookingQueue');
    if (!state.bookingData.bookings?.length) {
        container.className = 'booking-list empty';
        container.textContent = 'No active bookings.';
        return;
    }
    container.className = 'booking-list';
    container.innerHTML = state.bookingData.bookings.map((booking) => {
        const index = bookingStatuses.indexOf(booking.status);
        const nextLabel = statusLabels[bookingStatuses[index + 1]] || 'Complete';
        const track = bookingStatuses.slice(0, 6).map((_, step) => `<span class="status-step ${step <= index ? 'done' : ''}"></span>`).join('');
        return `<article class="booking-card" data-booking-id="${Number(booking.id)}">
            <div class="booking-head"><div><strong>${escapeHtml(booking.patient_name)}</strong><span>${escapeHtml(booking.booking_ref)} &middot; ${escapeHtml(booking.package_name)}</span></div><strong>${escapeHtml(statusLabels[booking.status] || booking.status)}</strong></div>
            <div class="booking-meta">${escapeHtml(booking.location_name || 'No location')} &middot; $${Number(booking.amount)} &middot; ${escapeHtml(booking.payment_method)} / ${escapeHtml(booking.payment_status)}</div>
            <div class="status-track">${track}</div>
            <div class="booking-actions">
                <input class="booking-note" placeholder="Status note" maxlength="255">
                ${booking.payment_status !== 'paid' ? '<select class="payment-method"><option value="card">Card</option><option value="bank">Bank</option><option value="cash">Cash</option></select><button class="payment" data-action="payment">Collect Payment</button>' : ''}
                <button data-action="advance">${escapeHtml(nextLabel)}</button>
            </div>
        </article>`;
    }).join('');
}

function renderLocations(locations) {
    const container = $('#serviceLocations');
    if (!locations?.length) {
        container.className = 'location-list empty';
        container.textContent = 'No locations configured.';
        return;
    }
    container.className = 'location-list';
    container.innerHTML = locations.map((location) => `<article class="location-row ${Number(location.active) ? '' : 'inactive'}">
        <div><strong>${escapeHtml(location.name)}</strong><span>${escapeHtml(location.location_type)} &middot; ${Number(location.x).toFixed(2)}, ${Number(location.y).toFixed(2)}</span></div>
        <button data-location-id="${Number(location.id)}">${Number(location.active) ? 'Disable' : 'Enable'}</button>
    </article>`).join('');
}

async function loadBookingQueue() {
    const data = await post('bookingQueue');
    if (!data) { qbNotify('Unable to load the booking queue.', 'error'); return; }
    renderBookingQueue(data);
    renderLocations(data?.locations || []);
}

function updatePackageTotals() {
    const selected = [...document.querySelectorAll('#packageTests input:checked')].map((input) => input.value);
    const selectedTests = document.querySelectorAll('#packageTestOptions input:checked').length;
    const selectedScans = document.querySelectorAll('#packageScanOptions input:checked').length;
    const base = state.packageAdmin.tests.filter((test) => selected.includes(test.test_id)).reduce((total, test) => total + Number(test.price || 0), 0);
    const discount = Math.max(0, Math.min(Number($('#packageDiscount').value || 0), 90));
    $('#packageBasePrice').textContent = `$${base.toLocaleString()}`;
    $('#packageSalePrice').textContent = `$${Math.round(base * (1 - discount / 100)).toLocaleString()}`;
    $('#testSelectedCount').textContent = `${selectedTests} selected`;
    $('#scanSelectedCount').textContent = `${selectedScans} selected`;
    document.querySelectorAll('.test-option').forEach((card) => {
        card.classList.toggle('selected', card.querySelector('input').checked);
    });
    const selectedLabels = state.packageAdmin.tests
        .filter((test) => selected.includes(test.test_id))
        .map((test) => test.label);
    const currentDescription = $('#packageDescription').value;
    const baseDescription = currentDescription.split('\nIncluded procedures:')[0].trim();
    $('#packageDescription').value = selectedLabels.length
        ? `${baseDescription}${baseDescription ? '\n' : ''}Included procedures: ${selectedLabels.join(', ')}`
        : baseDescription;
}

function resetPackageEditor() {
    state.selectedPackage = null;
    $('#packageId').value = '';
    $('#packageName').value = '';
    $('#packageDescription').value = '';
    $('#packageDiscount').value = '0';
    $('#packageActive').checked = true;
    document.querySelectorAll('#packageTests input').forEach((input) => { input.checked = false; });
    updatePackageTotals();
    document.querySelectorAll('.admin-package').forEach((button) => button.classList.remove('active'));
}

function selectPackage(id) {
    const item = state.packageAdmin.packages.find((entry) => Number(entry.id) === Number(id));
    if (!item) return;
    state.selectedPackage = item;
    $('#packageId').value = item.id;
    $('#packageName').value = item.name;
    $('#packageDescription').value = item.description || '';
    $('#packageDiscount').value = Number(item.discount_percent || 0);
    $('#packageActive').checked = Number(item.active) === 1;
    document.querySelectorAll('#packageTests input').forEach((input) => { input.checked = (item.tests || []).includes(input.value); });
    document.querySelectorAll('.admin-package').forEach((button) => button.classList.toggle('active', Number(button.dataset.packageId) === Number(id)));
    updatePackageTotals();
}

function renderPackageAdmin(data) {
    state.packageAdmin = data || { packages: [], tests: [] };
    $('#packageAdminList').className = state.packageAdmin.packages.length ? 'admin-list' : 'admin-list empty';
    $('#packageAdminList').innerHTML = state.packageAdmin.packages.map((item) => `<button class="admin-package" data-package-id="${Number(item.id)}"><strong>${escapeHtml(item.name)}</strong><span>$${Number(item.sale_price).toLocaleString()} ${Number(item.discount_percent) ? `(${Number(item.discount_percent)}% off)` : ''} &middot; ${Number(item.active) ? 'Available' : 'Hidden'}</span></button>`).join('') || 'No packages configured.';
    const activeProcedures = state.packageAdmin.tests.filter((test) => Number(test.active));
    const optionMarkup = (test) => `<label class="test-option"><span class="procedure-name">${escapeHtml(test.label)}</span><span class="procedure-meta">${escapeHtml(test.category)} &middot; $${Number(test.price)}</span><input type="checkbox" value="${escapeHtml(test.test_id)}"></label>`;
    $('#packageTestOptions').innerHTML = activeProcedures.filter((test) => test.category !== 'Imaging').map(optionMarkup).join('') || '<span class="muted">No tests available.</span>';
    $('#packageScanOptions').innerHTML = activeProcedures.filter((test) => test.category === 'Imaging').map(optionMarkup).join('') || '<span class="muted">No scans available.</span>';
    $('#testPriceList').className = state.packageAdmin.tests.length ? 'price-grid' : 'price-grid empty';
    $('#testPriceList').innerHTML = state.packageAdmin.tests.map((test) => `<label class="price-row" data-test-id="${escapeHtml(test.test_id)}"><span><strong>${escapeHtml(test.label)}</strong>${escapeHtml(test.category)}</span><input class="test-price" type="number" min="0" max="1000000" value="${Number(test.price)}"><input class="test-active" type="checkbox" ${Number(test.active) ? 'checked' : ''}></label>`).join('') || 'No tests configured.';
    $('#pricingTestCount').textContent = state.packageAdmin.tests.filter((test) => test.category !== 'Imaging').length;
    $('#pricingScanCount').textContent = state.packageAdmin.tests.filter((test) => test.category === 'Imaging').length;
    if (state.selectedPackage) selectPackage(state.selectedPackage.id); else resetPackageEditor();
}

async function loadPackageAdmin() {
    const data = await post('packageAdmin');
    if (!data) { qbNotify('Unable to load package settings.', 'error'); return; }
    renderPackageAdmin(data);
}

async function loadHealthReports() {
    if (!state.patient?.citizenid) { qbNotify('Load a patient before opening clinical reports.', 'error'); return; }
    const reports = await post('healthReports', { citizenid: state.patient.citizenid });
    renderHealthReports(reports);
}

function showAlert(alert) {
    const card = document.createElement('article');
    card.className = 'alert';
    card.innerHTML = `
        <strong>${alert.caller || 'Emergency Call'}</strong>
        <span>${alert.message || 'Medical emergency'}</span>
        <button>Set Waypoint</button>
    `;
    card.querySelector('button').addEventListener('click', () => post('waypoint', { coords: alert.coords }));
    $('#alertStack').appendChild(card);
    setTimeout(() => card.remove(), 15000);
}

window.addEventListener('message', (event) => {
    const { action, payload = {} } = event.data || {};

    if (action === 'open') {
        tablet.classList.remove('hidden');
        state.billMax = payload.config?.billMax || state.billMax;
        state.tests = payload.config?.tests || {};
        state.surgeries = payload.config?.surgeries || {};
        fillProcedureSelect($('#testSelect'), state.tests);
        fillProcedureSelect($('#surgerySelect'), state.surgeries);
        $('#doctorName').textContent = payload.player?.name || 'Doctor';
        $('#unitName').textContent = payload.player?.grade || 'EMS';
        $('#callsign').textContent = payload.player?.callsign || 'EMS';
        $('#grade').textContent = payload.player?.grade || 'Cadet';
        setPatient(payload.patient);
        setTab('overview');
    }

    if (action === 'close') tablet.classList.add('hidden');

    if (action === 'duty') {
        $('#dutyStatus').textContent = payload.onduty ? 'Available' : 'Off duty';
    }

    if (action === 'death') {
        death.classList.toggle('hidden', !payload.active);
        $('#deathTimer').textContent = formatTimer(payload.seconds || 0);
        $('#respawnHint').textContent = payload.seconds <= 0 ? 'Press E to respawn at hospital' : 'Respawn unlocks soon';
    }

    if (action === 'alert') showAlert(payload);
    if (action === 'reportReady') loadHealthReports();
    if (action === 'serviceDataChanged') loadBookingQueue();
    if (action === 'packageDataChanged') loadPackageAdmin();
});

document.querySelectorAll('.nav').forEach((button) => {
    button.addEventListener('click', () => {
        setTab(button.dataset.tab);
        if (button.dataset.tab === 'bookings' || button.dataset.tab === 'locations') loadBookingQueue();
        if (button.dataset.tab === 'packages' || button.dataset.tab === 'pricing') loadPackageAdmin();
    });
});

$('#close').addEventListener('click', () => post('close'));

$('#reviveBtn').addEventListener('click', () => {
    if (!state.patient?.source) { qbNotify('Load a nearby patient first.', 'error'); return; }
    post('revive', { target: state.patient.source });
});

$('#treatBtn').addEventListener('click', () => {
    if (!state.patient?.source) { qbNotify('Load a nearby patient first.', 'error'); return; }
    post('treat', { target: state.patient.source });
});

$('#recordsBtn').addEventListener('click', async () => {
    if (!state.patient?.citizenid) { qbNotify('Load a patient before opening records.', 'error'); return; }
    const records = await post('records', { citizenid: state.patient.citizenid });
    renderRecords(records);
    setTab('records');
});

$('#healthReportsBtn').addEventListener('click', loadHealthReports);

$('#runTestBtn').addEventListener('click', () => {
    if (!state.patient?.source) { qbNotify('Load a nearby patient before starting a test.', 'error'); return; }
    if (!$('#testSelect').value) { qbNotify('No diagnostic test is configured.', 'error'); return; }
    post('clinicalProcedure', {
        target: state.patient.source,
        procedureType: 'test',
        procedureId: $('#testSelect').value,
        notes: $('#testNotes').value
    });
});

$('#runSurgeryBtn').addEventListener('click', () => {
    if (!state.patient?.source) { qbNotify('Load a nearby patient before surgery.', 'error'); return; }
    if (!$('#surgerySelect').value) { qbNotify('No surgery is configured.', 'error'); return; }
    post('clinicalProcedure', {
        target: state.patient.source,
        procedureType: 'surgery',
        procedureId: $('#surgerySelect').value,
        notes: $('#surgeryNotes').value
    });
});

$('#refreshBookingsBtn').addEventListener('click', loadBookingQueue);
$('#refreshLocationsBtn').addEventListener('click', loadBookingQueue);

$('#locationForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    await post('addServiceLocation', { name: $('#locationName').value, locationType: $('#locationType').value });
    $('#locationName').value = '';
    setTimeout(loadBookingQueue, 300);
});

$('#serviceLocations').addEventListener('click', async (event) => {
    const button = event.target.closest('[data-location-id]');
    if (!button) return;
    await post('toggleServiceLocation', { id: Number(button.dataset.locationId) });
    setTimeout(loadBookingQueue, 300);
});

$('#bookingQueue').addEventListener('click', async (event) => {
    const button = event.target.closest('[data-action]');
    const card = event.target.closest('[data-booking-id]');
    if (!button || !card) return;
    const id = Number(card.dataset.bookingId);
    if (button.dataset.action === 'payment') {
        await post('collectBookingPayment', { id, method: card.querySelector('.payment-method').value });
    } else {
        await post('advanceBooking', { id, note: card.querySelector('.booking-note').value });
    }
    setTimeout(loadBookingQueue, 500);
});

$('#refreshPackagesBtn').addEventListener('click', loadPackageAdmin);
$('#newPackageBtn').addEventListener('click', resetPackageEditor);
$('#packageAdminList').addEventListener('click', (event) => {
    const button = event.target.closest('[data-package-id]');
    if (button) selectPackage(button.dataset.packageId);
});
$('#packageTests').addEventListener('change', updatePackageTotals);
$('#packageDiscount').addEventListener('input', updatePackageTotals);

$('#testPriceList').addEventListener('change', async (event) => {
    const row = event.target.closest('[data-test-id]');
    if (!row) return;
    await post('saveTestPrice', {
        testId: row.dataset.testId,
        price: Number(row.querySelector('.test-price').value),
        active: row.querySelector('.test-active').checked
    });
    setTimeout(loadPackageAdmin, 300);
});

$('#packageForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    const selectedTests = [...document.querySelectorAll('#packageTests input:checked')].map((input) => input.value);
    if (!selectedTests.length) { qbNotify('Select at least one test or scan.', 'error'); return; }
    await post('saveHealthPackage', {
        id: $('#packageId').value ? Number($('#packageId').value) : null,
        name: $('#packageName').value,
        description: $('#packageDescription').value,
        discount: Number($('#packageDiscount').value),
        active: $('#packageActive').checked,
        tests: selectedTests
    });
    setTimeout(loadPackageAdmin, 400);
});

$('#deletePackageBtn').addEventListener('click', async () => {
    if (!state.selectedPackage) { qbNotify('Select a custom package first.', 'error'); return; }
    if (!Number(state.selectedPackage.is_custom)) { qbNotify('Predefined packages can be hidden or edited, but not deleted.', 'error'); return; }
    await post('deleteHealthPackage', { id: Number(state.selectedPackage.id) });
    state.selectedPackage = null;
    setTimeout(loadPackageAdmin, 400);
});

$('#billingForm').addEventListener('submit', (event) => {
    event.preventDefault();
    if (!state.patient?.source) { qbNotify('Load a patient before creating a bill.', 'error'); return; }
    const amount = Math.min(Number($('#billAmount').value || 0), state.billMax);
    if (amount < 1) { qbNotify('Enter a valid billing amount.', 'error'); return; }
    post('bill', {
        target: state.patient.source,
        amount,
        notes: $('#billNotes').value
    });
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') post('close');
});
