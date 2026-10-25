## Overview

HEY! If you're seeing this, you're seeing my fork of the original HomeRacker repo: https://github.com/kellerlabs/homeracker

What is this for?

I wanted to try and create a version of the `rackpanel` part that uses the 15mm units and square holes of standard HomeRacker panels, but keeping the reinforcement elements of the `rackpanel`.

I used Atlassian's Rovo to help me figure out what to change. Is the code neat? I have no idea. Does it work? Yes, it at least works! That is, I have successfully rendered and exported some STL files and the slicer didn't explode when I imported them.

Why did I even do this? 

Shelf-ish reasons. Nothing at all to do with server racks. My sense of scale is inordinately defective for an artist and I'm horrible at math. I wanted to try and create an easy-to-customize version that matched the scale I was already using (HomeRacker's 15mm standard). And I didn't want to have to throw myself on the kindness of strangers to do it (and I have a penchant for learning things the hard way).

## What Changed

`lib/reinforced_panel.scad`, `parts/reinforcedpanel.scad`, and `lib/reinforced_split.scad`. 

Now you can use `reinforced_panel` to create "reinforced panels". The configurator has been updated for `reinforced_panel` to allow more than 8 height units, and the description of each variable matches the change in scale (15mm units).

<img width="1378" height="788" alt="reinforced_panel" src="https://github.com/user-attachments/assets/2eba3129-6e6b-478e-a859-8f4a47c029bc" />

## Known Issues

Split Mode: Only works if `height units` is 2 or more. A 1u height panel is too small to split and OpenSCAD just NOPEs out.

## Etc.

I am not a coder. I am patently terrible at this. I know how to describe what I want, but not how to make it happen. I rely on Rovo for that. 

I'm also sure I haven't followed a single one of the guidelines for contributing, for which I apologize. At the same time, I'm not _entirely_ sorry because my primary goal was to just get a working MVP _for myself_. I hadn't planned on sharing it, but creating a fork and storing my new Franken-files in the forked repo so I don't lose them seemed like a good idea. If I print one of these reinforced panels and they _actually_ work as intended, _then_ I'll see about making this mess compliant as a "real" community contribution.

That said, if you, gentle reader, have stumbled on this repo by chance, I am defintely open to suggestions, recommendations, etc. I really have _no idea what I'm doing_. I'm a technical writer/artist/quality assurance veteran who MacGyvered something with determination, a prayer, and not much else.