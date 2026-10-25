// HomeRacker - Reinforced Panel
//
// Modification of `rackpanel` that uses the standard 15mm HomeRacker support unit.
// Revisions by Kythera of Anevern (using Atlassian's Rovo, because Kythera can't code).

include <../lib/truss_panel.scad>
include <../lib/truss_split.scad>

/* [General Parameters] */
// Panel width in 15mm units
width_units = 10; // [1:1:40]
// Panel height in 15mm units
height_units = 1;  // [1:1:40]
// Bore hole pattern
bore_mode = 0;  // [0:Standard (1 per unit), 1:Minimal (corners only), 2:None]

/* [Stability & Strength] */
// Panel depth (wall thickness)
panel_depth_type = 1;  // [1:Regular (2mm), 2:Strong (4mm)]
// Back-side truss stiffener (flush with split-knuckle plane)
back_brace = true;  // [false,true]
// Truss grid density for the back brace (only relevant if back_brace is on)
back_brace_density = "regular";  // [regular, dense]

/* [Advanced Parameters] */
// Split mode for rack panel — controls how the panel is split for assembly and viewing
split_mode = 0;  // [0:Full, 1:Half]
// view mode controls which sections of the panel are visible in case of a split mode selection other than full
view_mode = 0;  // [0:Assembled, 1:Half Left, 2:Half Right, 3:Exploded]

/* [Debug Parameters] */
// Show distinct colors per section for easier debugging and measurement
debug_colors = false;  // [false,true]
// Enable chamfering on edges
chamfer_enabled = true;  // [false,true]

/* [Hidden] */
$fn = 100;

panel_width = width_units * BASE_UNIT;

_panel_depth = panel_depth_type == 2 ? 4 : 2;

// Density scales with height so triangles keep a consistent size across panel heights:
// regular = 1 band per unit, dense = 2 bands per unit.
_brace_rows = back_brace_density == "regular" ? max(1, height_units) :
  back_brace_density == "dense" ? max(2, 2 * height_units) :
  die(str("Invalid back_brace_density: ", back_brace_density));

rackpanel(panel_width = panel_width, panel_height_units = height_units, bore_mode = bore_mode,
  split_mode = split_mode, view_mode = view_mode,
  panel_depth = _panel_depth,
  brace_enabled = back_brace, brace_rows = _brace_rows,
  debug_colors = debug_colors, chamfer_enabled = chamfer_enabled);
