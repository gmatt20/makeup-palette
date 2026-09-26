// Same identifiers, ordering, JSON, and blend as MakeupCore. The preview is a test harness.
export const treatments = [
  ['foundation', 'Complexion', 'Foundation'], ['concealer', 'Complexion', 'Concealer'],
  ['blush', 'Cheeks', 'Blush'], ['bronzer', 'Cheeks', 'Bronzer'],
  ['cheekContour', 'Contour', 'Cheeks'], ['noseContour', 'Contour', 'Nose'],
  ['jawContour', 'Contour', 'Jaw'], ['templeContour', 'Contour', 'Temples'],
  ['cheekHighlight', 'Highlight', 'Cheeks'], ['noseHighlight', 'Highlight', 'Nose'],
  ['cupidBowHighlight', 'Highlight', "Cupid’s bow"],
  ['eyeshadow', 'Eyes', 'Eyeshadow'], ['eyeliner', 'Eyes', 'Eyeliner'],
  ['browFill', 'Brows', 'Brow fill'], ['lipstick', 'Lips', 'Lipstick'],
  ['lipLiner', 'Lips', 'Lip liner'], ['mascara', 'Lashes', 'Mascara'],
];
const ids = new Set(treatments.map(([id]) => id));
const unit = value => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1;
export const emptyLook = () => ({ version: 1, treatments: {} });

export function validateLook(look) {
  if (!look || look.version !== 1 || !look.treatments || typeof look.treatments !== 'object' || Array.isArray(look.treatments)) {
    throw new Error('Unsupported or damaged saved look. Reset all to start again.');
  }
  for (const [id, style] of Object.entries(look.treatments)) {
    if (!ids.has(id) || !style || !unit(style.intensity) || !style.color ||
        !['red', 'green', 'blue'].every(key => unit(style.color[key]))) {
      throw new Error(`Invalid makeup settings for ${id}.`);
    }
  }
  return look;
}

export function setMakeup(look, id, color, intensity) {
  validateLook(look);
  if (!ids.has(id)) throw new Error(`Unknown treatment: ${id}`);
  if (!unit(intensity) || !color || !['red', 'green', 'blue'].every(key => unit(color[key]))) {
    throw new Error(`Invalid makeup settings for ${id}.`);
  }
  return validateLook({ version: 1, treatments: { ...look.treatments, [id]: { color: { ...color }, intensity } } });
}

export function clearTreatment(look, id) {
  validateLook(look);
  if (!ids.has(id)) throw new Error(`Unknown treatment: ${id}`);
  const next = { version: 1, treatments: { ...look.treatments } };
  delete next.treatments[id];
  return next;
}

export function colorFromHex(hex) {
  if (!/^#[\da-f]{6}$/i.test(hex)) throw new Error('Use a six-digit color.');
  return { red: parseInt(hex.slice(1, 3), 16) / 255, green: parseInt(hex.slice(3, 5), 16) / 255, blue: parseInt(hex.slice(5, 7), 16) / 255 };
}

export function colorToHex(color) {
  return '#' + ['red', 'green', 'blue'].map(key => Math.round(color[key] * 255).toString(16).padStart(2, '0')).join('');
}

export function composePixels(original, masks, look) {
  validateLook(look);
  if (original.length % 4) throw new Error('Invalid RGBA texture.');
  const active = treatments.filter(([id]) => look.treatments[id]?.intensity > 0).map(([id]) => {
    if (!masks[id] || masks[id].length !== original.length / 4) throw new Error(`Missing or invalid mask: ${id}`);
    return [masks[id], look.treatments[id]];
  });
  const output = new Uint8ClampedArray(original.length);
  for (let i = 0, pixel = 0; i < original.length; i += 4, pixel++) {
    const shade = 0.45 + 0.55 * (0.2126 * original[i] + 0.7152 * original[i + 1] + 0.0722 * original[i + 2]) / 255;
    let r = original[i], g = original[i + 1], b = original[i + 2];
    for (const [mask, { color, intensity }] of active) {
      const alpha = 0.8 * intensity * mask[pixel] / 255;
      r += (color.red * 255 * shade - r) * alpha;
      g += (color.green * 255 * shade - g) * alpha;
      b += (color.blue * 255 * shade - b) * alpha;
    }
    output[i] = Math.round(r); output[i + 1] = Math.round(g); output[i + 2] = Math.round(b); output[i + 3] = original[i + 3];
  }
  return output;
}
