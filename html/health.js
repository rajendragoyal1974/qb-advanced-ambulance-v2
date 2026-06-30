let serviceData = { packages: [], locations: [], bookings: [] };
let reports = [];
const statusOrder = ['placed', 'awaiting_visit', 'samples_collected', 'scans_completed', 'awaiting_report', 'report_published', 'completed'];
const statusLabels = {
    placed: 'Order placed',
    awaiting_visit: 'Awaiting sample visit at the hospital',
    samples_collected: 'Samples taken',
    scans_completed: 'Samples and scans completed',
    awaiting_report: 'Waiting for report publication',
    report_published: 'Report published',
    completed: 'Package completed'
};

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character]);
}

function money(value) {
    return `$${Number(value || 0).toLocaleString()}`;
}

function renderPackages() {
    const container = document.querySelector('#packages');
    if (!serviceData.packages.length) { container.innerHTML = '<p class="empty">No packages are available.</p>'; return; }
    container.innerHTML = serviceData.packages.map((item) => `<article class="package">
        <h2>${escapeHtml(item.name)}</h2>
        <p>${escapeHtml(item.description)}</p>
        <div class="test-list">${(item.tests || []).map((test) => `<span>${escapeHtml(test.replaceAll('_', ' '))}</span>`).join('')}</div>
        <div class="package-footer"><strong>${Number(item.discount_percent) ? `<s>${money(item.original_price)}</s> ${money(item.sale_price)} (${Number(item.discount_percent)}% off)` : money(item.sale_price)}</strong><button data-package-id="${Number(item.id)}">Book now</button></div>
    </article>`).join('');
}

function trackingMarkup(booking) {
    const current = statusOrder.indexOf(booking.status);
    return statusOrder.map((status, index) => `<div class="tracking-step ${index <= current ? 'done' : ''}">${escapeHtml(statusLabels[status])}</div>`).join('');
}

function renderBookings() {
    const container = document.querySelector('#bookingList');
    if (!serviceData.bookings.length) { container.innerHTML = '<p class="empty">No health package bookings.</p>'; return; }
    container.innerHTML = serviceData.bookings.map((booking) => {
        const location = serviceData.locations.find((item) => Number(item.id) === Number(booking.location_id));
        return `<article class="booking">
        <h2>${escapeHtml(booking.package_name)}</h2>
        <div class="meta">${escapeHtml(booking.booking_ref)} &middot; ${escapeHtml(booking.location_name || 'Location pending')}</div>
        <span class="payment-badge ${booking.payment_status === 'paid' ? 'paid' : ''}">${escapeHtml(booking.payment_status)} &middot; ${escapeHtml(booking.payment_method)}</span>
        <div class="tracking">${trackingMarkup(booking)}</div>
        ${booking.status_note ? `<p class="notes">${escapeHtml(booking.status_note)}</p>` : ''}
        ${location ? `<div class="package-footer"><span class="meta">Visit service location</span><button data-route-id="${Number(location.id)}">Route</button></div>` : ''}
    </article>`;
    }).join('');
}

function renderReports() {
    const container = document.querySelector('#reports');
    document.querySelector('#reportCount').textContent = reports.length;
    if (!reports.length) { container.innerHTML = '<p class="empty">No reports have been published.</p>'; return; }
    container.innerHTML = reports.map((report) => `<article class="report">
        <h2>${escapeHtml(report.procedure_name)}</h2>
        <div class="meta">${escapeHtml(report.category)} &middot; ${escapeHtml(report.created_at)}<br>Clinician: ${escapeHtml(report.doctor_name)}</div>
        <p class="summary-text">${escapeHtml(report.summary)}</p>
        ${Object.entries(report.findings || {}).map(([name, value]) => `<div class="finding"><span>${escapeHtml(name)}</span><span>${escapeHtml(value)}</span></div>`).join('')}
        ${report.doctor_notes ? `<p class="notes">${escapeHtml(report.doctor_notes)}</p>` : ''}
    </article>`).join('');
}

