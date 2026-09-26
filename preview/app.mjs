/**
 * Windows / browser development preview only.
 * Shares treatment IDs, look JSON, masks, and blend math with MakeupCore;
 * does not share RealityKit rendering code. Duo postures use published device
 * geometry from duo.mjs as a layout proposal for the app teammate.
 */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import {
  treatments, emptyLook, validateLook, setMakeup, clearTreatment,
  colorFromHex, colorToHex,
} from './look.mjs';
import { POSTURES, postureById, screenFor, fitScale, screenReadout, BEZEL_CSS_PX, HINGE_BAND_CSS_PX } from './duo.mjs';

const STORAGE_KEY = 'makeup-face-latest-look';
const ASSETS = '/assets';
const SWATCHES = [
  ['Rose', '#bc395b'], ['Berry', '#6e143a'], ['Coral', '#f25c38'], ['Plum', '#61296e'],
  ['Cocoa', '#573324'], ['Sand', '#c79463'], ['Pearl', '#ffebc7'], ['Ink', '#0f0a0f'],
];

const els = {
  posture: document.getElementById('posture'),
  scale: document.getElementById('scale'),
  readout: document.getElementById('readout'),
  postureDetail: document.getElementById('posture-detail'),
  deviceScale: document.getElementById('deviceScale'),
  device: document.getElementById('device'),
  screen: document.getElementById('screen'),
  viewport: document.getElementById('viewport'),
  front: document.getElementById('front'),
  before: document.getElementById('before'),
  status: document.getElementById('status'),
  controls: document.getElementById('controls'),
  treatment: document.getElementById('treatment'),
  color: document.getElementById('color'),
  hex: document.getElementById('hex'),
  swatches: document.getElementById('swatches'),
  intensity: document.getElementById('intensity'),
  amount: document.getElementById('amount'),
  treatmentState: document.getElementById('treatment-state'),
  clear: document.getElementById('clear'),
  reset: document.getElementById('reset'),
};

const state = {
  look: emptyLook(),
  selected: 'lipstick',
  yaw: 0,
  pitch: 0,
  showsOriginal: false,
  ready: false,
  busy: false,
  persistenceWarning: null,
  width: 0,
  height: 0,
  postureId: 'open',
};

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xe4dcd7);
const camera = new THREE.PerspectiveCamera(35, 1, 0.05, 40);
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
els.viewport.appendChild(renderer.domElement);

const pivot = new THREE.Group();
scene.add(pivot);
scene.add(new THREE.AmbientLight(0xffffff, 0.55));
const key = new THREE.DirectionalLight(0xfff4ea, 1.15);
key.position.set(0.4, 1.2, 2.2);
scene.add(key);
const fill = new THREE.DirectionalLight(0xd8e4ff, 0.35);
fill.position.set(-1.2, 0.4, 1);
scene.add(fill);

const materials = [];
let originalMap = null;
let editedMap = null;
let worker = null;
let composeToken = 0;
const pendingCompose = new Map();

function setStatus(message, { failed = false } = {}) {
  els.status.textContent = message;
  els.status.dataset.state = failed ? 'failed' : 'ok';
}

function clampOrientation() {
  state.yaw = Math.min(Math.PI / 3, Math.max(-Math.PI / 3, state.yaw));
  state.pitch = Math.min(Math.PI / 12, Math.max(-Math.PI / 12, state.pitch));
  pivot.rotation.set(state.pitch, state.yaw, 0, 'YXZ');
}

