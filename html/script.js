const containerRefs = {};
const typeToContainer = {
    door: 'tab-doors',
    window: 'tab-windows',
    seats: 'tab-seats'
};

let navLabels = {};
let statusBadgeEl;

let uiLocales = {
    header: 'CYRIL CARMENU',
    tabs: {
        doors: 'DVEŘE',
        windows: 'OKNA',
        seats: 'SEDADLA',
        status: 'STAV'
    },
    empty: {
        doors: 'Toto vozidlo zde nemá žádné ovladatelné dveře.',
        windows: 'Žádná okna pro tento model.',
        seats: 'Sedadla nebyla nalezena.'
    },
    seat_status: {
        mine: 'MÉ',
        occupied: 'OBS.',
        free: 'VOLNO'
    },
    actions: {
        shuffle: 'Přesednout'
    }
};

function mergeLocales(target = {}, source = {}) {
    const output = { ...target };
    Object.keys(source || {}).forEach((key) => {
        const value = source[key];
        if (value && typeof value === 'object' && !Array.isArray(value)) {
            output[key] = mergeLocales(output[key] || {}, value);
        } else {
            output[key] = value;
        }
    });
    return output;
}

function applyUiLocales() {
    if (statusBadgeEl) {
        statusBadgeEl.textContent = uiLocales.header || 'CYRIL CARMENU';
    }
    if (navLabels.doors) navLabels.doors.textContent = uiLocales.tabs?.doors ?? 'DVEŘE';
    if (navLabels.windows) navLabels.windows.textContent = uiLocales.tabs?.windows ?? 'OKNA';
    if (navLabels.seats) navLabels.seats.textContent = uiLocales.tabs?.seats ?? 'SEDADLA';
    if (navLabels.status) navLabels.status.textContent = uiLocales.tabs?.status ?? 'STAV';
}

document.addEventListener('DOMContentLoaded', () => {
    document.documentElement.style.setProperty('background-color', 'transparent', 'important');
    document.documentElement.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    document.body.style.setProperty('background', 'transparent', 'important');

    containerRefs[typeToContainer.door] = document.getElementById(typeToContainer.door);
    containerRefs[typeToContainer.window] = document.getElementById(typeToContainer.window);
    containerRefs[typeToContainer.seats] = document.getElementById(typeToContainer.seats);

    navLabels = {
        doors: document.querySelector('#nav-doors .nav-label'),
        windows: document.querySelector('#nav-windows .nav-label'),
        seats: document.querySelector('#nav-seats .nav-label'),
        status: document.querySelector('#nav-other .nav-label')
    };
    statusBadgeEl = document.querySelector('.status-badge');

    lucide.createIcons();
    applyUiLocales();
});

function resolveContainer(key) {
    if (!containerRefs[key]) {
        containerRefs[key] = document.getElementById(key);
    }
    return containerRefs[key];
}

function switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.getElementById('tab-' + tabId).classList.add('active');
    document.getElementById('nav-' + tabId).classList.add('active');
}