function renderInvoices() {
    const container = document.querySelector('#invoiceList');
    if (!serviceData.bookings.length) { container.innerHTML = '<p class="empty">No invoices.</p>'; return; }
    container.innerHTML = serviceData.bookings.map((booking) => `<article class="invoice">
        <div class="invoice-row"><div><h2>${escapeHtml(booking.invoice_number || booking.booking_ref)}</h2><span class="meta">${escapeHtml(booking.package_name)}</span></div><strong>${money(booking.amount)}</strong></div>
        <div class="invoice-row"><span class="meta">${escapeHtml(booking.created_at)}</span><span class="payment-badge ${booking.payment_status === 'paid' ? 'paid' : ''}">${escapeHtml(booking.payment_status)}</span></div>
        <p class="meta">Payment method: ${escapeHtml(booking.payment_method)}<br>Service location: ${escapeHtml(booking.location_name || 'Not assigned')}</p>
    </article>`).join('');
}

function renderAll() {
    renderPackages();
    renderBookings();
    renderReports();
    renderInvoices();
}

async function loadData() {
    if (typeof fetchNui !== 'function') return;
    try {
        const [services, healthReports] = await Promise.all([fetchNui('patientServices', {}), fetchNui('healthRecords', {})]);
        serviceData = services || { packages: [], locations: [], bookings: [] };
        reports = Array.isArray(healthReports) ? healthReports : [];
        renderAll();
    } catch (error) {
        document.querySelector('#packages').innerHTML = '<p class="empty">Packages could not be loaded. Please reopen the app or contact EMS.</p>';
    }
}

document.querySelector('#refresh').addEventListener('click', loadData);
document.querySelectorAll('#phoneTabs button').forEach((button) => button.addEventListener('click', () => {
    document.querySelectorAll('#phoneTabs button').forEach((item) => item.classList.toggle('active', item === button));
    document.querySelectorAll('.phone-page').forEach((page) => page.classList.toggle('active', page.id === button.dataset.page));
}));

document.querySelector('#packages').addEventListener('click', (event) => {
    const button = event.target.closest('[data-package-id]');
    if (!button) return;
    const packageData = serviceData.packages.find((item) => Number(item.id) === Number(button.dataset.packageId));
    document.querySelector('#bookingPackageId').value = packageData.id;
    document.querySelector('#bookingPackageName').textContent = `${packageData.name} - ${money(packageData.sale_price)}`;
    document.querySelector('#bookingLocation').innerHTML = serviceData.locations.map((location) => `<option value="${Number(location.id)}">${escapeHtml(location.name)} (${escapeHtml(location.location_type)})</option>`).join('');
    document.querySelector('#bookingMessage').textContent = serviceData.locations.length ? '' : 'No active hospital or pharmacy location is available.';
    document.querySelector('#confirmBooking').disabled = !serviceData.locations.length;
    document.querySelector('#bookingDialog').showModal();
});

document.querySelector('#confirmBooking').addEventListener('click', async (event) => {
    event.preventDefault();
    const result = await fetchNui('createHealthBooking', {
        packageId: Number(document.querySelector('#bookingPackageId').value),
        locationId: Number(document.querySelector('#bookingLocation').value),
        paymentMethod: document.querySelector('#bookingPayment').value
    });
    if (!result?.ok) { document.querySelector('#bookingMessage').textContent = result?.error || 'Booking failed.'; return; }
    document.querySelector('#bookingDialog').close();
    await loadData();
    document.querySelector('[data-page="bookings"]').click();
});

document.querySelector('#bookingList').addEventListener('click', (event) => {
    const button = event.target.closest('[data-route-id]');
    if (!button) return;
    const location = serviceData.locations.find((item) => Number(item.id) === Number(button.dataset.routeId));
    if (location) fetchNui('serviceWaypoint', { x: location.x, y: location.y });
});

if (typeof onNuiEvent === 'function') onNuiEvent('services', (payload) => { serviceData = payload.data || serviceData; renderAll(); });
if (typeof onNuiEvent === 'function') onNuiEvent('reports', (payload) => { reports = payload.reports || []; renderReports(); });
loadData();