function applyDeviceLayout() {
  const posture = postureById(state.postureId);
  const screen = screenFor(posture);
  els.device.dataset.posture = posture.id;
  els.postureDetail.textContent = posture.detail;
  document.documentElement.style.setProperty('--screen-w', `${screen.widthPx}px`);
  document.documentElement.style.setProperty('--screen-h', `${screen.heightPx}px`);
  document.documentElement.style.setProperty('--hinge', `${HINGE_BAND_CSS_PX}px`);
  document.documentElement.style.setProperty('--bezel', `${BEZEL_CSS_PX}px`);

  const available = {
    width: els.deviceScale.parentElement?.clientWidth || window.innerWidth - 48,
    height: Math.max(420, window.innerHeight - 180),
  };
  let scale;
  if (els.scale.value === 'fit') scale = fitScale(posture, available);
  else scale = Number(els.scale.value) || 1;
  document.documentElement.style.setProperty('--scale', String(scale));

  const outerW = (screen.widthPx + 2 * BEZEL_CSS_PX) * scale;
  const outerH = (screen.heightPx + 2 * BEZEL_CSS_PX) * scale;
  els.deviceScale.style.width = `${outerW}px`;
  els.deviceScale.style.height = `${outerH}px`;
  els.readout.textContent = `${screenReadout(posture)} · scale ${(scale * 100).toFixed(0)}%`;
  requestAnimationFrame(frameCamera);
}

function frameCamera() {
  const { clientWidth: width, clientHeight: height } = els.viewport;
  if (!width || !height) return;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  const halfHeight = Math.max(0.85, 1.05 / camera.aspect);
  const distance = halfHeight / Math.tan(THREE.MathUtils.degToRad(camera.fov * 0.5)) * 1.12 + 0.65;
  camera.position.set(0, 0.18, distance);
  camera.lookAt(0, 0.18, 0);
  camera.updateProjectionMatrix();
}

function populatePostures() {
  els.posture.replaceChildren();
  for (const posture of POSTURES) {
    const option = document.createElement('option');
    option.value = posture.id;
    option.textContent = posture.label;
    els.posture.append(option);
  }
  els.posture.value = state.postureId;
}

function populateTreatments() {
  const groups = new Map();
  for (const [id, category, label] of treatments) {
    if (!groups.has(category)) groups.set(category, []);
    groups.get(category).push([id, label]);
  }
  els.treatment.replaceChildren();
  for (const [category, items] of groups) {
    const group = document.createElement('optgroup');
    group.label = category;
    for (const [id, label] of items) {
      const option = document.createElement('option');
      option.value = id;
      option.textContent = label;
      group.append(option);
    }
    els.treatment.append(group);
  }
  els.treatment.value = state.selected;
}

function populateSwatches() {
  els.swatches.replaceChildren();
  for (const [name, hex] of SWATCHES) {
    const button = document.createElement('button');
    button.type = 'button';
    button.style.background = hex;
    button.title = name;
    button.setAttribute('aria-label', `Apply ${name}`);
    button.addEventListener('click', () => {
      els.color.value = hex;
      els.hex.textContent = hex.toUpperCase();
      applyCurrentColor();
      syncSwatchPressed();
    });
    els.swatches.append(button);
  }
}

function syncSwatchPressed() {
  const current = els.color.value.toLowerCase();
  for (const button of els.swatches.querySelectorAll('button')) {
    const hex = rgbToHex(button.style.backgroundColor);
    button.setAttribute('aria-pressed', String(hex === current));
  }
}

function rgbToHex(css) {
  const match = css.match(/(\d+),\s*(\d+),\s*(\d+)/);
  if (!match) return '';
  return '#' + match.slice(1).map(value => Number(value).toString(16).padStart(2, '0')).join('');
}

function syncPaletteFromLook() {
  const style = state.look.treatments[state.selected];
  if (style) {
    const hex = colorToHex(style.color);
    els.color.value = hex;
    els.hex.textContent = hex.toUpperCase();
    els.intensity.value = Math.round(style.intensity * 100);
    els.amount.textContent = `${els.intensity.value}%`;
    els.treatmentState.textContent = `Applied at ${els.intensity.value}% intensity.`;
  } else {
    els.treatmentState.textContent = 'No added makeup for this treatment.';
    els.amount.textContent = `${els.intensity.value}%`;
  }
  syncSwatchPressed();
}

function loadPersistedLook() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return emptyLook();
    return validateLook(JSON.parse(raw));
  } catch (error) {
    state.persistenceWarning = `Saved look could not be restored (${error.message}). Showing the original face.`;
    return emptyLook();
  }
}

