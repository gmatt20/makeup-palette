/**
 * Windows local makeup station (preview-only). Three.js + UV mask composition.
 * Not RealityKit / Duo fold proof — see PRD-WINDOWS.md.
 */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import {
  treatments, emptyLook, validateLook, setMakeup, clearTreatment,
  colorFromHex, colorToHex,
} from './look.mjs';

const STORE_KEY = 'makeup-face-latest-look-v1';
const MAX_YAW = Math.PI / 3;
const MAX_PITCH = Math.PI / 12;

const statusEl = document.getElementById('status');
const station = document.getElementById('station');
const poseSelect = document.getElementById('pose');
const treatmentSelect = document.getElementById('treatment');
const colorInput = document.getElementById('color');
const hexOut = document.getElementById('hex');
const intensityInput = document.getElementById('intensity');
const amountOut = document.getElementById('amount');
const treatmentState = document.getElementById('treatment-state');
const controls = document.getElementById('controls');
const swatches = document.getElementById('swatches');
const viewport = document.getElementById('viewport');

const SWATCHES = {
  Complexion: ['#f3d5c0', '#e8c4a8', '#d4a574', '#c68642', '#8d5524'],
  Cheeks: ['#f4a7a7', '#ec9482', '#e07a6a', '#d45d5d', '#c44569'],
  Contour: ['#c4a484', '#a67c52', '#8b6914', '#6b4423', '#5c4033'],
  Highlight: ['#fff5e6', '#f5e6d3', '#f0d9b5', '#e8c9a0', '#ffe4c4'],
  Eyes: ['#c9a0dc', '#8b7355', '#4a5568', '#2d3748', '#b76e79'],
  Brows: ['#3d2914', '#5c4033', '#6b4423', '#2c1810', '#1a1a1a'],
  Lips: ['#bc395b', '#c03060', '#9b1b30', '#e0115f', '#8b0000', '#ff69b4'],
  Lashes: ['#1a1a1a', '#2d2d2d', '#000000', '#3d2914', '#4a3728'],
};

const state = {
  look: emptyLook(),
  selected: 'lipstick',
  status: 'loading',
  showsOriginal: false,
  yaw: 0,
  pitch: 0,
  compact: 'open',
  busy: false,
  persistenceWarning: null,
  commandError: null,
};

let renderer, scene, camera, pivot, faceMeshes = [], colorMap;
let originalPixels, maskBuffers, composeWorker, composeId = 0;
const FACE_FOCUS_Y = 0.32; // asset-manifest cameraTarget[1]
const pending = new Map();

function setStatus(message) {
  statusEl.textContent = message;
}

function loadPersistedLook() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return emptyLook();
    return validateLook(JSON.parse(raw));
  } catch (error) {
    state.persistenceWarning = `Saved look could not be restored: ${error.message} Showing the original face.`;
    return emptyLook();
  }
}

function persist(look) {
  localStorage.setItem(STORE_KEY, JSON.stringify(look));
}

function applyCompact() {
  station.classList.toggle('closed', state.compact === 'closed');
  poseSelect.value = state.compact;
}

function fillTreatments() {
  const groups = new Map();
  for (const [id, category, label] of treatments) {
    if (!groups.has(category)) groups.set(category, []);
    groups.get(category).push([id, label]);
  }
  treatmentSelect.replaceChildren();
  for (const [category, items] of groups) {
    const optgroup = document.createElement('optgroup');
    optgroup.label = category;
    for (const [id, label] of items) {
      const option = document.createElement('option');
      option.value = id;
      option.textContent = label;
      optgroup.append(option);
    }
    treatmentSelect.append(optgroup);
  }
  treatmentSelect.value = state.selected;
}

function categoryOf(id) {
  return treatments.find(([treatment]) => treatment === id)?.[1] ?? 'Lips';
}

function fillSwatches() {
  const colors = SWATCHES[categoryOf(state.selected)] ?? SWATCHES.Lips;
  swatches.replaceChildren();
  for (const hex of colors) {
    const button = document.createElement('button');
    button.type = 'button';
    button.style.background = hex;
    button.setAttribute('aria-label', `Apply ${hex}`);
    button.addEventListener('click', () => {
      colorInput.value = hex;
      hexOut.textContent = hex.toUpperCase();
      applyCurrent();
      syncSwatchPressed();
    });
    swatches.append(button);
  }
  syncSwatchPressed();
}

