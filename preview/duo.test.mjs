import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DUO_BODY, DUO_DISPLAYS, HINGE_BAND_CSS_PX, POSTURES,
  aspectRatio, fitScale, paneSize, postureById, postureIds, screenFor, screenReadout,
} from './duo.mjs';

test('published Duo display and body specs drive every posture box', () => {
  assert.deepEqual(DUO_DISPLAYS.outer, {
    id: 'outer', label: 'Outer display', widthPx: 1398, heightPx: 2034, ppi: 460, diagonalInches: 5.4,
  });
  assert.deepEqual(DUO_DISPLAYS.inner, {
    id: 'inner', label: 'Inner display', widthPx: 1878, heightPx: 2670, ppi: 430, diagonalInches: 7.6,
  });
  assert.deepEqual(DUO_BODY, {
    foldedWidthMm: 84.1, foldedHeightMm: 117.8, openWidthMm: 164.6,
    openThicknessMm: 5.2, foldedThicknessMm: 11.3, weightGrams: 254,
  });
  assert.deepEqual(postureIds(), ['closed', 'open', 'tabletop']);
  assert.equal(POSTURES.length, 3);
  assert.equal(aspectRatio(screenFor(postureById('open'))), 2670 / 1878);
  assert.ok(aspectRatio(screenFor(postureById('open'))) > 1.4);
  assert.ok(aspectRatio(screenFor(postureById('closed'))) < 0.7);
  assert.throws(() => postureById('half'));
});

test('closed uses the outer display; open and tabletop use the inner display rotated to landscape', () => {
  assert.deepEqual(screenFor(postureById('closed')), {
    display: 'outer', label: 'Outer display', ppi: 460, diagonalInches: 5.4,
    orientation: 'portrait', widthPx: 1398, heightPx: 2034,
  });
  for (const id of ['open', 'tabletop']) {
    assert.deepEqual(screenFor(postureById(id)), {
      display: 'inner', label: 'Inner display', ppi: 430, diagonalInches: 7.6,
      orientation: 'landscape', widthPx: 2670, heightPx: 1878,
    });
  }
  assert.equal(screenReadout(postureById('open')), '2670 × 1878 CSS px · 430 ppi · landscape');
});

test('panes tile the display exactly and never straddle the hinge band', () => {
  const closed = paneSize(postureById('closed'));
  assert.equal(closed.widthPx, 1398);
  assert.equal(closed.heightPx, 1119);
  assert.ok(closed.heightPx < 2034);
  assert.equal(postureById('closed').hingeAxis, null);

  const open = paneSize(postureById('open'));
  assert.equal(open.widthPx, Math.round((2670 - HINGE_BAND_CSS_PX) / 2));
  assert.equal(open.heightPx, 1878);
  assert.equal(open.widthPx * 2 + HINGE_BAND_CSS_PX, 2670);

  const tabletop = paneSize(postureById('tabletop'));
  assert.equal(tabletop.widthPx, 2670);
  assert.equal(tabletop.heightPx, 925);
  assert.equal(tabletop.heightPx * 2 + HINGE_BAND_CSS_PX, 1878);
});

test('fit scale never exceeds the smaller axis and defaults to 1:1 without a viewport', () => {
  const open = postureById('open');
  assert.equal(fitScale(open, null), 1);
  const fitted = fitScale(open, { width: 1335, height: 1000 });
  assert.equal(fitted, 1335 / 2670);
  assert.ok(2670 * fitted <= 1335);
  assert.ok(1878 * fitted <= 1000);
  assert.ok(fitScale(open, { width: 4000, height: 1000 }) === 1000 / 1878);
  assert.equal(fitScale(open, { width: 0, height: 0 }), 1);
  assert.ok(fitScale(postureById('closed'), { width: 1398, height: 2034 }) <= 1);
});
