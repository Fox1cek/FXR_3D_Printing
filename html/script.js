let currentPrinterId = null;
let localPrinterData = {};
let localRecipes = {};
let localShopBlueprints = [];
let localOwnedBlueprints = {};
let localLocales = {};
let selectedRefillItem = null;
let currentCategoryFilter = 'all';
let currentView = 'catalog';
let timerInterval = null;

function getLocText(key, fallback) {
    if (localLocales && localLocales[key]) {
        return localLocales[key];
    }
    return fallback || key;
}

window.addEventListener('message', function(event) {
    const item = event.data;

    if (!item) return;

    if (item.action === 'openPrinter' || !item.action) {
        currentPrinterId = item.printerId || 1;
        localPrinterData = item.data || {};
        localRecipes = item.recipes || {};
        localShopBlueprints = item.shopBlueprints || [];
        localOwnedBlueprints = item.ownedBlueprints || {};
        localLocales = item.locales || {};

        const appEl = document.getElementById('app');
        if (appEl) {
            appEl.classList.remove('hidden');
            appEl.style.display = 'flex';
        }

        applyLocales();

        if (item.initialView === 'darkweb') {
            switchView('darkweb', document.querySelector('.darkweb-tab'));
        } else {
            switchView('catalog', document.querySelector('.tab-btn'));
        }

        renderUI();
        startTimer();
    } else if (item.action === 'syncPrinter') {
        if (item.printerId === currentPrinterId) {
            localPrinterData = item.data || {};
            renderUI();
        }
    } else if (item.action === 'closePrinter') {
        closeApp();
    }
});

function applyLocales() {
    document.getElementById('uiTitle').innerText = getLocText('printer_title', '3D PRINTER');
    document.getElementById('txtStorage').innerText = getLocText('storage', 'STORAGE');
    document.getElementById('txtPlastic').innerText = getLocText('plastic_label', 'Plastic Filament');
    document.getElementById('txtMetal').innerText = getLocText('metal_label', 'Metal Filament');
    document.getElementById('txtBattery').innerText = getLocText('battery_label', 'Battery');
    document.getElementById('txtDurability').innerText = getLocText('durability', 'Condition');
    document.getElementById('txtRepair').innerText = getLocText('repair', 'Repair');
    document.getElementById('txtActivePrint').innerText = getLocText('active_print', 'PRINTING');
    document.getElementById('txtIdle').innerText = getLocText('idle', 'Printer Idle');
    document.getElementById('txtPickup').innerText = getLocText('pickup', 'Collect');
    document.getElementById('txtCancel').innerText = getLocText('cancel', 'Cancel');
    document.getElementById('txtExtract').innerText = getLocText('extract', 'Extract');
    document.getElementById('txtPack').innerText = getLocText('pack', 'Pack');
    document.getElementById('tabAll').innerText = getLocText('all', 'All');
    document.getElementById('tabTools').innerText = getLocText('tools', 'Tools');
    document.getElementById('tabAttachments').innerText = getLocText('attachments', 'Attachments');
    document.getElementById('tabWeapons').innerText = getLocText('weapons', 'Weapons');
    document.getElementById('tabDarkweb').innerText = getLocText('darkweb_cad', 'CAD Store');
    document.getElementById('btnCancelModal').innerText = getLocText('cancel', 'Cancel');
    document.getElementById('btnConfirmModal').innerText = getLocText('confirm', 'Confirm');
}

function closeApp() {
    const appEl = document.getElementById('app');
    if (appEl) {
        appEl.classList.add('hidden');
        appEl.style.display = 'none';
    }
    if (timerInterval) clearInterval(timerInterval);

    try {
        const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
        fetch(`https://${resourceName}/closeUI`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    } catch (e) {
        console.error("Failed to post closeUI:", e);
    }
}

document.getElementById('closeBtn').addEventListener('click', closeApp);

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeApp();
    }
});

function renderUI() {
    renderMaterials();
    renderActiveJob();
    if (currentView === 'darkweb') {
        renderDarkWebStore();
    } else {
        renderRecipesGrid();
    }
}