function syncSwatchPressed() {
  const current = colorInput.value.toLowerCase();
  for (const button of swatches.querySelectorAll('button')) {
    button.setAttribute('aria-pressed', String(button.style.background.toLowerCase() === current
      || rgbToHex(button.style.background) === current));
  }
}

function rgbToHex(value) {
  const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i);
  if (!match) return value.toLowerCase();
  return '#' + [match[1], match[2], match[3]].map(n => Number(n).toString(16).padStart(2, '0')).join('');
}

function syncControlsFromLook() {
  const style = state.look.treatments[state.selected];
  if (style) {
    const hex = colorToHex(style.color);
    colorInput.value = hex;
    hexOut.textContent = hex.toUpperCase();
    intensityInput.value = Math.round(style.intensity * 100);
    amountOut.textContent = `${intensityInput.value}%`;
    treatmentState.textContent = `Applied at ${intensityInput.value}% intensity.`;
  } else {
    treatmentState.textContent = 'No added makeup for this treatment.';
  }
  fillSwatches();
}

function frameMessage() {
  const parts = [];
  if (state.persistenceWarning) parts.push(state.persistenceWarning);
  if (state.commandError) parts.push(state.commandError);
  if (state.status === 'ready' && !parts.length) {
    parts.push(state.showsOriginal
      ? 'Showing original appearance. Your edit is preserved.'
      : 'Ready. Pick a treatment and color.');
  }
  if (parts.length) setStatus(parts.join(' '));
}

