## Overview

HEY! If you're seeing this, you're seeing my fork of the original HomeRacker repo: https://github.com/kellerlabs/homeracker

What is this for?

I wanted to try and create a version of the rackpanel part that uses the 15mm units and square holes of standard HomeRacker panels, but with the reinforcement of the rackpanel.

I used Atlassian's Rovo to help me figure out what to change. Is the code neat? I have no idea. Does it work? Yes, it at least works!

Why did I even do this? Shelf reasons. Nothing at all to do with server racks. And I wanted to use a scale I already understood (HomeRacker's 15mm standard).

## What Changed

`lib/truss_panel.scad`, `parts/truss_panel.scad`, and `lib/truss_split.scad`. 

Now you can use `truss_panel` to create "reinforced panels". The configurator has been updated for `truss_panel` to allow more than 8 height units, and the description of each variable matches the change in scale (15mm units).

<img width="1378" height="788" alt="reinforced_panel" src="https://github.com/user-attachments/assets/2eba3129-6e6b-478e-a859-8f4a47c029bc" />

## Known Issues

Split Mode: Only works if `height units` is 2 or more. A 1u height panel is too small to split.

## Etc

I am not a coder. I am patently terrible at this. I know how to describe what I want, but not how to make it happen. I rely on Rovo for that. So I'm sure there's bugs or other parts of the files that can be refined. Suggestions are more than welcome!