function renderMaterials() {
    const mats = localPrinterData.materials || {};
    const pCount = mats.plastic_filament || 0;
    const mCount = mats.metal_filament || 0;
    const bCount = mats.printer_battery || 0;

    document.getElementById('plasticVal').innerText = `${pCount} / 200`;
    document.getElementById('plasticBar').style.width = `${Math.min(100, (pCount / 200) * 100)}%`;

    document.getElementById('metalVal').innerText = `${mCount} / 200`;
    document.getElementById('metalBar').style.width = `${Math.min(100, (mCount / 200) * 100)}%`;

    document.getElementById('chipVal').innerText = `${bCount} / 20`;
    document.getElementById('chipBar').style.width = `${Math.min(100, (bCount / 20) * 100)}%`;

    const dura = typeof localPrinterData.durability === 'number' ? localPrinterData.durability : 100;
    const duraValEl = document.getElementById('durabilityVal');
    const duraBarEl = document.getElementById('durabilityBar');
    const duraIconEl = document.getElementById('durabilityIcon');

    if (duraValEl) duraValEl.innerText = `${dura}%`;
    if (duraBarEl) {
        duraBarEl.style.width = `${Math.max(0, Math.min(100, dura))}%`;
        if (dura > 50) {
            duraBarEl.className = 'progress-fill green-fill';
            if (duraIconEl) duraIconEl.className = 'fa-solid fa-screwdriver-wrench green-text';
        } else if (dura > 20) {
            duraBarEl.className = 'progress-fill amber-fill';
            if (duraIconEl) duraIconEl.className = 'fa-solid fa-screwdriver-wrench amber-text';
        } else {
            duraBarEl.className = 'progress-fill red-fill';
            if (duraIconEl) duraIconEl.className = 'fa-solid fa-triangle-exclamation red-text glow-pulse';
        }
    }
}

function renderActiveJob() {
    const statusBadge = document.getElementById('statusBadge');
    const statusText = document.getElementById('statusText');
    const noJobView = document.getElementById('noJobView');
    const activeJobView = document.getElementById('activeJobView');
    const pickupBtn = document.getElementById('pickupBtn');
    const cancelBtn = document.getElementById('cancelBtn');

    if (localPrinterData.finished_item) {
        statusBadge.className = 'status-badge status-ready';
        statusText.innerText = getLocText('status_ready', 'FINISHED');

        noJobView.classList.add('hidden');
        activeJobView.classList.remove('hidden');

        const recipe = localRecipes[localPrinterData.finished_item] || {};
        document.getElementById('jobItemName').innerText = recipe.label || localPrinterData.finished_item;
        document.getElementById('jobTimeLeft').innerText = getLocText('status_done', 'DONE');
        document.getElementById('mainProgressBar').style.width = '100%';

        pickupBtn.classList.remove('hidden');
        cancelBtn.classList.add('hidden');
    } else if (localPrinterData.current_print) {
        statusBadge.className = 'status-badge status-printing';
        statusText.innerText = getLocText('status_printing', 'PRINTING...');

        noJobView.classList.add('hidden');
        activeJobView.classList.remove('hidden');

        const recipe = localRecipes[localPrinterData.current_print] || {};
        document.getElementById('jobItemName').innerText = recipe.label || localPrinterData.current_print;

        pickupBtn.classList.add('hidden');
        cancelBtn.classList.remove('hidden');

        updateProgressTimer();
    } else {
        statusBadge.className = 'status-badge status-idle';
        statusText.innerText = getLocText('status_ready_print', 'READY');

        noJobView.classList.remove('hidden');
        activeJobView.classList.add('hidden');
    }
}

function formatTimeSeconds(totalSecs) {
    if (!totalSecs || totalSecs <= 0) return '0s';
    const days = Math.floor(totalSecs / 86400);
    const hours = Math.floor((totalSecs % 86400) / 3600);
    const mins = Math.floor((totalSecs % 3600) / 60);
    const secs = totalSecs % 60;

    if (days > 0) {
        return `${days}d ${hours}h`;
    } else if (hours > 0) {
        return `${hours}h ${mins}m`;
    } else if (mins > 0) {
        return `${mins}m ${secs > 0 ? secs + 's' : ''}`;
    }
    return `${secs}s`;
}

