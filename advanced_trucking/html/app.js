const tablet = document.getElementById('tablet');
const tabs = document.querySelectorAll('.tab');
const panels = document.querySelectorAll('.panel');
const contractGrid = document.getElementById('contractGrid');
const activeJobBox = document.getElementById('activeJob');
const telemetry = document.getElementById('telemetry');
const historyList = document.getElementById('historyList');
const companyGrid = document.getElementById('companyGrid');
const upgradeGrid = document.getElementById('upgradeGrid');
const licenseGrid = document.getElementById('licenseGrid');
const truckMarket = document.getElementById('truckMarket');

let state = {
    profile: null,
    contracts: [],
    companyData: null,
    logs: [],
    activeJob: null
};

const licenses = {
    hazmat: { label: 'Hazmat License', level: 5, price: 18000 },
    oversized: { label: 'Oversized Load License', level: 4, price: 14000 },
    cold_chain: { label: 'Cold Chain Certification', level: 3, price: 9000 }
};

const trucks = {
    starter: { label: 'Old Hauler', price: 35000 },
    highway: { label: 'Highway Sleeper', price: 72000 },
    heavy: { label: 'Heavy Puller', price: 125000 }
};

const upgrades = {
    bay_2: { label: 'Second Service Bay', price: 55000 },
    dispatch: { label: 'Dispatch Office', price: 85000 },
    cold_storage: { label: 'Cold Storage Dock', price: 70000 },
    hazmat_yard: { label: 'Hazmat Yard', price: 120000 }
};

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function money(value) {
    return `$${Number(value || 0).toLocaleString()}`;
}

function miles(meters) {
    return `${Math.max(1, Math.round((meters || 0) / 1609.34))} mi`;
}

function ownedLicense(key) {
    const list = state.profile?.licenses || [];
    return list.includes(key);
}

function card(title, tag, body, button) {
    return `
        <article class="card">
            <header>
                <h3>${title}</h3>
                ${tag || ''}
            </header>
            ${body}
            ${button || ''}
        </article>
    `;
}

function renderProfile() {
    const profile = state.profile || {};
    document.getElementById('driverLine').textContent = `${profile.name || 'Driver'} | ${profile.completed || 0} completed | ${profile.failed || 0} failed`;
    document.getElementById('level').textContent = profile.level || 1;
    document.getElementById('xp').textContent = profile.xp || 0;
    document.getElementById('rep').textContent = profile.reputation || 0;
}

function renderActiveJob() {
    const job = state.activeJob;
    if (!job) {
        activeJobBox.className = 'activeJob muted';
        activeJobBox.textContent = 'No active delivery';
        return;
    }
    activeJobBox.className = 'activeJob';
    activeJobBox.innerHTML = `
        <strong>${job.cargo}</strong> from ${job.originLabel} to ${job.destinationLabel}
        <div class="meta">
            <span><strong>${job.requiredTrailerLabel}</strong> Required trailer</span>
            <span><strong>${miles(job.distance)}</strong> Route distance</span>
            <span><strong>${money(job.estimatedPay)}</strong> Estimated pay</span>
            <span><strong>${job.illegal ? 'Discreet' : 'Filed'}</strong> Documents</span>
        </div>
    `;
}

function renderContracts() {
    if (!state.contracts.length) {
        contractGrid.innerHTML = '<div class="activeJob muted">No contracts available for your current level, licenses, or reputation.</div>';
        return;
    }
    contractGrid.innerHTML = state.contracts.map(job => {
        const tagClass = job.illegal ? 'risk' : 'good';
        const tagText = job.illegal ? 'Risk RP' : 'Legal';
        return card(
            job.tier,
            `<span class="tag ${tagClass}">${tagText}</span>`,
            `<div class="meta">
                <span><strong>${job.cargo}</strong>Cargo</span>
                <span><strong>${job.requiredTrailerLabel}</strong>Trailer</span>
                <span><strong>${miles(job.distance)}</strong>Distance</span>
                <span><strong>${money(job.estimatedPay)}</strong>Pay</span>
                <span><strong>${Math.round(job.weight || 0).toLocaleString()} lb</strong>Weight</span>
                <span><strong>${job.fragile ? 'Yes' : 'No'}</strong>Fragile</span>
            </div>
            <p class="muted">${job.originLabel} to ${job.destinationLabel}</p>`,
            `<button class="primary" data-start="${job.id}">Accept Contract</button>`
        );
    }).join('');
}

function gauge(label, value, max = 100) {
    const pct = Math.max(0, Math.min(100, Math.round((Number(value || 0) / max) * 100)));
    const cls = pct < 30 ? 'bad' : pct < 55 ? 'warn' : '';
    return `
        <div class="gauge">
            <span>${label}: ${pct}%</span>
            <div class="bar ${cls}"><i style="width:${pct}%"></i></div>
        </div>
    `;
}

