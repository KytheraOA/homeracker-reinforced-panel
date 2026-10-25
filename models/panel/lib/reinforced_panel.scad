// HomeRacker - Reinforced Panel library
//
// This file is part of the HomeRacker implementation by KellerLab.
// It has been adapted from the original standard 10"/19" to the 15mm HomeRacker standard support unit grid.
// This revised version was created by Kythera of Anevern, with help from Atlassian's Rovo AI 
// (because Kythera can't code).

// Rovo's summary of the revised module hierarchy:
// Module hierarchy:
//   rackpanel        — top-level: orchestrates bore mode, chamfering, and split/assembly views
//   _panel_assembly  — internal: manages the layout of split halves and the lockpin
//   _panel_left/right— internal: manages the clipping and attachment of knuckles to halves
//   _naked_panel     — internal: the base panel body before split logic is applied
//   rackpanel_stack  — attachable unit stacker via zcopies (15mm grid aligned)
//   rackpanel_1u     — single 15mm unit panel body with bore subtraction
//   bores_1u         — standard bore pattern for a single 15mm unit
//   bores_minimal    — 2-bore pattern (top/bottom) for minimal mounting
//   rack_bore        — single M6-compatible bore shape
//   _back_brace      — optional truss_grid stiffener for the panel rear

// ==== Original HomeRacker license notice ====
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
// ==== End of original HomeRacker license notice ====

include <BOSL2/std.scad>
include <../../core/lib/constants.scad>
include <truss.scad>

RP_PRIMARY_COLOR = HR_YELLOW;
RP_SECONDARY_COLOR = HR_CHARCOAL;
RP_RACKMOUNT_BORE_WIDTH = LOCKPIN_HOLE_SIDE_LENGTH;
RP_RACKMOUNT_BORE_HEIGHT = LOCKPIN_HOLE_SIDE_LENGTH;
// narrow non-standard width purely for demoing the split feature with minimal material
RP_DEMO_WIDTH = 60;

// Back-brace stiffener (truss_grid) — see truss.scad
// Unusable strip on each side (clears the mount surfaces + bore columns). Rounded up from
// STD_MOUNT_SURFACE_WIDTH + TOLERANCE/2 (= 15.975) for a clean number.
RP_BRACE_SIDE_MARGIN = 16;
// Total knuckle depth measured from the panel front face. The brace's BACK face lands on this
// plane so it sits flush with split connectors. Mirrors split.scad's HR_SPLIT_KNUCKLE_STRENGTH_SLIM
// derivation, kept local to avoid a circular include between rackpanel.scad and split.scad.
RP_BRACE_DEPTH = (LOCKPIN_HOLE_SIDE_LENGTH + PRINTING_LAYER_WIDTH * 2) + BASE_STRENGTH * 2;  // = 8.8mm

/** Single rackmount bore
 * Rounded rectangular slot sized for M6 screws (10mm × 6.5mm).
 */
module rack_bore(panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  bore_dimensions = [RP_RACKMOUNT_BORE_WIDTH, panel_depth + HR_EPSILON, RP_RACKMOUNT_BORE_HEIGHT];
  attachable(anchor, spin, orient, size = bore_dimensions) {
    color(debug_colors ? HR_RED : RP_PRIMARY_COLOR)
      cuboid(bore_dimensions, rounding = 0.5, except = [FRONT, BACK]);
    children();
  }
}

/** Bores for 1U rackmount
 * Evenly spaced rack bores for a single unit, per standard measurements.
 *   bore_count=3: standard pattern (top, middle, bottom)
 *   bore_count=2: outer bores only (top, bottom)
 *   bore_count=1: middle bore only
 */
