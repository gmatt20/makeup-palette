/**
 * Windows / browser development preview only.
 * iPhone Duo geometry transcribed from Apple's published specifications so the
 * harness lays out at true device aspect ratios and CSS-pixel sizes instead of
 * a generic browser window. Posture layouts are proposals for the native app;
 * the fold/orientation shell itself is owned by the app teammate.
 */

export const DUO_DISPLAYS = {
  outer: {
    id: 'outer',
    label: 'Outer display',
    widthPx: 1398,
    heightPx: 2034,
    ppi: 460,
    diagonalInches: 5.4,
  },
  inner: {
    id: 'inner',
    label: 'Inner display',
    widthPx: 1878,
    heightPx: 2670,
    ppi: 430,
    diagonalInches: 7.6,
  },
};

export const DUO_BODY = {
  foldedWidthMm: 84.1,
  foldedHeightMm: 117.8,
  openWidthMm: 164.6,
  openThicknessMm: 5.2,
  foldedThicknessMm: 11.3,
  weightGrams: 254,
};

export const HINGE_BAND_CSS_PX = 28;
export const BEZEL_CSS_PX = 10;

export const POSTURES = [
  {
    id: 'closed',
    label: 'Closed — outer display',
    detail: 'One-handed portrait. Outer display only; the inner panel does not exist in this posture.',
    display: 'outer',
    flexDegrees: 0,
    hingeAxis: null,
    layout: 'stacked',
    faceShare: 0.55,
  },
  {
    id: 'open',
    label: 'Open — inner display',
    detail: 'Two-handed landscape. The hinge splits the face preview from the palette.',
    display: 'inner',
    flexDegrees: 180,
    hingeAxis: 'vertical',
    layout: 'split',
  },
  {
    id: 'tabletop',
    label: 'Tabletop — inner display, half-folded',
    detail: 'Stands on a surface. The raised half shows the face; the flat half holds the palette.',
    display: 'inner',
    flexDegrees: 105,
    hingeAxis: 'horizontal',
    layout: 'flex',
  },
];

export function postureById(id) {
  const posture = POSTURES.find(entry => entry.id === id);
  if (!posture) throw new Error(`Unknown Duo posture: ${id}`);
  return posture;
}

export function postureIds() {
  return POSTURES.map(entry => entry.id);
}

/** The Duo is a book-style fold, so the inner display is used rotated to landscape. */
export function screenFor(posture) {
  const display = DUO_DISPLAYS[posture.display];
  const landscape = posture.display === 'inner';
  return {
    display: display.id,
    label: display.label,
    ppi: display.ppi,
    diagonalInches: display.diagonalInches,
    orientation: landscape ? 'landscape' : 'portrait',
    widthPx: landscape ? display.heightPx : display.widthPx,
    heightPx: landscape ? display.widthPx : display.heightPx,
  };
}

export function aspectRatio(screen) {
  return screen.widthPx / screen.heightPx;
}

/** One pane's box in CSS pixels, excluding the hinge band the panes must never straddle. */
export function paneSize(posture) {
  const screen = screenFor(posture);
  if (posture.layout === 'stacked') {
    return {
      widthPx: screen.widthPx,
      heightPx: Math.round(screen.heightPx * posture.faceShare),
    };
  }
  const band = HINGE_BAND_CSS_PX;
  const vertical = posture.hingeAxis === 'vertical';
  const usableWidth = vertical ? screen.widthPx - band : screen.widthPx;
  const usableHeight = vertical ? screen.heightPx : screen.heightPx - band;
  return {
    widthPx: Math.round(vertical ? usableWidth / 2 : usableWidth),
    heightPx: Math.round(vertical ? usableHeight : usableHeight / 2),
  };
}

export function fitScale(posture, available) {
  const screen = screenFor(posture);
  const width = available && available.width > 0 ? available.width : screen.widthPx;
  const height = available && available.height > 0 ? available.height : screen.heightPx;
  return Math.min(width / screen.widthPx, height / screen.heightPx);
}

export function screenReadout(posture) {
  const screen = screenFor(posture);
  return `${screen.widthPx} × ${screen.heightPx} CSS px · ${screen.ppi} ppi · ${screen.orientation}`;
}
