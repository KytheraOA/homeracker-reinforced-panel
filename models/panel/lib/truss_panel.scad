// HomeRacker - Rack panel library (truss_panel.scad version)
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
include <truss_split.scad>

RP_PRIMARY_COLOR = HR_YELLOW;
RP_SECONDARY_COLOR = HR_CHARCOAL;
RP_RACKMOUNT_BORE_WIDTH = LOCKPIN_HOLE_SIDE_LENGTH;
RP_RACKMOUNT_BORE_HEIGHT = LOCKPIN_HOLE_SIDE_LENGTH;

RP_BRACE_SIDE_MARGIN = 16;
RP_BRACE_DEPTH = (LOCKPIN_HOLE_SIDE_LENGTH + PRINTING_LAYER_WIDTH * 2) + BASE_STRENGTH * 2;

module rack_bore(panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  bore_dimensions = [RP_RACKMOUNT_BORE_WIDTH, panel_depth + HR_EPSILON, RP_RACKMOUNT_BORE_HEIGHT];
  attachable(anchor, spin, orient, size = bore_dimensions) {
    color(debug_colors ? HR_RED : RP_PRIMARY_COLOR)
      cuboid(bore_dimensions, rounding = 0.5, except = [FRONT, BACK]);
    children();
  }
}

module bores_1u(bore_count = 3, panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  width = RP_RACKMOUNT_BORE_WIDTH;
  height = RP_RACKMOUNT_BORE_HEIGHT + (bore_count - 1) * BASE_UNIT;
  attachable(anchor, spin, orient, size = [width, panel_depth, height]) {
    zcopies(spacing = BASE_UNIT, n = bore_count)
      rack_bore(panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

module rackpanel_1u(panel_width = BASE_UNIT, bore_count = 3, panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  panel_height = BASE_UNIT;
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

module rackpanel_stack(panel_width = BASE_UNIT, panel_height_units = 1, bore_count = 3, panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  panel_dimensions = [panel_width, panel_depth, panel_height_units * BASE_UNIT];
  attachable(anchor, spin, orient, size = panel_dimensions) {
    zcopies(spacing = BASE_UNIT, n = panel_height_units)
      rackpanel_1u(panel_width = panel_width, bore_count = bore_count, panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

module bores_minimal(panel_height_units, panel_depth = BASE_STRENGTH, debug_colors = false, anchor = CENTER, spin = 0, orient = UP) {
  bore_spacing = (panel_height_units - 1) * BASE_UNIT;
  n = panel_height_units == 1 ? 1 : 2;
  attachable(anchor, spin, orient, size = [RP_RACKMOUNT_BORE_WIDTH, panel_depth, RP_RACKMOUNT_BORE_HEIGHT + bore_spacing]) {
    zcopies(spacing = bore_spacing, n = n)
      rack_bore(panel_depth = panel_depth, debug_colors = debug_colors);
    children();
  }
}

module rackpanel(panel_width = BASE_UNIT, panel_height_units = 1, bore_mode = 0, split_mode = 0, view_mode = 0, panel_depth = BASE_STRENGTH, brace_enabled = true, brace_rows = 2, debug_colors = false, chamfer_enabled = true, anchor = CENTER, spin = 0, orient = UP) {
  
  attachable_height = panel_height_units * BASE_UNIT;
  panel_dimensions = [panel_width, panel_depth, attachable_height];
  brace_depth = RP_BRACE_DEPTH - panel_depth;
  lockpin_seat = attachable_height - TOLERANCE / 2;

  module _naked_panel() {
    attachable(CENTER, 0, UP, size = panel_dimensions) {
      diff()
        rackpanel_stack(panel_width = panel_width, panel_height_units = panel_height_units, bore_count = (bore_mode == 0 ? 1 : 0), panel_depth = panel_depth, debug_colors = debug_colors) {
          if (bore_mode == 1) tag("remove") align(CENTER, [LEFT, RIGHT], inside = true, inset = (BASE_UNIT - RP_RACKMOUNT_BORE_WIDTH) / 2) bores_minimal(panel_height_units);
          if (chamfer_enabled) edge_mask(FRONT) chamfer_edge_mask(chamfer = BASE_CHAMFER);
        }
      children();
    }
  }

  module _panel_left() {
    w_half = panel_width / 2 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 2;
    left(HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 4)
      attachable(size = [w_half, panel_depth, attachable_height]) {
        left_half() _naked_panel();
        align(RIGHT, FRONT) split_connector(units = panel_height_units, knuckle_side = "left", debug_colors = debug_colors);
        children();
      }
  }

  module _panel_right() {
    w_half = panel_width / 2 - HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 2;
    right(HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 4)
      attachable(size = [w_half, panel_depth, attachable_height]) {
        right_half() _naked_panel();
        align(LEFT, FRONT) split_connector(units = panel_height_units, knuckle_side = "right", debug_colors = debug_colors);
        children();
      }
  }

  if (split_mode == 0) {
    attachable(anchor, spin, orient, size = panel_dimensions) {
      _naked_panel();
      children();
    }
  } else {
    gap = (view_mode == 3) ? HR_SPLIT_KNUCKLE_STRENGTH_SLIM : 0;
    offset = (panel_width / 4 + HR_SPLIT_KNUCKLE_STRENGTH_SLIM / 8) + gap;
    
    attachable(anchor, spin, orient, size = [panel_width + 2*gap, panel_depth, attachable_height]) {
      union() {
        if (view_mode != 2) left(offset) _panel_left();
        if (view_mode != 1) right(offset) _panel_right();
        if (view_mode == 0 || view_mode == 3) {
           z_off = (view_mode == 3) ? -BASE_STRENGTH : lockpin_seat - attachable_height/2;
           up(z_off) split_lockpin(units = panel_height_units, debug_colors = debug_colors);
        }
      }
      children();
    }
  }
}