function formatRemainingTime(remaining) {
    if (remaining <= 0) return getLocText('completing', 'COMPLETING...');
    const days = Math.floor(remaining / 86400);
    const hours = Math.floor((remaining % 86400) / 3600);
    const mins = Math.floor((remaining % 3600) / 60);
    const secs = remaining % 60;

    if (days > 0) {
        return `${days}d ${hours < 10 ? '0' : ''}${hours}h ${mins < 10 ? '0' : ''}${mins}m`;
    } else if (hours > 0) {
        return `${hours < 10 ? '0' : ''}${hours}h ${mins < 10 ? '0' : ''}${mins}m ${secs < 10 ? '0' : ''}${secs}s`;
    }
    return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`;
}

function updateProgressTimer() {
    if (!localPrinterData.current_print || !localPrinterData.finish_time) return;

    const now = Math.floor(Date.now() / 1000);
    const finishTime = localPrinterData.finish_time;
    const recipe = localRecipes[localPrinterData.current_print] || {};
    const totalDuration = recipe.printTime || 60;

    const remaining = Math.max(0, finishTime - now);
    const elapsed = totalDuration - remaining;
    const pct = Math.min(100, Math.max(0, (elapsed / totalDuration) * 100));

    document.getElementById('mainProgressBar').style.width = `${pct}%`;
    document.getElementById('jobTimeLeft').innerText = formatRemainingTime(remaining);
}

function startTimer() {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = setInterval(() => {
        if (localPrinterData.current_print) {
            updateProgressTimer();
        }
    }, 1000);
}

function switchView(view, btn) {
    currentView = view;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');

    const grid = document.getElementById('recipesGrid');
    const store = document.getElementById('darkwebPanel');

    if (view === 'darkweb') {
        grid.classList.add('hidden');
        store.classList.remove('hidden');
        renderDarkWebStore();
    } else {
        store.classList.add('hidden');
        grid.classList.remove('hidden');
        renderRecipesGrid();
    }
}

function renderRecipesGrid() {
    const grid = document.getElementById('recipesGrid');
    if (!grid) return;

    grid.innerHTML = '';
    const mats = localPrinterData.materials || {};

    for (const [key, recipe] of Object.entries(localRecipes)) {
        if (currentCategoryFilter !== 'all' && recipe.category !== currentCategoryFilter) {
            continue;
        }

        let canAfford = true;
        let reqsHTML = '';

        for (const [matKey, count] of Object.entries(recipe.materials || {})) {
            const hasAmount = mats[matKey] || 0;
            const isEnough = hasAmount >= count;
            if (!isEnough) canAfford = false;

            const matName = matKey === 'plastic_filament' ? getLocText('plastic_short', 'Plastic') : (matKey === 'metal_filament' ? getLocText('metal_short', 'Metal') : (matKey === 'printer_battery' ? getLocText('battery_short', 'Battery') : matKey));
            reqsHTML += `<span class="req-badge ${isEnough ? 'has-enough' : 'missing'}">${matName}: ${hasAmount}/${count}</span>`;
        }

        let hasBlueprint = true;
        if (recipe.blueprint) {
            hasBlueprint = !!localOwnedBlueprints[recipe.blueprint];
            if (!hasBlueprint) canAfford = false;
        }

        const bpBadgeHTML = recipe.blueprint 
            ? `<span class="req-badge ${hasBlueprint ? 'has-enough' : 'missing'}">${hasBlueprint ? '✔ CAD' : '🔒 CAD'}</span>`
            : '';

        const card = document.createElement('div');
        card.className = 'recipe-card';
        card.innerHTML = `
            <div class="recipe-header">
                <span class="recipe-title">${recipe.label}</span>
                <span class="recipe-time-badge"><i class="fa-regular fa-clock"></i> ${formatTimeSeconds(recipe.printTime)}</span>
            </div>
            <div class="recipe-reqs">
                ${reqsHTML}
                ${bpBadgeHTML}
            </div>
            ${hasBlueprint ? `
                <button class="btn btn-primary w-full" ${canAfford ? '' : 'disabled style="opacity:0.5; cursor:not-allowed;"'} onclick="startPrint('${key}')">
                    <i class="fa-solid fa-play"></i> ${getLocText('start_print', 'Print')}
                </button>
            ` : `
                <button class="btn btn-secondary w-full" style="border-color: rgba(235, 87, 87, 0.4); color: #eb5757;" onclick="switchView('darkweb', document.querySelector('.darkweb-tab'))">
                    <i class="fa-solid fa-lock"></i> ${getLocText('buy_cad', 'Get CAD')}
                </button>
            `}
        `;

        grid.appendChild(card);
    }
}

function filterCategory(cat, btn) {
    currentCategoryFilter = cat;
    currentView = 'catalog';
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');

    document.getElementById('darkwebPanel').classList.add('hidden');
    document.getElementById('recipesGrid').classList.remove('hidden');

    renderRecipesGrid();
}

function renderDarkWebStore() {
    const storePanel = document.getElementById('darkwebPanel');
    if (!storePanel) return;

    storePanel.innerHTML = '';

    for (const bp of localShopBlueprints) {
        const isOwned = !!localOwnedBlueprints[bp.item];

        const card = document.createElement('div');
        card.className = 'darkweb-card';
        card.innerHTML = `
            <div class="darkweb-card-header">
                <div class="darkweb-title">
                    <i class="fa-solid fa-file-code cyan-text"></i>
                    <span>${bp.label}</span>
                </div>
                <span class="price-badge">$${bp.price.toLocaleString()}</span>
            </div>
            <p class="darkweb-desc">${bp.description || 'CAD'}</p>
            <div class="darkweb-footer">
                ${isOwned ? `
                    <button class="btn btn-success w-full" disabled style="opacity: 0.9; cursor: default;">
                        <i class="fa-solid fa-check"></i> ${getLocText('owned', 'Owned')}
                    </button>
                ` : `
                    <button class="btn btn-primary w-full" onclick="downloadBlueprint('${bp.item}', this)">
                        <i class="fa-solid fa-download"></i> $${bp.price}
                    </button>
                `}
            </div>
        `;

        storePanel.appendChild(card);
    }
}

function downloadBlueprint(itemKey, btn) {
    if (btn) {
        btn.disabled = true;
    }

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/buyBlueprint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemKey: itemKey })
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            localOwnedBlueprints[itemKey] = true;
            if (data.owned) localOwnedBlueprints = data.owned;
            renderDarkWebStore();
        } else {
            if (btn) {
                btn.disabled = false;
            }
        }
    })
    .catch(err => {
        console.error("Failed to download blueprint:", err);
        if (btn) {
            btn.disabled = false;
        }
    });
}

function openRefillModal(matItem, matLabel) {
    selectedRefillItem = matItem;
    document.getElementById('modalTitle').innerText = matLabel;
    document.getElementById('refillAmount').value = matItem === 'printer_battery' ? 1 : 10;
    document.getElementById('refillModal').classList.remove('hidden');
}

function closeRefillModal() {
    document.getElementById('refillModal').classList.add('hidden');
}

function confirmRefill() {
    const amount = parseInt(document.getElementById('refillAmount').value) || 0;
    if (amount <= 0 || !selectedRefillItem) return;

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/addMaterial`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId,
            item: selectedRefillItem,
            amount: amount
        })
    });

    closeRefillModal();
}

function startPrint(recipeKey) {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/startPrint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId,
            recipeKey: recipeKey
        })
    });
}

function pickupPrint() {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/pickupPrint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId
        })
    });
}

function cancelPrint() {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/cancelPrint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId
        })
    });
}

function packPrinter() {
    closeApp();
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/packPrinter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId
        })
    });
}

function extractMaterials() {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/extractMaterials`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId
        })
    });
}

function repairPrinter() {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_3dprinter';
    fetch(`https://${resourceName}/repairPrinter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            printerId: currentPrinterId
        })
    });
}