module bores_1u(bore_count = 3, panel_depth = BASE_STRENGTH,
  debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {

  assert(is_int(bore_count) && bore_count >= 1 && bore_count <= 3, "Bore count must be an integer between 1 and 3");

  width = RP_RACKMOUNT_BORE_WIDTH;
  depth = panel_depth;
  height = RP_RACKMOUNT_BORE_HEIGHT + (bore_count - 1) * BASE_UNIT;
  attachable_dimensions = [width, depth, height];
  attachable(anchor, spin, orient, size = attachable_dimensions) {
    zcopies(spacing = BASE_UNIT, n = bore_count)
      rack_bore(panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

/** Single 1U rack panel body
 * Flat panel (1U height × panel_width) with bore holes subtracted.
 * Does NOT apply chamfers — chamfering is handled at the rackpanel level.
 * Used as the building block for rackpanel_stack.
 */
module rackpanel_1u(panel_width = BASE_UNIT, bore_count = 3, panel_depth = BASE_STRENGTH,
  debug_colors = false,
  anchor = CENTER, spin = 0, orient = UP) {

  panel_height = BASE_UNIT; // Changed to 15mm HomeRacker core support units
  panel_dimensions = [panel_width, panel_depth, panel_height];

  tag_scope("rackpanel_1u")
    attachable(anchor, spin, orient, size = panel_dimensions) {
      color_this(debug_colors ? HR_BLUE : RP_PRIMARY_COLOR)
        diff()
          cuboid(panel_dimensions) {
            if (bore_count > 0)
              tag("remove") align(CENTER, [LEFT, RIGHT], inside = true, inset = (BASE_UNIT - RP_RACKMOUNT_BORE_WIDTH) / 2)
                bores_1u(bore_count = bore_count, panel_depth = panel_depth, debug_colors = debug_colors);
          }
      children();
    }
}

// Bore modes — control how many bores per unit
RP_BORE_MODE_DEFAULT = 0;  // 1 hole per 15mm unit
RP_BORE_MODE_MINIMAL = 1;  // 2 holes total (top + bottom corners)
RP_BORE_MODE_NONE    = 2;  // No holes (2U+)

/** Returns uniform bore count for a given mode and panel height.
 * For MINIMAL, rackpanel handles bores separately via bores_minimal (returns 0 here).
 */
function get_bore_count_per_unit(bore_mode, panel_height_units) =
  bore_mode == RP_BORE_MODE_DEFAULT ? 1 : 0; 

/** Rack panel unit stack
 * Stacks rackpanel_1u units via a single zcopies call.
 * Pure stacker — no bore mode logic, no chamfering.
 * Attachable — exposes $parent_size so children (e.g. edge_mask) work as expected.
 */
module rackpanel_stack(panel_width = BASE_UNIT, panel_height_units = 1, bore_count = 3, panel_depth = BASE_STRENGTH,
  debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {

  panel_dimensions = [panel_width, panel_depth, panel_height_units * BASE_UNIT];

  attachable(anchor, spin, orient, size = panel_dimensions) {
    zcopies(spacing = BASE_UNIT, n = panel_height_units)
      rackpanel_1u(panel_width = panel_width, bore_count = bore_count, panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

/** Bores for minimal rackmount pattern
 * Places bores at top + bottom unit centers only.
 *   1U: 1 bore at center
 *   2U+: 2 bores (top + bottom unit centers)
 * Sibling module to bores_1u — same interface, different spacing strategy.
 */
module bores_minimal(panel_height_units, panel_depth = BASE_STRENGTH,
  debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {

  assert(is_int(panel_height_units) && panel_height_units >= 1, "panel_height_units must be a positive integer");
  bore_spacing = (panel_height_units - 1) * BASE_UNIT;
  n = panel_height_units == 1 ? 1 : 2;
  width = RP_RACKMOUNT_BORE_WIDTH;
  height = RP_RACKMOUNT_BORE_HEIGHT + bore_spacing;
  attachable_dimensions = [width, panel_depth, height];

  attachable(anchor, spin, orient, size = attachable_dimensions) {
    zcopies(spacing = bore_spacing, n = n)
      rack_bore(panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

HR_RP_SPLIT_FULL = 0;
HR_RP_SPLIT_HALF = 1;

HR_RP_VIEW_ASSEMBLY = 0;
HR_RP_VIEW_HALF_LEFT = 1;
HR_RP_VIEW_HALF_RIGHT = 2;
HR_RP_VIEW_EXPLOSION = 3;

/** Usable keystone-band width for a rack panel face (mm).
 * Excludes the rackmount mount-surface column on each outer edge plus a half-tolerance
 * slide-in clearance per outer edge. On a split half the seam (inner) edge has no mount
 * column, but the split-connector knuckle occupies the centre, so the band stops at the
 * naked-panel edge (its half of the knuckle, HR_SPLIT_KNUCKLE_STRENGTH_SLIM/2). The two
 * halves' bands therefore leave the knuckle uncovered in the middle; a cutout pass should
 * overlap that edge by HR_EPSILON to stay manifold. Pair with get_rackpanel_usable_x() to
 * centre cutouts (e.g. keystone pockets) in the band.
 *   full:  panel_width - 2*STD_MOUNT_SURFACE_WIDTH - TOLERANCE                              (centred)
 *   half:  panel_width/2 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM/2 - BASE_UNIT - TOLERANCE/2
 * split_mode=Half is only meaningful per half (view_mode Half-Left/Half-Right). The
 * assembled/exploded views have no single usable band, so they warn and fall back to the
 * full-panel band (which will NOT fit a half) — distribute content per half instead.
 */
function get_rackpanel_usable_width(panel_width, split_mode = HR_RP_SPLIT_FULL, view_mode = HR_RP_VIEW_ASSEMBLY) =
  let(_full_band = panel_width - 2 * BASE_UNIT - TOLERANCE)
  (split_mode == HR_RP_SPLIT_HALF && (view_mode == HR_RP_VIEW_HALF_LEFT || view_mode == HR_RP_VIEW_HALF_RIGHT))
  ? panel_width / 2 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 2 - BASE_UNIT - TOLERANCE / 2
  : split_mode == HR_RP_SPLIT_HALF
  ? echo("⚠️ get_rackpanel_usable_width: split_mode=Half needs view_mode=Half-Left/Half-Right; the assembled/exploded views have no single usable band. Falling back to the full-panel band, which will NOT fit a half.") _full_band
  : _full_band;

/** X offset of the usable band centre from the (half-)panel attachable centre (mm).
 * Full panels are symmetric (0). A split half pins the band's seam edge on its naked-panel
 * edge (the split-connector knuckle boundary), so the band centre shifts toward the seam by
 * half the deducted outer column + clearance, less half the knuckle cutout. Left half shifts
 * +X (seam on its right); right half shifts -X. panel_width is accepted for API symmetry with
 * get_rackpanel_usable_width() (the offset is width-independent). As with usable_width,
 * split_mode=Half with a non-half view is undefined: it warns and returns 0 (panel centre).
 */
function get_rackpanel_usable_x(panel_width, split_mode = HR_RP_SPLIT_FULL, view_mode = HR_RP_VIEW_ASSEMBLY) =
  (split_mode == HR_RP_SPLIT_HALF && view_mode == HR_RP_VIEW_HALF_LEFT)
  ? BASE_UNIT / 2 + TOLERANCE / 4 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 4
: -(BASE_UNIT / 2 + TOLERANCE / 4 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 4)
  ? -(STD_MOUNT_SURFACE_WIDTH / 2 + TOLERANCE / 4 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 4)
  : split_mode == HR_RP_SPLIT_HALF
  ? echo("⚠️ get_rackpanel_usable_x: split_mode=Half needs view_mode=Half-Left/Half-Right; returning 0 (panel centre).") 0
  : 0;

/** Rack panel (top-level module)
 * Assembles a complete rack panel with configurable height, bore mode, and chamfering.
 * Orchestrates:
 *   - rackpanel_stack for unit stacking
 *   - bores_minimal subtracted as children (MINIMAL mode)
 *   - edge_mask + chamfer_edge_mask for outer chamfers
 *   - optional back-side truss stiffener (brace_enabled), flush with the split-knuckle plane
 */
module rackpanel(panel_width = BASE_UNIT, panel_height_units = 1, bore_mode = RP_BORE_MODE_DEFAULT,
  split_mode = HR_RP_SPLIT_FULL, view_mode = HR_RP_VIEW_ASSEMBLY,
  panel_depth = BASE_STRENGTH,
  brace_enabled = true, brace_rows = 2, // turns braces on by default instead of off
  debug_colors = false, chamfer_enabled = true,
  anchor = CENTER, spin = 0, orient = UP) {

  assert(is_int(panel_height_units) && panel_height_units >= 1, "panel_height_units must be a positive integer");
  assert(bore_mode >= RP_BORE_MODE_DEFAULT && bore_mode <= RP_BORE_MODE_NONE, "bore_mode must be 0 (Standard), 1 (Minimal), or 2 (None)");
  assert(is_num(panel_depth) && panel_depth >= BASE_STRENGTH, str("panel_depth must be a number >= ", BASE_STRENGTH, "mm"));
  attachable_height = panel_height_units * BASE_UNIT;
  panel_dimensions = [panel_width, panel_depth, attachable_height];
  // sink depth that seats the lock pin flush with the panel top (matches split_lockpin total height)
  lockpin_seat = attachable_height - TOLERANCE / 2;
  bore_count = get_bore_count_per_unit(bore_mode, panel_height_units);
  // The brace sits behind the panel back face and protrudes to the knuckle plane; it only
  // earns its place when at least a rib's worth of depth is available there.
  brace_active = brace_enabled && (RP_BRACE_DEPTH - panel_depth) >= BASE_STRENGTH;
  brace_depth = RP_BRACE_DEPTH - panel_depth;  // protrusion from the panel back to the knuckle plane

  module _naked_panel() {
    tag_scope("rackpanel")
      attachable(CENTER, 0, UP, size = panel_dimensions) {
        diff()
          rackpanel_stack(panel_width = panel_width, panel_height_units = panel_height_units,
            bore_count = bore_count, panel_depth = panel_depth, debug_colors = debug_colors) {
            if (bore_mode == RP_BORE_MODE_MINIMAL)
              tag("remove") align(CENTER, [LEFT, RIGHT], inside = true, inset = (BASE_UNIT - RP_RACKMOUNT_BORE_WIDTH) / 2)
              bores_minimal(panel_height_units = panel_height_units, panel_depth = panel_depth, debug_colors = debug_colors);
            if (chamfer_enabled)
              color_this(debug_colors ? HR_GREEN : RP_PRIMARY_COLOR)
                edge_mask(FRONT)
                  chamfer_edge_mask(chamfer = BASE_CHAMFER);
          }
        children();
      }
  }

  split_connector_width = HR_SPLIT_KNUCKLE_STRENGTH_SLIM;
  split_connector_cutout = split_connector_width / 2;
  attachable_width_half_naked = panel_width / 2 - split_connector_cutout;
  attachable_width_half = attachable_width_half_naked + split_connector_width / 2;
  // left_half/right_half size their masking cube on ALL axes, so it must clear the panel's
  // full bounding box (otherwise a tall, narrow panel like the demo width clips to the width).
  split_clip_size = 2 * max(panel_width, attachable_height);

  // Back-side truss stiffener. Emits one framed truss field, offset by `x_offset` and with the
  // diagonals flipped by `mirror_lattice` (so split halves read as a mirrored pair). The caller
  // attaches it to the panel back, so it also works standalone. tag_scope("brace") keeps the
  // truss's own chamfer tags from leaking into an enclosing panel diff().
  module _back_brace(field_width, x_offset = 0, mirror_lattice = true) {
    if (field_width > 2 * BASE_STRENGTH)
      tag_scope("brace")
        right(x_offset)
          scale([mirror_lattice ? -1 : 1, 1, 1])
            color_this(debug_colors ? HR_GREEN : RP_PRIMARY_COLOR)
              truss_grid(size = [field_width, brace_depth, attachable_height], rows = brace_rows,
                chamfer_enabled = chamfer_enabled, anchor = FRONT);
  }

  module _naked_panel_left() {
    attachable(size = [attachable_width_half_naked, panel_depth, attachable_height]) {
      right(attachable_width_half_naked / 2 + split_connector_cutout)
        color(debug_colors ? HR_GREEN : RP_PRIMARY_COLOR)
          // Clip exactly at the knuckle boundary
          left_half(s = split_clip_size, x = -split_connector_cutout) _naked_panel();
      children();
    }
  }

  module _naked_panel_right() {
    attachable(size = [attachable_width_half_naked, panel_depth, attachable_height]) {
      left(attachable_width_half_naked / 2 + split_connector_cutout)
        color(debug_colors ? HR_RED : RP_PRIMARY_COLOR)
          // Clip exactly at the knuckle boundary
          right_half(s = split_clip_size, x = split_connector_cutout) _naked_panel();
      children();
    }
  }

  module _panel_left() {
    left(split_connector_width / 4)
      _naked_panel_left() {
        align(RIGHT, FRONT)
          diff()
            split_connector(units = panel_height_units, panel_depth = panel_depth,
              knuckle_side = HR_SPLIT_KNUCKLE_SIDE_LEFT,
              debug_colors = debug_colors, chamfer_enabled = chamfer_enabled) {
            }
        if (brace_active)
          attach(BACK, FRONT, overlap = -HR_EPSILON)
            _back_brace(attachable_width_half_naked - RP_BRACE_SIDE_MARGIN + HR_EPSILON, x_offset = -RP_BRACE_SIDE_MARGIN / 2 + HR_EPSILON / 2);
      }
  }

  module _panel_right() {
    right(split_connector_width / 4)
      _naked_panel_right() {
        align(LEFT, FRONT)
          diff()
            split_connector(units = panel_height_units, panel_depth = panel_depth,
              knuckle_side = HR_SPLIT_KNUCKLE_SIDE_RIGHT,
              debug_colors = debug_colors, chamfer_enabled = chamfer_enabled) {
            }
        if (brace_active)
          attach(BACK, FRONT, overlap = -HR_EPSILON)
            _back_brace(attachable_width_half_naked - RP_BRACE_SIDE_MARGIN + HR_EPSILON, x_offset = RP_BRACE_SIDE_MARGIN / 2 - HR_EPSILON / 2, mirror_lattice = true);
      }
  }

  module _panel_assembly(explode = false) {
    gap = explode ? HR_SPLIT_KNUCKLE_STRENGTH_SLIM : 0;
    offset = attachable_width_half / 2 + gap;

    attachable(size = [panel_width + 2*gap, HR_SPLIT_KNUCKLE_STRENGTH_SLIM, attachable_height]) {
      union() {
        left(offset) _panel_left();
        right(offset) _panel_right();
      }
      union() { children(); }
    }
  }

  // Views that accept external children (e.g. a diff("keystone") cutout pass) share one outer
  // attachable so children attach OUTSIDE _naked_panel's tag_scope (otherwise their remove tags
  // get scoped away and never cut) and so anchor/spin/orient apply uniformly. Width is the only
  // view-dependent dimension; the union() merges the single active branch into one shape node.
  
  // Logic: Only show the full panel if we are NOT in a split view.
  if (split_mode == HR_RP_SPLIT_FULL) {
    attachable(anchor, spin, orient, size = panel_dimensions) {
      _naked_panel()
        if (brace_active)
          attach(BACK, FRONT, overlap = -HR_EPSILON) // Added epsilon to stop Z-fighting
            _back_brace(panel_width - 2 * RP_BRACE_SIDE_MARGIN);
      children();
    }
  } else {
    // We are in a Split Mode (Half-Left, Half-Right, Assembly, or Explosion)
    if (view_mode == HR_RP_VIEW_HALF_LEFT) {
      attachable(anchor, spin, orient, size = [attachable_width_half, panel_depth, attachable_height]) {
        _panel_left();
        children();
      }
    } else if (view_mode == HR_RP_VIEW_HALF_RIGHT) {
      attachable(anchor, spin, orient, size = [attachable_width_half, panel_depth, attachable_height]) {
        _panel_right();
        children();
      }
    } else if (view_mode == HR_RP_VIEW_ASSEMBLY) {
      _panel_assembly(explode = false)
        attach(TOP, TOP, overlap = lockpin_seat)
          split_lockpin(units = panel_height_units, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
    } else if (view_mode == HR_RP_VIEW_EXPLOSION) {
      _panel_assembly(explode = true)
        attach(TOP, TOP, overlap = -BASE_STRENGTH)
          split_lockpin(units = panel_height_units, debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
    }
  }
} 