'use strict';

// ── State ───────────────────────────────────────────────────
let currentVehiclePlate = null;   // GTA native plate of the vehicle player is in
let myPlates            = [];
let activeTier          = null;   // tier being purchased right now
let tier3Prices         = {};     // length → price, sent from Lua config

// ── Lua → NUI messages ──────────────────────────────────────
window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'open':
      openUI(data.vehiclePlate, data.tier3Prices || {});
      break;
    case 'showPlates':
      renderPlates(data.plates || []);
      break;
    case 'notify':
      toast(data.msg, data.ntype || 'info');
      break;
    case 'purchaseSuccess':
      toast('Plate ' + data.plate + ' purchased!', 'success');
      nuiFetch('getPlates', {});
      showTab('myplates');
      break;
  }
});

// ── Open / close ────────────────────────────────────────────
let isOpen = false;

function openUI(vehiclePlate, prices) {
  tier3Prices = prices;
  currentVehiclePlate = vehiclePlate || null;

  document.getElementById('barPlate').textContent =
    currentVehiclePlate || '— not in vehicle —';

  document.getElementById('app').classList.remove('hidden');
  isOpen = true;
  showTab('myplates');
  nuiFetch('getPlates', {});
}

function closeUI() {
  if (!isOpen) return;   // prevent double-fire / loop
  isOpen = false;
  document.getElementById('app').classList.add('hidden');
  document.getElementById('purchaseModal').classList.add('hidden');
  nuiFetch('closeUI', {});  // tells Lua to release SetNuiFocus
}

document.getElementById('closeBtn').addEventListener('click', closeUI);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeUI(); });

// ── Tabs ────────────────────────────────────────────────────
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => showTab(btn.dataset.tab));
});

function showTab(name) {
  document.querySelectorAll('.tab-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === name));
  document.querySelectorAll('.tab-pane').forEach(p =>
    p.classList.toggle('active', p.id === 'tab-' + name));
}

// ── Render My Plates ─────────────────────────────────────────
function renderPlates(plates) {
  myPlates = plates;
  const list  = document.getElementById('plates-list');
  const empty = document.getElementById('platesEmpty');
  list.innerHTML = '';

  if (!plates.length) { empty.style.display = ''; return; }
  empty.style.display = 'none';

  plates.forEach(p => {
    const isAssigned = p.assigned_vehicle && p.assigned_vehicle !== 'UNASSIGNED';
    const isOnCurrent = isAssigned && currentVehiclePlate &&
      p.assigned_vehicle.toUpperCase() === currentVehiclePlate.toUpperCase();

    const card = document.createElement('div');
    card.className = 'plate-card';
    card.innerHTML = `
      <div class="plate-demo white">${escHtml(p.mu_plate)}</div>
      <div class="plate-card-left">
        <div class="plate-card-tag">${tierLabel(p.plate_type)}</div>
        <div class="plate-card-assigned ${isAssigned ? 'active-assign' : ''}">
          ${isAssigned
            ? (isOnCurrent ? '✔ On this vehicle' : 'Assigned to: ' + p.assigned_vehicle)
            : 'Unassigned'}
        </div>
      </div>
      <div class="plate-card-actions">
        <button class="btn btn-apply" data-plate="${escHtml(p.mu_plate)}">
          ${isOnCurrent ? 'Remove' : 'Apply'}
        </button>
        <button class="btn btn-sell" data-plate="${escHtml(p.mu_plate)}"
                data-price="${p.purchased_price}">
          Sell (50%)
        </button>
      </div>`;
    list.appendChild(card);
  });

  // Apply button
  list.querySelectorAll('.btn-apply').forEach(btn => {
    btn.addEventListener('click', () => {
      if (!currentVehiclePlate) { toast('You must be in a vehicle.', 'error'); return; }
      nuiFetch('applyPlate', { muPlate: btn.dataset.plate, vehiclePlate: currentVehiclePlate });
    });
  });

  // Sell button
  list.querySelectorAll('.btn-sell').forEach(btn => {
    btn.addEventListener('click', () => {
      const refund = Math.floor(Number(btn.dataset.price) * 0.5);
      if (!confirm(`Sell plate "${btn.dataset.plate}"?\nRefund: $${refund.toLocaleString()}`)) return;
      nuiFetch('sellPlate', { muPlate: btn.dataset.plate });
    });
  });
}

function tierLabel(t) {
  return { tier1: 'Tier 1 — AA 0000', tier2: 'Tier 2 — AAA 0000', tier3: 'Tier 3 — Name' }[t] || t;
}

// ── Purchase flow ────────────────────────────────────────────
document.querySelectorAll('.btn-buy').forEach(btn => {
  btn.addEventListener('click', () => openPurchaseModal(
    btn.dataset.tier,
    Number(btn.dataset.price),
    btn.dataset.hint,
    btn.dataset.placeholder
  ));
});

function openPurchaseModal(tier, basePrice, hint, placeholder) {
  activeTier = tier;

  document.getElementById('modalTitle').textContent =
    { tier1: 'Tier 1 — AA 0000', tier2: 'Tier 2 — AAA 0000', tier3: 'Tier 3 — Name / Word' }[tier];
  document.getElementById('modalHint').textContent = hint;

  const input = document.getElementById('plateInput');
  input.value = '';
  input.placeholder = placeholder;
  input.focus();

  document.getElementById('platePreview').textContent = '——';
  document.getElementById('modalPriceLine').textContent = '';
  document.getElementById('purchaseModal').classList.remove('hidden');
}

// Live preview
document.getElementById('plateInput').addEventListener('input', function () {
  const val = this.value.toUpperCase();
  this.value = val;
  document.getElementById('platePreview').textContent = val || '——';

  if (activeTier === 'tier3') {
    const price = tier3Prices[val.replace(/\s/g,'').length];
    document.getElementById('modalPriceLine').textContent =
      price ? `Price: $${Number(price).toLocaleString()}` : '';
  }
});

document.getElementById('modalCancel').addEventListener('click', () => {
  document.getElementById('purchaseModal').classList.add('hidden');
});

document.getElementById('modalConfirm').addEventListener('click', () => {
  const plate = document.getElementById('plateInput').value.trim().toUpperCase();
  if (!plate) { toast('Enter a plate.', 'error'); return; }
  nuiFetch('purchasePlate', { tier: activeTier, plate });
  document.getElementById('purchaseModal').classList.add('hidden');
});

// Close modal on overlay click
document.getElementById('purchaseModal').addEventListener('click', function (e) {
  if (e.target === this) this.classList.add('hidden');
});

// ── Toast notification ───────────────────────────────────────
let toastTimer;
function toast(msg, type = 'info') {
  let el = document.getElementById('toast');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toast';
    document.body.appendChild(el);
  }
  el.textContent   = msg;
  el.className     = 'show ' + type;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.className = ''; }, 3000);
}

// ── NUI → Lua fetch ──────────────────────────────────────────
function nuiFetch(endpoint, data) {
  return fetch(`https://mu-licenseplate/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

// ── Helpers ──────────────────────────────────────────────────
function escHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
