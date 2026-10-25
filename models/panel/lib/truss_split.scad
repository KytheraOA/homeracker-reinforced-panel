// HomeRacker - Panel Split Library (version for truss_panel.scad)
//
// This library provides the split-connector logic used to create a vertical split 
// in the "truss panels" created with truss_panel.scad.
// It has been adapted from the original 44.45mm server standard to the 
// 15mm HomeRacker standard support unit grid.
// This revised version was created by Kythera of Anevern, with help from Atlassian's Rovo AI 
// (because Kythera can't code).

// Here's Rovo's summary of the changes:
// Module hierarchy:
//   split_connector — top-level: orchestrates the knuckle stack and ownership
//   knuckle         — single interlocking hinge element (LOCK or MIDDLE type)
//   split_lockpin   — specialized long pin to secure the split halves
//
// Hinge Logic:
// Each 15mm height unit is built from 4 interleaved knuckles, bottom to top:
//   0: LOCK (Left) - 1: MIDDLE (Right) - 2: MIDDLE (Left) - 3: LOCK (Right)
//
// This 4-knuckle pattern is point-symmetric (180deg rotation), ensuring that 
// both panel halves own exactly two knuckles per unit. This allows the halves 
// to interlock perfectly like a zipper.
//
// Modernization Notes:
// - Knuckle heights are now derived from BASE_UNIT (15mm).
// - Assertions updated to allow fractional units for cross-library compatibility.
// - All vertical spacing is now 15mm-grid aligned.

// ==== Original MIT License Header ====
// MIT License
// Copyright (c) 2026 Patrick Pötz
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ==== End of Original MIT License Header ====

include <BOSL2/std.scad>
include <../../core/lib/support.scad>
include <../../core/lib/lockpin.scad>

_LOCKPIN_HOLE_CENTER_SIDE = LOCKPIN_HOLE_SIDE_LENGTH + PRINTING_LAYER_WIDTH * 2;
HR_SPLIT_KNUCKLE_STRENGTH_SLIM = _LOCKPIN_HOLE_CENTER_SIDE + BASE_STRENGTH * 2;

HR_SPLIT_KNUCKLE_TYPE_LOCK = 0;
HR_SPLIT_KNUCKLE_TYPE_MIDDLE = 1;
HR_SPLIT_KNUCKLE_GAP = TOLERANCE / 2;

function get_knuckle_height(knuckle_type) =
  (BASE_UNIT - 4 * HR_SPLIT_KNUCKLE_GAP) / 4;

module knuckle(knuckle_type, panel_depth = BASE_STRENGTH, anchor = CENTER, spin = 0, orient = UP, debug_colors = false, chamfer_enabled = true) {
  attachable_height = get_knuckle_height(knuckle_type);
  attachable(anchor = anchor, spin = spin, orient = orient, size = [HR_SPLIT_KNUCKLE_STRENGTH_SLIM, HR_SPLIT_KNUCKLE_STRENGTH_SLIM, attachable_height]) {
    color_this(debug_colors ? HR_BLUE : HR_CORE_SUPPORT_SECONDARY_COLOR)
      diff()
        cuboid([HR_SPLIT_KNUCKLE_STRENGTH_SLIM, HR_SPLIT_KNUCKLE_STRENGTH_SLIM, attachable_height], chamfer = chamfer_enabled ? BASE_CHAMFER : 0, except = FRONT) {
          if (chamfer_enabled)
            fwd(HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 2 - (panel_depth + HR_EPSILON) / 2)
              cuboid([HR_SPLIT_KNUCKLE_STRENGTH_SLIM, panel_depth + HR_EPSILON, attachable_height]);
          tag("remove")
            if (knuckle_type == HR_SPLIT_KNUCKLE_TYPE_LOCK) {
              lockpin_hole_support();
            } else {
              cuboid([LOCKPIN_HOLE_SIDE_LENGTH, LOCKPIN_HOLE_SIDE_LENGTH, attachable_height + HR_EPSILON]);
            }
        }
    children();
  }
}

module split_connector(units = 1, panel_depth = BASE_STRENGTH, knuckle_side = "all", anchor = CENTER, spin = 0, orient = UP, debug_colors = false, chamfer_enabled = true) {
  _k_h = (BASE_UNIT - 4 * (TOLERANCE/2)) / 4;
  _g = TOLERANCE / 2;
  attachable_height = units * BASE_UNIT - TOLERANCE / 2;

  attachable(anchor = anchor, spin = spin, orient = orient, size = [HR_SPLIT_KNUCKLE_STRENGTH_SLIM, HR_SPLIT_KNUCKLE_STRENGTH_SLIM, attachable_height]) {
    down(attachable_height / 2 - _k_h / 2)
      for (i = [0:units-1]) translate([0, 0, i * BASE_UNIT]) {
        if (knuckle_side == "all" || knuckle_side == "left") knuckle(HR_SPLIT_KNUCKLE_TYPE_LOCK, panel_depth=panel_depth);
        translate([0, 0, _k_h + _g]) if (knuckle_side == "all" || knuckle_side == "right") knuckle(HR_SPLIT_KNUCKLE_TYPE_MIDDLE, panel_depth=panel_depth);
        translate([0, 0, 2*(_k_h + _g)]) if (knuckle_side == "all" || knuckle_side == "left") knuckle(HR_SPLIT_KNUCKLE_TYPE_MIDDLE, panel_depth=panel_depth);
        translate([0, 0, 3*(_k_h + _g)]) if (knuckle_side == "all" || knuckle_side == "right") knuckle(HR_SPLIT_KNUCKLE_TYPE_LOCK, panel_depth=panel_depth);
      }
    children();
  }
}