function persistLook(look) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(look));
  state.persistenceWarning = null;
}

async function loadImageData(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Missing asset: ${url}`);
  const bitmap = await createImageBitmap(await response.blob());
  const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
  const context = canvas.getContext('2d', { willReadFrequently: true });
  context.drawImage(bitmap, 0, 0);
  bitmap.close();
  return context.getImageData(0, 0, canvas.width, canvas.height);
}

function luminanceMask(imageData) {
  const mask = new Uint8Array(imageData.width * imageData.height);
  const { data } = imageData;
  for (let i = 0, pixel = 0; i < data.length; i += 4, pixel++) {
    mask[pixel] = Math.round(0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]);
  }
  return mask;
}

function makeTexture(pixels, width, height) {
  const texture = new THREE.DataTexture(pixels, width, height, THREE.RGBAFormat);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.flipY = false;
  texture.magFilter = THREE.LinearFilter;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.generateMipmaps = true;
  texture.needsUpdate = true;
  return texture;
}

function applyMap(map) {
  for (const material of materials) {
    material.map = map;
    material.needsUpdate = true;
  }
}

function showActiveMap() {
  const map = state.showsOriginal ? originalMap : editedMap;
  if (map) applyMap(map);
}

function compose(look) {
  const id = ++composeToken;
  return new Promise((resolve, reject) => {
    pendingCompose.set(id, { resolve, reject });
    worker.postMessage({ id, look });
  });
}

async function commit(next) {
  if (!state.ready) throw new Error('The face is not ready yet.');
  if (state.busy) throw new Error('A makeup change is still being applied.');
  state.busy = true;
  els.controls.disabled = true;
  try {
    const pixels = await compose(next);
    const map = makeTexture(pixels, state.width, state.height);
    persistLook(next);
    if (editedMap && editedMap !== originalMap) editedMap.dispose();
    const hasMakeup = Object.keys(next.treatments).length > 0;
    editedMap = hasMakeup ? map : originalMap;
    if (editedMap !== map) map.dispose();
    state.look = next;
    showActiveMap();
    syncPaletteFromLook();
    setStatus(state.persistenceWarning || 'Look updated and saved in this browser.');
  } finally {
    state.busy = false;
    els.controls.disabled = !state.ready;
  }
}

async function applyCurrentColor() {
  try {
    const color = colorFromHex(els.color.value);
    const intensity = Number(els.intensity.value) / 100;
    await commit(setMakeup(state.look, state.selected, color, intensity));
  } catch (error) {
    setStatus(error.message, { failed: true });
    syncPaletteFromLook();
  }
}

function wireControls() {
  els.posture.addEventListener('change', () => {
    state.postureId = els.posture.value;
    applyDeviceLayout();
  });
  els.scale.addEventListener('change', applyDeviceLayout);
  window.addEventListener('resize', applyDeviceLayout);

  els.front.addEventListener('click', () => {
    state.yaw = 0;
    state.pitch = 0;
    clampOrientation();
  });
  els.before.addEventListener('change', () => {
    state.showsOriginal = els.before.checked;
    showActiveMap();
    setStatus(state.showsOriginal
      ? 'Showing the supplied original appearance. Your edited look is preserved.'
      : (state.persistenceWarning || 'Showing your edited look.'));
  });
  els.treatment.addEventListener('change', () => {
    state.selected = els.treatment.value;
    syncPaletteFromLook();
  });
  els.color.addEventListener('input', () => {
    els.hex.textContent = els.color.value.toUpperCase();
    syncSwatchPressed();
  });
  els.color.addEventListener('change', () => applyCurrentColor());
  els.intensity.addEventListener('input', () => {
    els.amount.textContent = `${els.intensity.value}%`;
  });
  els.intensity.addEventListener('change', async () => {
    if (!state.look.treatments[state.selected]) {
      els.amount.textContent = `${els.intensity.value}%`;
      return;
    }
    try {
      const style = state.look.treatments[state.selected];
      await commit(setMakeup(state.look, state.selected, style.color, Number(els.intensity.value) / 100));
    } catch (error) {
      setStatus(error.message, { failed: true });
      syncPaletteFromLook();
    }
  });
  els.clear.addEventListener('click', async () => {
    try { await commit(clearTreatment(state.look, state.selected)); }
    catch (error) { setStatus(error.message, { failed: true }); }
  });
  els.reset.addEventListener('click', async () => {
    try { await commit(emptyLook()); }
    catch (error) { setStatus(error.message, { failed: true }); }
  });

  let drag = null;
  els.viewport.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    drag = { x: event.clientX, y: event.clientY, yaw: state.yaw, pitch: state.pitch };
    els.viewport.setPointerCapture(event.pointerId);
  });
  els.viewport.addEventListener('pointermove', event => {
    if (!drag) return;
    state.yaw = drag.yaw + (event.clientX - drag.x) * 0.006;
    state.pitch = drag.pitch + (event.clientY - drag.y) * 0.004;
    clampOrientation();
  });
  els.viewport.addEventListener('pointerup', () => { drag = null; });
  els.viewport.addEventListener('pointercancel', () => { drag = null; });
  els.viewport.addEventListener('keydown', event => {
    const step = event.shiftKey ? 0.25 : 0.15;
    if (event.key === 'ArrowLeft') state.yaw -= step;
    else if (event.key === 'ArrowRight') state.yaw += step;
    else if (event.key === 'ArrowUp') state.pitch -= step * 0.55;
    else if (event.key === 'ArrowDown') state.pitch += step * 0.55;
    else if (event.key === 'Home') { state.yaw = 0; state.pitch = 0; }
    else return;
    event.preventDefault();
    clampOrientation();
  });

  new ResizeObserver(() => frameCamera()).observe(els.viewport);
}

function animate() {
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

async function boot() {
  populatePostures();
  populateTreatments();
  populateSwatches();
  wireControls();
  applyDeviceLayout();
  clampOrientation();
  animate();

  state.look = loadPersistedLook();
  try {
    setStatus('Loading portrait and makeup masks…');
    const base = await loadImageData(`${ASSETS}/base-color.jpg`);
    state.width = base.width;
    state.height = base.height;
    const masks = {};
    await Promise.all(treatments.map(async ([id]) => {
      const image = await loadImageData(`${ASSETS}/masks/${id}.png`);
      if (image.width !== state.width || image.height !== state.height) {
        throw new Error(`The ${id} mask does not match the face texture.`);
      }
      masks[id] = luminanceMask(image);
    }));

    worker = new Worker(new URL('./texture-worker.mjs', import.meta.url), { type: 'module' });
    worker.onmessage = ({ data }) => {
      const pending = pendingCompose.get(data.id);
      if (!pending) return;
      pendingCompose.delete(data.id);
      if (data.error) pending.reject(new Error(data.error));
      else pending.resolve(data.pixels);
    };
    worker.postMessage({ type: 'init', original: base.data, masks });

    const gltf = await new GLTFLoader().loadAsync(`${ASSETS}/face.glb`);
    gltf.scene.traverse(object => {
      if (!object.isMesh) return;
      const material = new THREE.MeshStandardMaterial({ map: null, roughness: 1, metalness: 0 });
      object.material = material;
      materials.push(material);
    });
    pivot.add(gltf.scene);

    originalMap = makeTexture(new Uint8ClampedArray(base.data), state.width, state.height);
    if (Object.keys(state.look.treatments).length) {
      const pixels = await compose(state.look);
      editedMap = makeTexture(pixels, state.width, state.height);
    } else {
      editedMap = originalMap;
    }
    showActiveMap();
    applyDeviceLayout();
    state.ready = true;
    els.controls.disabled = false;
    syncPaletteFromLook();
    setStatus(state.persistenceWarning || 'Ready. Choose a treatment and color to apply makeup.');
  } catch (error) {
    state.ready = false;
    els.controls.disabled = true;
    setStatus(`Unable to load the face: ${error.message}`, { failed: true });
  }
}

boot();
