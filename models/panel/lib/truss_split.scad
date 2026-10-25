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

// gap between neighbouring knuckles (also applied at each height-unit boundary)
HR_SPLIT_KNUCKLE_GAP = TOLERANCE / 2;

// per height unit: 2 LOCK knuckles (full BASE_UNIT each) + 2 MIDDLE knuckles sharing the
// remainder, with a HR_SPLIT_KNUCKLE_GAP between every knuckle and at the unit boundary
// (4 gaps per unit: 3 internal + 1 boundary).
function get_knuckle_height(knuckle_type) =
  (BASE_UNIT - 4 * HR_SPLIT_KNUCKLE_GAP) / 4;

// the knuckle body is a square HR_SPLIT_KNUCKLE_STRENGTH_SLIM column. each panel-half leaf butts
// flush against it: the owning half's leaf welds to the near face, the opposite half's leaf kisses
// the far face on assembly. point-symmetric, so the body is identical for either half (ownership
// is tag-driven).
module knuckle(knuckle_type,
  panel_depth = BASE_STRENGTH,
  anchor = CENTER, spin = 0, orient = UP,
  debug_colors = false, chamfer_enabled = true) {

  assert(knuckle_type == HR_SPLIT_KNUCKLE_TYPE_LOCK || knuckle_type == HR_SPLIT_KNUCKLE_TYPE_MIDDLE,
    "Invalid knuckle type");

  attachable_width = HR_SPLIT_KNUCKLE_STRENGTH_SLIM;
  attachable_depth = HR_SPLIT_KNUCKLE_STRENGTH_SLIM;
  attachable_height = get_knuckle_height(knuckle_type);

  attachable(anchor = anchor, spin = spin, orient = orient, size = [attachable_width, attachable_depth, attachable_height]) {

    color_this(debug_colors ? HR_BLUE : HR_CORE_SUPPORT_SECONDARY_COLOR)
      // main knuckle body
      diff()
        cuboid([HR_SPLIT_KNUCKLE_STRENGTH_SLIM, HR_SPLIT_KNUCKLE_STRENGTH_SLIM, attachable_height], chamfer = chamfer_enabled ? BASE_CHAMFER : 0, except = FRONT) {
          // refill the front panel_depth slab so the vertical-corner chamfers only run
          // knuckle_depth - panel_depth deep: keeps a clean square front face while the rear
          // chamfers (which help neighbouring knuckles nest) stay full length. the slab pokes
          // HR_EPSILON proud of the front so its face is not coplanar/coincident with the body
          // front face (which would leave a triangulation seam even in a full render).
          if (chamfer_enabled)
            fwd(attachable_depth / 2 - (panel_depth + HR_EPSILON) / 2)
              color_this(debug_colors ? HR_BLUE : HR_CORE_SUPPORT_SECONDARY_COLOR)
                cuboid([HR_SPLIT_KNUCKLE_STRENGTH_SLIM, panel_depth + HR_EPSILON, attachable_height]);

          // lock pin hole: LOCK knuckles get the tension socket, MIDDLE knuckles a plain 4x4mm hole
          color_this(debug_colors ? HR_YELLOW : HR_CORE_SUPPORT_SECONDARY_COLOR)
            align(CENTER) tag("remove")
              if (knuckle_type == HR_SPLIT_KNUCKLE_TYPE_LOCK) {
                lockpin_hole_support();
              } else {
                cuboid([LOCKPIN_HOLE_SIDE_LENGTH, LOCKPIN_HOLE_SIDE_LENGTH, attachable_height + HR_EPSILON], chamfer = chamfer_enabled ? -LOCKPIN_HOLE_CHAMFER : 0, edges = [TOP, BOTTOM]);
              }
        }

    children();
  }
}

// units as in Rack Units (1U = 1.75 inches = 44.45mm),
// so units=2 means a 2U split (88.9mm)

HR_SPLIT_KNUCKLE_SIDE_ALL = "all";
HR_SPLIT_KNUCKLE_SIDE_LEFT = "left";
HR_SPLIT_KNUCKLE_SIDE_RIGHT = "right";

// a knuckle owned by `owner` is shown when the requested side is "all" or matches the owner,
// otherwise it is tagged "remove" so diff() drops it (knuckles never overlap, so nothing is carved).
function knuckle_visibility_tag(owner, knuckle_side) =
  (knuckle_side == HR_SPLIT_KNUCKLE_SIDE_ALL || knuckle_side == owner) ? "show" : "remove";