async function decodeImage(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Missing asset: ${url}`);
  const bitmap = await createImageBitmap(await response.blob());
  const canvas = document.createElement('canvas');
  canvas.width = bitmap.width;
  canvas.height = bitmap.height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
}

function luminanceMask(imageData) {
  const { data } = imageData;
  const mask = new Uint8Array(data.length / 4);
  for (let i = 0, p = 0; i < data.length; i += 4, p++) {
    mask[p] = Math.round(0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]);
  }
  return mask;
}

function composeAsync(look) {
  return new Promise((resolve, reject) => {
    const id = ++composeId;
    pending.set(id, { resolve, reject });
    composeWorker.postMessage({ id, look });
  });
}

function disposeMaterial(material) {
  if (!material) return;
  if (Array.isArray(material)) {
    for (const entry of material) disposeMaterial(entry);
    return;
  }
  material.dispose?.();
}

function ensureUnlitMaterial(mesh) {
  // Match native UnlitMaterial: color is baked into the atlas; PBR + missing lights = silhouette.
  if (mesh.userData.unlit && mesh.material?.isMeshBasicMaterial) return mesh.material;
  disposeMaterial(mesh.material);
  const material = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    toneMapped: false,
    fog: false,
  });
  mesh.material = material;
  mesh.userData.unlit = true;
  return material;
}

function applyUnlitMaterials() {
  for (const mesh of faceMeshes) ensureUnlitMaterial(mesh);
}

function uploadTexture(pixels, width, height) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  const image = new ImageData(new Uint8ClampedArray(pixels), width, height);
  ctx.putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.flipY = false;
  texture.magFilter = THREE.LinearFilter;
  texture.minFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  texture.needsUpdate = true;
  if (colorMap) colorMap.dispose();
  colorMap = texture;
  for (const mesh of faceMeshes) {
    const material = ensureUnlitMaterial(mesh);
    material.map = texture;
    material.color.set(0xffffff);
    material.needsUpdate = true;
  }
}

async function commit(look, { persistLook = true } = {}) {
  if (state.status !== 'ready') throw new Error('The face is not ready.');
  if (state.busy) throw new Error('A makeup change is still being applied.');
  state.busy = true;
  controls.disabled = true;
  try {
    const pixels = await composeAsync(look);
    if (persistLook) persist(look);
    state.look = look;
    state.commandError = null;
    state.persistenceWarning = null;
    if (!state.showsOriginal) {
      uploadTexture(pixels, originalPixels.width, originalPixels.height);
    } else {
      // Keep edited texture path warm by composing only; display stays on original until toggle off.
      state._editedPixels = pixels;
    }
    if (!state.showsOriginal) state._editedPixels = pixels;
    syncControlsFromLook();
    frameMessage();
  } catch (error) {
    state.commandError = error.message;
    frameMessage();
    throw error;
  } finally {
    state.busy = false;
    controls.disabled = false;
  }
}

async function applyCurrent() {
  try {
    const color = colorFromHex(colorInput.value);
    const intensity = Number(intensityInput.value) / 100;
    const next = setMakeup(state.look, state.selected, color, intensity);
    await commit(next);
  } catch (error) {
    setStatus(error.message);
  }
}

function applyOrientation() {
  if (!pivot) return;
  pivot.rotation.order = 'YXZ';
  pivot.rotation.y = state.yaw;
  pivot.rotation.x = state.pitch;
}

function setupScene() {
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NoToneMapping;
  viewport.append(renderer.domElement);
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0xe4dcd7);
  camera = new THREE.PerspectiveCamera(35, 1, 0.1, 20);
  pivot = new THREE.Group();
  scene.add(pivot);
}

function fitCamera(box) {
  const size = new THREE.Vector3();
  box.getSize(size);
  const center = new THREE.Vector3();
  box.getCenter(center);
  pivot.position.sub(center);
  // Frame the face (manifest cameraTarget), not the full bust center.
  const focusY = FACE_FOCUS_Y;
  const faceSpan = Math.max(size.y * 0.55, size.x * 0.85);
  const aspect = Math.max(viewport.clientWidth / Math.max(viewport.clientHeight, 1), 0.5);
  const halfHeight = Math.max(faceSpan / 2, size.x / (2 * aspect));
  const distance = halfHeight / Math.tan((35 * Math.PI) / 360) * 1.05 + size.z / 2;
  camera.position.set(0, focusY, distance);
  camera.lookAt(0, focusY, 0);
}

function resize() {
  if (!renderer) return;
  const width = viewport.clientWidth;
  const height = viewport.clientHeight;
  if (width < 1 || height < 1) return;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
}

function animate() {
  requestAnimationFrame(animate);
  if (renderer && scene && camera) renderer.render(scene, camera);
}

function bindPointer() {
  let dragging = false;
  let origin = null;
  let start = null;
  viewport.addEventListener('pointerdown', event => {
    dragging = true;
    origin = { yaw: state.yaw, pitch: state.pitch };
    start = { x: event.clientX, y: event.clientY };
    viewport.setPointerCapture(event.pointerId);
  });
  viewport.addEventListener('pointermove', event => {
    if (!dragging || !origin) return;
    state.yaw = Math.min(MAX_YAW, Math.max(-MAX_YAW, origin.yaw + (event.clientX - start.x) * 0.006));
    state.pitch = Math.min(MAX_PITCH, Math.max(-MAX_PITCH, origin.pitch + (event.clientY - start.y) * 0.004));
    applyOrientation();
  });
  const end = () => { dragging = false; origin = null; };
  viewport.addEventListener('pointerup', end);
  viewport.addEventListener('pointercancel', end);
  viewport.addEventListener('keydown', event => {
    const stepYaw = 0.15;
    const stepPitch = 0.08;
    if (event.key === 'ArrowLeft') { state.yaw = Math.max(-MAX_YAW, state.yaw - stepYaw); applyOrientation(); }
    if (event.key === 'ArrowRight') { state.yaw = Math.min(MAX_YAW, state.yaw + stepYaw); applyOrientation(); }
    if (event.key === 'ArrowUp') { state.pitch = Math.max(-MAX_PITCH, state.pitch - stepPitch); applyOrientation(); }
    if (event.key === 'ArrowDown') { state.pitch = Math.min(MAX_PITCH, state.pitch + stepPitch); applyOrientation(); }
    if (event.key === 'Home') { state.yaw = 0; state.pitch = 0; applyOrientation(); }
  });
}

function bindUi() {
  poseSelect.addEventListener('change', () => {
    state.compact = poseSelect.value === 'closed' ? 'closed' : 'open';
    applyCompact();
    resize();
  });
  treatmentSelect.addEventListener('change', () => {
    state.selected = treatmentSelect.value;
    syncControlsFromLook();
  });
  colorInput.addEventListener('input', () => {
    hexOut.textContent = colorInput.value.toUpperCase();
    syncSwatchPressed();
  });
  colorInput.addEventListener('change', () => applyCurrent());
  intensityInput.addEventListener('input', () => {
    amountOut.textContent = `${intensityInput.value}%`;
  });
  intensityInput.addEventListener('change', () => applyCurrent());
  document.getElementById('clear').addEventListener('click', async () => {
    try { await commit(clearTreatment(state.look, state.selected)); }
    catch (error) { setStatus(error.message); }
  });
  document.getElementById('reset').addEventListener('click', async () => {
    try { await commit(emptyLook()); }
    catch (error) { setStatus(error.message); }
  });
  document.getElementById('front').addEventListener('click', () => {
    state.yaw = 0;
    state.pitch = 0;
    applyOrientation();
  });
  document.getElementById('before').addEventListener('change', async event => {
    state.showsOriginal = event.target.checked;
    if (state.showsOriginal) {
      uploadTexture(originalPixels.data, originalPixels.width, originalPixels.height);
    } else if (state._editedPixels) {
      uploadTexture(state._editedPixels, originalPixels.width, originalPixels.height);
    } else {
      try {
        const pixels = await composeAsync(state.look);
        state._editedPixels = pixels;
        uploadTexture(pixels, originalPixels.width, originalPixels.height);
      } catch (error) {
        setStatus(error.message);
      }
    }
    frameMessage();
  });
  window.addEventListener('resize', resize);
}

async function boot() {
  fillTreatments();
  applyCompact();
  bindUi();
  setupScene();
  bindPointer();
  animate();
  resize();

  composeWorker = new Worker(new URL('./texture-worker.mjs', import.meta.url), { type: 'module' });
  composeWorker.onmessage = ({ data }) => {
    const entry = pending.get(data.id);
    if (!entry) return;
    pending.delete(data.id);
    if (data.error) entry.reject(new Error(data.error));
    else entry.resolve(data.pixels);
  };

  try {
    setStatus('Loading portrait and makeup masks…');
    state.look = loadPersistedLook();
    const base = await decodeImage('/assets/base-color.jpg');
    originalPixels = base;
    maskBuffers = {};
    await Promise.all(treatments.map(async ([id]) => {
      const image = await decodeImage(`/assets/masks/${id}.png`);
      if (image.width !== base.width || image.height !== base.height) {
        throw new Error(`Mask ${id} size does not match base-color (${image.width}×${image.height}).`);
      }
      maskBuffers[id] = luminanceMask(image);
    }));
    composeWorker.postMessage({ type: 'init', original: base.data, masks: maskBuffers });

    const gltf = await new GLTFLoader().loadAsync('/assets/face.glb');
    const root = gltf.scene;
    faceMeshes = [];
    root.traverse(node => {
      if (node.isMesh) faceMeshes.push(node);
    });
    if (!faceMeshes.length) throw new Error('The prepared GLB has no mesh.');
    applyUnlitMaterials();
    pivot.add(root);
    const box = new THREE.Box3().setFromObject(pivot);
    fitCamera(box);
    for (const mesh of faceMeshes) mesh.visible = false;

    const edited = Object.keys(state.look.treatments).length
      ? await composeAsync(state.look)
      : base.data.slice(0);
    state._editedPixels = edited;
    uploadTexture(edited, base.width, base.height);
    for (const mesh of faceMeshes) mesh.visible = true;
    applyOrientation();
    state.status = 'ready';
    controls.disabled = false;
    syncControlsFromLook();
    frameMessage();
    resize();
  } catch (error) {
    state.status = 'failed';
    setStatus(`Unable to load the face: ${error.message}`);
    console.error(error);
  }
}

boot();