function sendAction(action, data = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function toggleElement(el, type, id) {
    const isActive = el.classList.toggle('btn-active');
    sendAction('toggle' + type.charAt(0).toUpperCase() + type.slice(1), { id: id, state: isActive });
}

function emptyMessage(type) {
    if (!uiLocales.empty) return '';
    if (type === 'door') return uiLocales.empty.doors || '';
    if (type === 'window') return uiLocales.empty.windows || '';
    return uiLocales.empty[type] || '';
}

function createEmptyState(type) {
    const empty = document.createElement('div');
    empty.className = 'empty-state';
    empty.textContent = emptyMessage(type);
    return empty;
}

function renderControlGroup(type, items) {
    const containerId = typeToContainer[type];
    if (!containerId) return;
    const container = resolveContainer(containerId);
    if (!container) return;

    container.innerHTML = '';
    if (!items || items.length === 0) {
        container.appendChild(createEmptyState(type));
        return;
    }

    items.forEach(item => {
        const btn = document.createElement('button');
        btn.className = 'control-btn';
        btn.dataset.type = type;
        btn.dataset.id = item.id;
        btn.innerHTML = `
            <i data-lucide="${item.icon}"></i>
            <span class="text-[9px] font-bold">${item.label}</span>
        `;
        btn.addEventListener('click', () => toggleElement(btn, type, item.id));
        container.appendChild(btn);
    });

    lucide.createIcons();
}

function seatStatusLabel(seat) {
    if (seat.statusLabel) return seat.statusLabel;
    if (seat.statusKey && uiLocales.seat_status?.[seat.statusKey]) {
        return uiLocales.seat_status[seat.statusKey];
    }
    return '';
}

function renderSeats(seats = []) {
    const container = resolveContainer(typeToContainer.seats);
    if (!container) return;

    container.innerHTML = '';

    if (!seats.length) {
        container.appendChild(createEmptyState('seats'));
    } else {
        seats.forEach(seat => {
            const btn = document.createElement('button');
            btn.className = 'control-btn seat-btn';
            btn.dataset.seatIndex = seat.index;
            if (seat.isMine) btn.classList.add('btn-active');
            if (seat.occupied && !seat.isMine) {
                btn.classList.add('disabled');
                btn.disabled = true;
            }
            btn.innerHTML = `
                <i data-lucide="${seat.icon || 'circle'}"></i>
                <span class="text-[9px] font-bold">${seat.label}</span>
                <span class="seat-status">${seatStatusLabel(seat)}</span>
            `;
            btn.addEventListener('click', () => {
                if (btn.disabled) return;
                sendAction('changeSeat', { id: seat.index });
            });
            container.appendChild(btn);
        });
    }

    const shuffleBtn = document.createElement('button');
    shuffleBtn.className = 'control-btn shuffle-btn';
    shuffleBtn.innerHTML = `
        <i data-lucide="refresh-cw"></i>
        <span class="text-[11px] font-bold uppercase tracking-widest">${uiLocales.actions?.shuffle || 'Přesednout'}</span>
    `;
    shuffleBtn.addEventListener('click', () => sendAction('seatShuffle'));
    container.appendChild(shuffleBtn);

    lucide.createIcons();
}

document.addEventListener('mousedown', (e) => {
    if (e.button === 2) {
        if (!e.target.closest('.menu-container')) {
            sendAction('cameraControl', { active: true });
            document.getElementById('main-container').style.opacity = '0.3';
        }
    }
});

document.addEventListener('mouseup', (e) => {
    if (e.button === 2) {
        sendAction('cameraControl', { active: false });
        document.getElementById('main-container').style.opacity = '1.0';
    }
});

document.addEventListener('contextmenu', e => e.preventDefault());

window.addEventListener('message', (event) => {
    const item = event.data;
    if (item.type === 'ui') {
        document.body.style.display = item.status ? 'flex' : 'none';
    }
    if (item.type === 'locales' && item.locales) {
        uiLocales = mergeLocales(uiLocales, item.locales);
        applyUiLocales();
    }
    if (item.type === 'layout' && item.layout) {
        renderControlGroup('door', item.layout.doors || []);
        renderControlGroup('window', item.layout.windows || []);
    }
    if (item.type === 'updateSeats') {
        renderSeats(item.seats || []);
    }
    if (item.type === 'update') {
        if (item.engine !== undefined) {
            const btn = document.getElementById('engine-btn');
            item.engine ? btn.classList.add('btn-active') : btn.classList.remove('btn-active');
        }
        if (item.locked !== undefined) {
            const btn = document.getElementById('lock-btn');
            item.locked ? btn.classList.add('btn-active') : btn.classList.remove('btn-active');
        }
    }
});

window.addEventListener('keydown', e => {
    if (e.key === 'Escape') sendAction('closeMenu');
});