module split_connector(
  units = 1, panel_depth = BASE_STRENGTH,
  knuckle_side = HR_SPLIT_KNUCKLE_SIDE_ALL,
  anchor = CENTER, spin = 0, orient = UP,
  debug_colors = false, chamfer_enabled = true) {

  // one height unit, bottom to top: LOCK(left) - MIDDLE(right) - MIDDLE(left) - LOCK(right).
  // the stack is point-symmetric, so units just tile straight up without per-unit mirroring.
  // revised for 15mm support units
  module split_connector_1HU() {
    _g = HR_SPLIT_KNUCKLE_GAP;
    _k_h = (BASE_UNIT - 4 * _g) / 4; 

    // Determine ownership for each of the 4 knuckles
    show_0 = (knuckle_side == HR_SPLIT_KNUCKLE_SIDE_ALL || knuckle_side == HR_SPLIT_KNUCKLE_SIDE_LEFT);
    show_1 = (knuckle_side == HR_SPLIT_KNUCKLE_SIDE_ALL || knuckle_side == HR_SPLIT_KNUCKLE_SIDE_RIGHT);
    show_2 = (knuckle_side == HR_SPLIT_KNUCKLE_SIDE_ALL || knuckle_side == HR_SPLIT_KNUCKLE_SIDE_LEFT);
    show_3 = (knuckle_side == HR_SPLIT_KNUCKLE_SIDE_ALL || knuckle_side == HR_SPLIT_KNUCKLE_SIDE_RIGHT);

    tag_scope("split_connector") {
      // Knuckle 0: LOCK (Left)
      if (show_0) knuckle(HR_SPLIT_KNUCKLE_TYPE_LOCK, panel_depth = panel_depth, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
      
      // Knuckle 1: MIDDLE (Right)
      translate([0, 0, _k_h + _g])
        if (show_1) knuckle(HR_SPLIT_KNUCKLE_TYPE_MIDDLE, panel_depth = panel_depth, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
      
      // Knuckle 2: MIDDLE (Left)
      translate([0, 0, 2 * (_k_h + _g)])
        if (show_2) knuckle(HR_SPLIT_KNUCKLE_TYPE_MIDDLE, panel_depth = panel_depth, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
      
      // Knuckle 3: LOCK (Right)
      translate([0, 0, 3 * (_k_h + _g)])
        if (show_3) knuckle(HR_SPLIT_KNUCKLE_TYPE_LOCK, panel_depth = panel_depth, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
    }
  }

  attachable_width = HR_SPLIT_KNUCKLE_STRENGTH_SLIM;
  attachable_depth = HR_SPLIT_KNUCKLE_STRENGTH_SLIM;
  attachable_height = units * BASE_UNIT - TOLERANCE / 2;

  attachable(anchor = anchor, spin = spin, orient = orient, size = [attachable_width, attachable_depth, attachable_height]) {
    down(attachable_height / 2 - get_knuckle_height(HR_SPLIT_KNUCKLE_TYPE_LOCK) / 2)
      for ($idx = [0:units - 1]) {
        translate([0, 0, $idx * BASE_UNIT]) {
          split_connector_1HU(); 
        }
      }
    children();
  }
}

// the split lock pin threads vertically through the split_connector knuckle stack and locks
// the two split panel halves together (it replaces the standard lock pin for split panels).
// it reuses the core lock pin's tension grip (tension_shape + tension_hole) as its single lock
// element, seated in the bottom-most LOCK knuckle. a plain shaft then runs from the grip all the
// way up through every remaining knuckle. both extreme ends get a rounded + chamfered insertion
// tip; the leading (far) end gets a fuller rounded nose so it slides into the bores easily. the
// grip sits at one extreme end of the pin only; multi-HU pins keep that single grip and just
// extend the shaft.
HR_SPLIT_LOCKPIN_TENSION_HEIGHT = lockpin_prismoid_length * 2;  // = BASE_UNIT - BASE_STRENGTH
// short nub below the grip so its catch waist lines up with the lock knuckle socket waist
HR_SPLIT_LOCKPIN_END_EXTENSION = (BASE_UNIT - HR_SPLIT_LOCKPIN_TENSION_HEIGHT) / 2;
// bottom-nub insertion-tip fillet, clamped so the short nub below the grip can carry it
HR_SPLIT_LOCKPIN_CAP_FILLET = min(lockpin_width_outer / 3, HR_SPLIT_LOCKPIN_END_EXTENSION);
// leading (far) shaft end gets a fuller rounded nose for an easy lead-in into the knuckle bores —
// a tip that's too sharp catches hard on insertion (and can even snap the pin). the shaft is long,
// so it isn't limited by the short bottom nub like HR_SPLIT_LOCKPIN_CAP_FILLET is.
HR_SPLIT_LOCKPIN_LEAD_FILLET = lockpin_width_outer / 2;
// ...plus a deeper chamfer on that same leading end's front/back edges, so the nose tapers in the
// depth axis too. only the cap-end edges grow; the full-length side chamfers stay lockpin_chamfer.
HR_SPLIT_LOCKPIN_LEAD_CHAMFER = lockpin_height / 3;

// one tension grip (lock element core), with the flex slit removed. BASE_UNIT - BASE_STRENGTH tall.
module split_lockpin_grip(debug_colors = false, chamfer_enabled = true, anchor = CENTER, spin = 0, orient = UP) {
  attachable(anchor = anchor, spin = spin, orient = orient,
    size = [lockpin_width_inner, lockpin_height, HR_SPLIT_LOCKPIN_TENSION_HEIGHT]) {
    diff() {
      color(debug_colors ? HR_YELLOW : HR_CORE_SUPPORT_SECONDARY_COLOR) tension_shape(chamfer_enabled);
      tag("remove")
        color(debug_colors ? HR_RED : HR_CORE_SUPPORT_SECONDARY_COLOR)
          tension_hole(tension_hole_strength_multiplier = HR_CORE_LOCKPIN_TENSION_HOLE_STRENGTH_REGULAR);
    }
    children();
  }
}

// a plain pin segment whose `cap_dir` end is filleted + chamfered like a lock pin neck, while the
// opposite end stays flush so it butts against the grip. used for both the shaft (cap on TOP) and
// the short nub below the grip (cap on BOTTOM), so both extreme ends of the pin look identical.
module split_lockpin_shaft(shaft_height, cap_dir = TOP, cap_fillet = HR_SPLIT_LOCKPIN_CAP_FILLET, cap_chamfer = lockpin_chamfer, debug_colors = false, chamfer_enabled = true, anchor = CENTER, spin = 0, orient = UP) {
  shaft_size = [lockpin_width_outer, lockpin_height, shaft_height];
  attachable(anchor = anchor, spin = spin, orient = orient, size = shaft_size) {

    if (chamfer_enabled)
      // fillet + chamfer can't share an edge, so intersect the rounded nose with the chamfers.
      // the full-length side chamfers (Z edges) and the cap-end chamfer are separate cuboids so
      // the leading end can taper harder in depth without changing the side chamfers.
      intersection() {
        color_this(debug_colors ? HR_GREEN : HR_CORE_SUPPORT_SECONDARY_COLOR)
          cuboid(shaft_size, rounding = cap_fillet, edges = [cap_dir + LEFT, cap_dir + RIGHT]);
        color_this(debug_colors ? HR_WHITE : HR_CORE_SUPPORT_SECONDARY_COLOR)
          cuboid(shaft_size, chamfer = lockpin_chamfer, edges = "Z");
        color_this(debug_colors ? HR_BLUE : HR_CORE_SUPPORT_SECONDARY_COLOR)
          cuboid(shaft_size, chamfer = cap_chamfer, edges = [cap_dir + FRONT, cap_dir + BACK]);
      }
    else
      cuboid(shaft_size);
    children();
  }
}

module split_lockpin(units = 1,
  anchor = CENTER, spin = 0, orient = UP,
  debug_colors = false, chamfer_enabled = true) {

  assert(is_num(units) && units > 0, "units must be a positive number");

  total_height = units * BASE_UNIT - TOLERANCE / 2;
  // grip waist aligns with the bottom LOCK knuckle centre (BASE_UNIT/2 above the pin's bottom)
  grip_center_z = -total_height / 2 + BASE_UNIT / 2;
  // shaft spans from the grip's top out to the far (top) end of the pin
  shaft_height = total_height - (BASE_UNIT / 2 + HR_SPLIT_LOCKPIN_TENSION_HEIGHT / 2);
  // end cap additional strength
  cap_strength = 1;

  attachable(anchor = anchor, spin = spin, orient = orient,
    size = [lockpin_width_inner, lockpin_height, total_height]) {
    up(grip_center_z)
      split_lockpin_grip(debug_colors = debug_colors, chamfer_enabled = chamfer_enabled) {
        // short nub below the grip that centres it within the bottom lock knuckle; its bottom end
        // carries the same rounded + chamfered insertion tip as the shaft's top end
        attach(BOTTOM, TOP, overlap = cap_strength)
          split_lockpin_shaft(HR_SPLIT_LOCKPIN_END_EXTENSION + cap_strength, cap_dir = BOTTOM, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
        // plain shaft up through the rest of the stack; its far (leading) end carries the fuller
        // rounded nose + deeper end chamfer so it slides into the knuckle bores easily
        attach(TOP, BOTTOM)
          split_lockpin_shaft(shaft_height, cap_fillet = HR_SPLIT_LOCKPIN_LEAD_FILLET, cap_chamfer = HR_SPLIT_LOCKPIN_LEAD_CHAMFER, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
      }
    children();
  }
}
