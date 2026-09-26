import { composePixels } from './look.mjs';
let original, masks;
self.onmessage = ({ data }) => {
  if (data.type === 'init') { original = data.original; masks = data.masks; return; }
  try {
    const pixels = composePixels(original, masks, data.look);
    self.postMessage({ id: data.id, pixels }, [pixels.buffer]);
  } catch (error) { self.postMessage({ id: data.id, error: error.message }); }
};