function renderTelemetry() {
    const job = state.activeJob;
    if (!job) {
        telemetry.innerHTML = '<div class="muted">No rig assigned. Accept a contract to view condition data.</div>';
        return;
    }
    const condition = job.condition || {};
    telemetry.innerHTML = [
        gauge('Engine Health', condition.engine || 1000, 1000),
        gauge('Fuel Level', condition.fuel || 0, 340),
        gauge('Tire Wear', condition.tires || 0),
        gauge('Brake Wear', condition.brakes || 0),
        gauge('Oil Life', condition.oil || 0),
        `<div class="gauge"><span>Cargo</span><strong>${job.cargo}</strong><p class="muted">${job.requiredTrailerLabel}</p></div>`
    ].join('');
}

function renderCompany() {
    const profile = state.profile || {};
    const company = state.companyData || {};
    companyGrid.innerHTML = [
        card('Company Reputation', '<span class="tag good">Dispatch</span>', `<div class="meta"><span><strong>${company.reputation ?? profile.reputation ?? 0}</strong>Reputation</span><span><strong>${company.garage_level || 1}</strong>Garage level</span><span><strong>${company.driver_slots || 0}</strong>Driver slots</span><span><strong>${company.contract_slots || 1}</strong>Contract slots</span></div>`),
        card('Fleet Earnings', '<span class="tag">Ledger</span>', `<div class="meta"><span><strong>${money(profile.stats?.earned)}</strong>Earned</span><span><strong>${profile.stats?.mileage || 0}</strong>Miles</span><span><strong>${profile.stats?.fuel_used || 0}</strong>Fuel used</span><span><strong>${money(profile.stats?.damage_paid)}</strong>Repairs</span></div>`)
    ].join('');

    upgradeGrid.innerHTML = Object.entries(upgrades).map(([key, upgrade]) => {
        return card(upgrade.label, '<span class="tag">Upgrade</span>', `<p class="muted">${money(upgrade.price)}</p>`, `<button data-upgrade="${key}">Buy Upgrade</button>`);
    }).join('');
}

function renderLicenses() {
    licenseGrid.innerHTML = Object.entries(licenses).map(([key, license]) => {
        const owned = ownedLicense(key);
        return card(
            license.label,
            `<span class="tag ${owned ? 'good' : ''}">${owned ? 'Owned' : `Level ${license.level}`}</span>`,
            `<p class="muted">${money(license.price)}</p>`,
            owned ? '' : `<button data-license="${key}">Buy License</button>`
        );
    }).join('');

    truckMarket.innerHTML = Object.entries(trucks).map(([key, truck]) => {
        return card(truck.label, '<span class="tag">Truck</span>', `<p class="muted">${money(truck.price)}</p>`, `<button data-truck="${key}">Buy Truck</button>`);
    }).join('');
}

function renderHistory() {
    if (!state.logs.length) {
        historyList.innerHTML = '<div class="activeJob muted">No delivery history yet.</div>';
        return;
    }
    historyList.innerHTML = state.logs.map(log => `
        <div class="historyItem">
            <div>
                <strong>${log.message || log.event_type}</strong>
                <p class="muted">${log.created_at || ''}</p>
            </div>
            <strong>${money(log.amount)}</strong>
        </div>
    `).join('');
}

function renderAll() {
    renderProfile();
    renderActiveJob();
    renderContracts();
    renderTelemetry();
    renderCompany();
    renderLicenses();
    renderHistory();
}

tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        tabs.forEach(item => item.classList.remove('active'));
        panels.forEach(panel => panel.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(tab.dataset.tab).classList.add('active');
    });
});

document.addEventListener('click', event => {
    const start = event.target.closest('[data-start]');
    const license = event.target.closest('[data-license]');
    const truck = event.target.closest('[data-truck]');
    const upgrade = event.target.closest('[data-upgrade]');

    if (start) post('startJob', { jobId: start.dataset.start });
    if (license) post('buyLicense', { license: license.dataset.license });
    if (truck) post('buyTruck', { truck: truck.dataset.truck });
    if (upgrade) post('upgradeGarage', { upgrade: upgrade.dataset.upgrade });
});

document.getElementById('closeBtn').addEventListener('click', () => post('close'));
document.getElementById('refreshBtn').addEventListener('click', () => post('requestDashboard'));
document.getElementById('cancelJobBtn').addEventListener('click', () => post('cancelJob'));
document.getElementById('hireBtn').addEventListener('click', () => post('hireDriver', { driverName: `NPC Driver ${Math.floor(Math.random() * 900 + 100)}` }));

window.addEventListener('keydown', event => {
    if (event.key === 'Escape') post('close');
});

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'open') {
        tablet.classList.remove('hidden');
        state.profile = data.profile || state.profile;
        state.activeJob = data.activeJob || state.activeJob;
        renderAll();
    }
    if (data.action === 'close') {
        tablet.classList.add('hidden');
    }
    if (data.action === 'dashboard') {
        document.getElementById('companyName').textContent = data.company || 'Corner Life RP Trucking & Logistics';
        state.profile = data.profile || state.profile;
        state.contracts = data.contracts || [];
        state.companyData = data.companyData || null;
        state.logs = data.logs || [];
        state.activeJob = data.activeJob ?? state.activeJob;
        renderAll();
    }
    if (data.action === 'jobUpdated') {
        state.activeJob = data.activeJob || null;
        renderActiveJob();
        renderTelemetry();
    }
});
