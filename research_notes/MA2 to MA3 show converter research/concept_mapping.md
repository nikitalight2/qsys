# grandMA2 → grandMA3 concept and data-model mapping (programming data model)

Research context / caveats for the report writer:
- The MA Lighting help sites (help.malighting.com, help2.malighting.com), forum.malighting.com, consoletrainer.com and several mirror sites were **not fully readable at research time**. All manual-derived facts below therefore come from search-engine result summaries that quote the manual pages (URL given), not from full page reads. Verbatim quotes are as returned by the search engine; wording differs across manual versions (MA3 1.0–2.5, MA2 3.9). Treat exact column/option labels as "verify against the manual for your version".
- "Documented" = MA Lighting manual/release-notes page. "Community" = forum, blog, training vendor, third-party repo. "Inference" = my reasoning from documented facts.
- Headline finding for a converter project: **MA Lighting already ships an official one-way converter** ("Save as grandMA3" in grandMA2 onPC 3.9 / Mode2), whose documented scope and documented limitations are the best available statement of what maps 1:1 and what does not (see Q10). A third-party converter's value is in the gaps that page lists (macro syntax, embedded presets, non-simple effects, remotes, Xkeys 5/6/15/16, executors without sequences).

---

## Q1. Patch: fixture/channel IDs vs FID/CID, fixture types vs GDTF, DMX modes, universes, stages, multi-instance fixtures

### Takeaway
MA2 has two parallel ID spaces (Fixture ID and Channel ID) per fixture; MA3 generalises this to a primary FID plus optional CID drawn from eight ID types (Fixture, Channel + six renamable), with subfixtures addressed as `parent.sub`. MA3 fixture types are GDTF-based and MA2 fixture types can be converted/imported, but community reports say conversion loses fixture-type detail (XYZ/Pan-Tilt behaviour) and 3D positions.

### Cited Findings
- MA3: "A fixture has a primary ID called the FID, and can optionally have a second ID, the CID, which can be another ID type. A fixture needs at least one ID so we can select and ultimately control it." — [grandMA3 2.5 QSG First Patch](https://help.malighting.com/grandMA3/2.5/HTML/qsg_first_patch.html) (documented)
- MA3: "Every fixture patched in the showfile must have a unique FID, CID, or both." — [grandMA3 2.5 QSG First Patch](https://help.malighting.com/grandMA3/2.5/HTML/qsg_first_patch.html) (documented)
- MA3 ID types: "There are eight different types that we can use. Two of those are Fixture and Channel. The other six can be renamed to match our needs." — [grandMA3 2.5 QSG First Patch](https://help.malighting.com/grandMA3/2.5/HTML/qsg_first_patch.html) (documented)
- MA3 subfixtures: "If a fixture contains sub-fixtures, these IDs will be the fixture number, a dot, and a sub-number." Selecting the parent ID alone selects only the parent; "if the main and all the subfixtures need to be selected, then you need to select '17.'" — [grandMA3 2.1 Fixture Sheet](https://help.malighting.com/grandMA3/2.1/HTML/operate_fixture_sheet.html) (documented)
- MA3 patch columns: in Full mode the patch shows additional elements "ID Type, CID, Layer, and Class". — [grandMA3 2.4 Patch Add Fixtures](https://help2.malighting.com/grandMA3/2.4/HTML/patch_add_fixtures.html) (documented; "Class" is named but not explained in the snippet)
- MA3 positioning: fixtures can be positioned from Live Patch or the 3D window; "The zero point is 0.000m for all three position axis (X, Y, and Z) and 0.0° for all three rotation axis." X = stage left/right (positive = stage left), Y = downstage/upstage, Z = height; a Stage/Object axis setting chooses world vs local axes. — [grandMA3 1.0 Position Fixtures](https://help2.malighting.com/Page/grandMA3/patch_position_fixtures/en/1.0) (documented)
- MA3 MVR: "MVR is a file format that is used to share data for a stage set up between a lighting console, a visualizer, a CAD program or similar tools. It is a complementary system to the GDTF files." Importing an MVR "can add Layers, Classes, stage elements, or fixtures." — [grandMA3 2.5 Patch MVR](https://help.malighting.com/grandMA3/2.5/HTML/patch_mvr.html) (documented)
- MA3 fixture-type import sources: "fixture types can be imported from grandMA3 fixtures, converted grandMA2 fixtures, and GDTF-format fixtures". — [grandMA3 1.7 Import Fixture Types (PDF)](https://help2.malighting.com/Media/TopicPdf/77273/40) (documented)
- MA3 GDTF: "A GDTF file is a zip archive containing a description, geometry data, and gobo images"; onPC default GDTF folder is `MALightingTechnology/gma3_library/fixturetypes/gdtf`. — [grandMA3 2.4 Import GDTF](https://help2.malighting.com/grandMA3/2.4/HTML/ft_import_gdtf.html) (documented)
- MA3 attribute structure: attributes sit inside features, features inside feature groups; each attribute definition "has a unique name and a display name, and it can be a sub-attribute of a main attribute. Attributes are organized in Activation Groups, Feature Groups, and Deactivation Groups." — [grandMA3 2.1 Attribute Definitions](https://help.malighting.com/grandMA3/2.1/HTML/patch_attribute_definitions.html) (documented)
- MA3 capacity: "all the 1024 DMX universes are listed in the DMX Universes menu"; a maximum of "250 000 parameters in a grandMA3 session"; max 15 processing units. — [grandMA3 2.3 DMX Universe](https://help.malighting.com/grandMA3/2.3/HTML/patch_dmx_universe.html); [grandMA3 1.0 Parameter Expand](https://help2.malighting.com/Page/grandMA3/system_parameter_expand/en/1.0) (documented)
- MA3 brochure: native grandMA3 "adds features such as a tree structure for fixtures and the ability to import the complete Patch using MVR (my virtual rig)". — [grandMA3 brochure 2018 (PDF)](https://www.sgssistemas.lv/uploads/resources/126/en/ma-grandma3-brochure-eng-v2-2-07052018-72dpi-1.pdf) (vendor marketing)
- Community: after conversion of a long-running MA2 show "lot of informations are missing like patch, references of presets, strange kind of some fixturetype"; converted show "lost most of its fixture types"; "P/T fixture types lost their proper XYZ behavior after conversion". — [MA forum: switch from gMA2 to gMA3 – which way?](https://forum.malighting.com/forum/thread/69773-switch-from-gma2-to-gma3-which-way/) (community)
- Community: converted show whose fixtures did not appear in 3D; reply asked whether fixtures "were still at 0/0/0 XYZ coordinates". — [MA forum: MA2 converter to MA3 3D (June 2026)](https://forum.malighting.com/forum/thread/69940-ma2-converter-to-ma3-3d/) (community)
- Community: custom MA2 fixtures (Fixture Share) "had to be patched in grandMA2 and then saved as grandMA3 before they could be used"; the MA2 and MA3 folder names under ProgramData differ slightly, making exported files hard to find. — [MA forum: converted fixture type files](https://forum.malighting.com/forum/thread/7635-where-do-i-find-converted-grandma3-fixture-type-files-when-exporting-show-from-g/) (community)
- Community: "Exporting the patch to grandMA3 and loading it as a show is a common way to bring fixtures across"; "there is no possibility to merge it into an existing grandMA3 show." — [MA forum: grandMA2 fixture type import](https://forum.malighting.com/forum/thread/4039-grandma2-fixture-type-import/) (community)
- Community: attributes defined in the GDTF web builder "do not correspond to the attributes in the fixturetype, which then show up as NoFeature in MA". — [MA forum: Create GrandMA2 & MA3 fixtures with AI](https://forum.malighting.com/forum/thread/69765-revolution-in-patching-create-grandma2-ma3-fixtures-with-ai/) (community)

### Inferences
- Mapping: MA2 Fixture ID → MA3 FID with IDType=Fixture; MA2 Channel ID → MA3 CID with IDType=Channel (both ID spaces exist in both systems; MA3 adds six more renamable ID types with no MA2 equivalent).
- MA2 multi-instance fixtures (e.g., LED bars with per-cell instances) most plausibly map to MA3 parent fixture + subfixtures `N.1…N.k`; the MA3 "17." syntax (parent plus all subs) has no exact MA2 analogue. Not verified against the converter's actual behaviour.
- MA2 fixture-type XML must be converted into an MA3 fixture type (GDTF-like, with geometry); a converter cannot simply carry MA2 DMX-mode tables across because MA3 attribute definitions (Activation/Feature/Deactivation groups, physical units such as Angle for gobo index) differ. Community reports of lost XYZ/Pan-Tilt behaviour are consistent with geometry data being absent from MA2 fixture types.
- MA3 "Stage", "Layer", "Class" are patch-organisation objects that have no direct MA2 counterpart (MA2 has only layers in the patch); a converter would place everything on a default stage/layer.

### Gaps
- No reachable page explained MA3 "Class" or "Stage" objects in detail, nor DMX-mode selection during MA2→MA3 fixture conversion.
- Exact MA3 universe/parameter limits vs MA2 limits (MA2 figures were not found in any source; 256 universes / 65,536 parameters in the brief could not be confirmed).

---

## Q2. Groups, selection order, MA3 selection grid (X/Y/Z) and MAtricks vs MA2 MAtricks

### Takeaway
MA2 selections are strictly linear (order of selection) and MAtricks works on that line with Interleave/Block/Group/Wings; MA3 stores selections in a 3-D grid (X/Y/Z) and MAtricks operates per axis with Blocks, Groups, Wings, Width, Shuffle and phase/fade/delay-from-X. A linear MA2 group maps onto an MA3 group with selection only along X, which the MA3 manual and forum confirm as the "linear" case.

### Cited Findings
- MA3 grid: "The MA3 selection grid is a 3D grid where each fixture is a box. The grid organizes the fixtures in relation to each other but not necessarily their position in the 3D Viewer." — [grandMA3 2.2 Selection Grid](https://help.malighting.com/grandMA3/2.2/HTML/operate_selection.html) (documented)
- MA3: "MAtricks X, Y, and Z directions are relative to the entire range of selected fixtures." — [grandMA3 2.2 Selection Grid](https://help.malighting.com/grandMA3/2.2/HTML/operate_selection.html) (documented)
- MA3: "If the fixtures are in a 3-dimensional grid selection, then the MAtricks tool can be used in all three dimensions." Axis sections are coloured red (X), blue (Y), green (Z). — [grandMA3 2.0 MAtricks](https://help.malighting.com/grandMA3/2.0/HTML/matricks.html) (documented)
- MA3 Blocks: "if the block is increased to five, there are only two boxes in the grid, X = 1 and XBlock = 5." — [grandMA3 2.1 MAtricks Block](https://help.malighting.com/grandMA3/2.1/HTML/matricks_block.html) (documented)
- MA3 Groups: "The first fixture goes into the first group, the second fixture into the next group, the third fixture in the first group, and so on until there are no more fixtures." — [grandMA3 2.2 MAtricks Group](https://help.malighting.com/grandMA3/2.2/HTML/matricks_group.html) (documented)
- MA3 Wings: selection split into N wings, "Turning the X value changes how the highlighted selection moves relative to the centre of the selection." — [grandMA3 2.1 MAtricks Wings](https://help.malighting.com/grandMA3/2.1/HTML/matricks_wings.html) (documented)
- MA3 Width vs Groups: "groups place the grouped fixtures in the same grid positions where width moves the fixtures out on the next axis." — [grandMA3 2.3 MAtricks Width](https://help2.malighting.com/grandMA3/2.3/HTML/matricks_width.html) (documented)
- MA3 Shuffle: "Each shuffle setting per axis can be set to 0 (=None) up to 32 767. Each value represents a different shuffled selection order." Shuffle is stored in MAtricks pool objects. "When deactivating or resetting the MAtricks, the original selection order will be restored." — [grandMA3 2.5 MAtricks](https://help.malighting.com/grandMA3/2.5/HTML/matricks.html) (documented)
- MA3 groups store grid-cursor behaviour: "Move Grid Cursor 2D/3D Selection will enable Move Grid Cursor in the stored group, given the Selection Grid has a selection in at least two dimensions." — [grandMA3 2.0 MAtricks](https://help.malighting.com/grandMA3/2.0/HTML/matricks.html) (documented)
- MA2 MAtricks: "Interleave … defines the interval"; Y-axis settings "Single Y, Block Y, Align Group Y – are enabled only if the interleave is applied." — [grandMA2 MAtricks Toolbar](https://help.malighting.com/grandMA2/en/help/key_matricks_toolbar.html) (documented)
- MA2: "The keys Next and Previous are the two basic MAtricks"; "Prev + Next execute the All keyword." — [grandMA2 MAtricks](https://help.malighting.com/grandMA2/en/help/key_matricks.html) (documented)
- MA2 pools: Effects, Forms and MAtricks are separate pools; MAtricks pool settings "can be assigned to User keys". — [grandMA2 Pools in General](https://help2.malighting.com/grandMA2/en/help/key_pools.html) (documented)
- Community: "MA2 has no selection grid and there, we only work with linear selections." For a linear MA3 selection "you must set the layout selection mode to linierize, and ensure that the grid cursor is set to append X." — [MA forum: Selection](https://forum.malighting.com/forum/thread/69177-selection/) (community)
- Community training: ConsoleTrainer's "grandMA3 for grandMA2 Programmers" lesson 14 covers "The X, Y and Z Axes, aligning with grids, grid syntax, and storing and merging grids"; lesson 13 says "the new tree structure concept of the grandMA3 has changed how we input our selection order." — [ConsoleTrainer 14: Groups + Grids](https://consoletrainer.com/14-groups-grids-grandma3-for-grandma2-programmers/); [YouTube 13: New Selection Syntax](https://www.youtube.com/watch?v=LI_tj5M5xZo) (community)
- Industry quote: Grids and Phasers are "the two best arguments to upgrade" (Matt Jones, Ed Sheeran LD). — [CX Network](https://cxnetwork.com.au/?p=38649) (community/press)

### Inferences
- Conversion rule: MA2 group (ordered fixture list) → MA3 group with fixtures placed at X=0..n-1, Y=0, Z=0, preserving MA2 selection order as X order. MA2 Interleave ≈ MA3 Groups (interleaved sub-groups); MA2 Block ≈ MA3 Block; MA2 Wings ≈ MA3 Wings; MA2 "Y-axis after Interleave" has a rough analogue in MA3 Y but is not a 1:1 translation. MA3 Width and Shuffle have no MA2 equivalent.
- MA2 MAtricks pool objects can be mapped to MA3 MAtricks pool objects for X-axis only.

### Gaps
- No source stated how the official converter writes grid coordinates for converted groups (the converter page lists "groups" as converted but gives no detail).

---

## Q3. Attributes / features / feature groups and attribute-name cross-reference

### Takeaway
Both systems use the same nine top-level categories (Dimmer, Position, Gobo, Color, Beam, Focus, Control, Shapers, Video) — MA2 calls them Preset Types (numbered 1–9), MA3 calls them Feature Groups — so the coarse mapping is 1:1. Below that, MA3 has a Feature Group → Feature → Attribute hierarchy with distinct internal "Name" vs display "Pretty" names and GDTF-style naming; **no official or community MA2→MA3 attribute-name cross-reference table was found.**

### Cited Findings
- MA2: "Each preset has a preset type number"; types run Dimmer (1) … Focus (6), Control (7), Shapers (8), Video (9); default preset groups "All, Dimmer, Position, Gobo, Color, Beam, Focus, Control, Shapers & Video". — [grandMA2 QSG 12 Preset Pool](https://help.malighting.com/grandMA2/en/help/grandma2_quick_start_guide/key_12_preset_pool.html); [grandMA2 Preset Control Bar](https://help.malighting.com/grandMA2/en/help/key_ws_preset_control_bar.html) (documented)
- MA3 feature groups in encoder-bar order: "Dimmer, Position, Gobo, Color, Beam, Focus, Control, Shaper, and Video. If a show file contains additional feature groups, more squares will be added automatically to the bar." — [grandMA3 2.5 Presets](https://help.malighting.com/grandMA3/2.5/HTML/presets.html) (documented; note MA3 says "Shaper", MA2 "Shapers")
- MA3 hierarchy: attributes inside features inside feature groups; "Each definition has a unique name and a display name, and it can be a sub-attribute of a main attribute. Attributes are organized in Activation Groups, Feature Groups, and Deactivation Groups." — [grandMA3 2.1 Attribute Definitions](https://help.malighting.com/grandMA3/2.1/HTML/patch_attribute_definitions.html) (documented)
- MA3: "the attribute defining the gobo position (index) uses Angle as a physical unit." — [grandMA3 2.0 Attribute Definitions](https://help.malighting.com/grandMA3/2.0/HTML/patch_attribute_definitions.html) (documented)
- MA3: "The grandMA3 system has a color engine that gives unified control regardless of the fixture's color system." — [grandMA3 QSG Control Moving (1.9)](https://help2.malighting.com/Page/grandMA3/qsg_control_moving/en/1.9) (documented)
- MA3 scripting: use `List Attribute` or Patch → Attribute Definitions; "Use the 'Name' of the Attribute, not the 'Pretty' of the Attribute." — [MA forum: Attribute commands](https://forum.malighting.com/forum/thread/68475-attribute-commands/) (community, forum moderator)
- MA3 attribute name "ColorRGB_R" appears in a community keyword set and in a third-party gma3 MCP tool description. — [Quizlet grandMA3 keywords](https://quizlet.com/644115035/grandma-3-keywords-flash-cards/); [gma3-mcp set_attribute](https://glama.ai/mcp/servers/bdstark/gma3-mcp/tools/gma3_set_attribute) (community, weak)
- GDTF attribute definitions live in Annex A of the GDTF spec / DIN SPEC 15800 clause 6 "Attribute Definitions". — [gdtf Rust crate docs](https://docs.rs/crate/gdtf/latest/source/src/description/attribute.rs); [DIN SPEC 15800 TOC](https://www.din.de/de/wdc-beuth:din21:324748671/toc-3173040/download) (documented standard; list itself not retrieved)
- A community MA2 devkit rebuilt from grandMA2 onPC 3.9.61.1 lists an Attribute node of 456 entries in `ma2_attributes.json` (not retrievable at research time). — [grandma-devkit PR #16](https://github.com/badasslighting/grandma-devkit/pull/16) (community)
- Converter: "Effect lines using attributes that the preset types lack are not turned into steps." — [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html) (documented) — implies attribute→preset-type membership drives conversion.

### Inferences
- Coarse mapping table (documented both sides): MA2 PresetType 1 Dimmer → MA3 FeatureGroup Dimmer; 2 Position → Position; 3 Gobo → Gobo; 4 Color → Color; 5 Beam → Beam; 6 Focus → Focus; 7 Control → Control; 8 Shapers → Shaper; 9 Video → Video.
- Attribute-level mapping must be done by name normalisation against MA3's Attribute Definitions export ("Name" column) and the GDTF Annex A list (MA3 attribute names follow GDTF conventions such as numbered instances Gobo1/Gobo1Pos, Shutter1, ColorRGB_R). The specific MA2↔MA3 pairs in the brief (e.g., COLORRGB1 vs ColorRGB_R) could **not be confirmed** by any source and should be treated as unverified community lore.
- MA3's Activation/Deactivation groups and physical units (e.g., Angle for gobo index) mean raw MA2 DMX-percent values may not round-trip without the fixture type's physical mapping.

### Gaps
- No official/community MA2→MA3 attribute cross-reference spreadsheet found. The GDTF Annex A list and MA3 attribute-definition list were not retrievable (network). Report writer should flag this as a required artefact to build empirically (export `List Attribute` from both onPCs).

---

## Q4. Presets: modes, pools, references, embedded presets, phaser presets

### Takeaway
Both systems have Selective/Global/Universal presets, nine feature-group-filtered pools, and store cue values as preset references. MA3 adds five unfiltered "All" pools (14 default pools), per-pool default mode, presets that hold multiple modes at once, presets that carry timing, and presets that are themselves multi-step Phasers. The official converter converts selective presets with timings; **global/universal presets, embedded presets, effect data in presets, and timing-only presets are documented as not converted** (as of the 3.9 release notes cited).

### Cited Findings
- MA2 modes: selective preset "locked to the fixtures that specifically had position values when the preset was stored"; Global applies to later-added fixtures of same type ("if you later add more Mac 700s then they can also use the color preset"); Universal "applies also to other fixture types than the ones used during the creation." — [grandMA2 QSG 12 Preset Pool](https://help.malighting.com/grandMA2/en/help/grandma2_quick_start_guide/key_12_preset_pool.html) (documented)
- MA3 modes: "The modes are Selective, Global, and Universal, and each preset can store all three modes or some combinations of modes." "Each preset pool has a setting for a default mode. This mode is indicated by one of the letters in the upper right corner of the pool title field." — [grandMA3 2.5 Presets](https://help.malighting.com/grandMA3/2.5/HTML/presets.html) (documented)
- MA3 pools: "Each feature group has its own preset pool. The default setting is that you can only store values from a feature group in its respective pool." "There are also five All preset pools. They can store values from all feature groups." — [grandMA3 2.5 Presets](https://help.malighting.com/grandMA3/2.5/HTML/presets.html) (documented)
- MA3 1.0: "14 preset pools by default"; "9 pools with filters" (Dimmer…Video); "All 1 to 5" unfiltered; a "Dynamic" pool view "automatically changes between the feature group preset pools based on the selected feature group". — [grandMA3 1.0 Preset Pools](https://help2.malighting.com/Page/grandMA3/presets_pools/en/1.0); [grandMA3 2.3 Preset Pools](https://help.malighting.com/grandMA3/2.3/HTML/presets_pools.html) (documented)
- MA3 preset addressing: "The first number is the feature group / preset pool number. The second number is the pool object." — [grandMA3 2.0 Preset Pools](https://help.malighting.com/grandMA3/2.0/HTML/presets_pools.html) (documented)
- Converter puts MA2 effects into "preset pool 22, which is renamed to Effects" — i.e., MA3 pool numbers extend beyond 14 at least to 22. — [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html); [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html) (documented)
- MA3 references: "A reference to the preset is stored for the specific fixture attributes. This means that the value stored in the preset is not stored in the cue, but a reference to the preset is stored." "Updating the preset means that the cues do not need to be updated since they reference the preset." — [grandMA3 2.4 Presets Use](https://help.malighting.com/grandMA3/2.4/HTML/presets_use.html) (documented)
- MA3 timing in presets: "Presets that contain both attribute values and timing values are stored in cues with a preset reference." — [grandMA3 2.5 Presets Use](https://help.malighting.com/grandMA3/2.5/HTML/presets_use.html) (documented)
- MA3 deleted presets: "When presets are used in cues and later deleted, the preset values are transferred to the cue (hardcoded values in the cue)." — [grandMA3 2.3 Presets](https://help.malighting.com/grandMA3/2.3/HTML/presets.html) (documented)
- MA3 Recast: "The recast function only recasts presets to cues where a preset reference exists for the absolute layer." — [grandMA3 2.2 Cue Update](https://help.malighting.com/grandMA3/2.2/HTML/cue_update.html) (documented)
- MA3 embedded presets exist: Store → At → tap preset; "If you update one of the presets selected, the embedded preset will be automatically updated." — [grandMA3 1.0 Embedded Presets](https://help2.malighting.com/Page/grandMA3/presets_embedded/en/1.0) (documented)
- MA3 MAgic presets: values "are calculated based on the points and then taken into the programmer as hard values. There is no reference back to the MAgic preset." — [grandMA3 2.4 Presets Use](https://help.malighting.com/grandMA3/2.4/HTML/presets_use.html) (documented)
- MA3 Phaser presets: "allows you to place multi-step effect sequences directly inside a preset or cue"; "Phasers are the effects and chasers of grandMA3, creating dynamic output from a single preset or cue." — [MA Lighting grandMA3 software page](https://www.malighting.com/special/grandma3-software/); [grandMA3 2.2 QSG Phasers](https://help.malighting.com/grandMA3/2.2/HTML/qsg_phasers.html) (documented/vendor)
- Converter scope: converts "presets with timings"; limitations: "global and universal presets are not converted, yet", "embedded presets are also not converted, yet", "Embedded presets are not convertible, yet", "effect data in presets, and presets that contain only timings without values, are not convertible"; 3.9 fix: "selective embedded presets no longer make the conversion fail, but embedded presets still won't be converted"; fixed crash with "embedded presets had a circular reference to the first preset". — [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html); [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html) (documented)
- Third-party tool: "Preset Mode Converter" (Notion page by M. Schoeffmann) for moving presets between Mode2 and Mode3 via XML — existence noted, not verified. — [Preset Mode Converter](https://mschoeffmann.notion.site/Preset-Mode-Converter-2259d45a5e8480f1a6c7e5212206c34d) (community)

### Inferences
- MA2 preset `type.index` (e.g., 4.1 = Color 1) maps numerically to MA3 `pool.index` for pools 1–9 since both use the same order; MA2 "All" presets would need a target among MA3 All 1–5 (pools 10–14 by inference from "14 default pools"; numbering not confirmed).
- MA2 selective/global/universal flag → MA3 preset mode flag of the same name; MA3 can hold several modes in one preset, so MA2's single-mode presets are a strict subset.
- MA2 embedded presets (preset referencing preset) → MA3 embedded presets conceptually exist, but the official converter skips them, so this is a gap a third-party converter could fill.
- MA2 effects stored inside presets have no MA2-like home in MA3; they become Phaser steps in the preset — the converter explicitly does not do this.

### Gaps
- Exact MA3 pool numbering for All 1–5 and pools 15–21 (only "pool 22 = Effects after conversion" is documented).
- Whether MA3 2.5 changed any of the converter limitations (release-notes pages unreachable).

---

## Q5. Effects (MA2 Effect pool / effect lines) vs Phasers

### Takeaway
MA2 effects are pool objects with lines (attribute, form, rate/speed, size/low-high, phase, width, groups, blocks, wings) applied to a selection; MA3 Phasers are per-attribute multi-step value sequences (steps with width/transition/accel/decel, speed, phase, measure) living in presets/cues. MA Lighting's own converter maps only the simple predefined MA2 forms to Phaser accel/decel values, with stomp becoming a single relative step; everything else is documented as not convertible.

### Cited Findings
- MA2 Rate/Speed: "both, rate and speed set the speed of an effect, and the default is Rate 1 which corresponds to 60.0 BPM"; Blocks: "Fixtures next to each other execute the same phase"; Wings: phase runs outward then inward, "In Pan effects which consist of 2 wings, one of the wings is inverted"; Width "sets the high and low values of an effect … not applied with the form Chase". — [grandMA2 Predefined Effects](https://help.malighting.com/grandMA2/en/help/key_effects_predefined.html) (documented)
- MA2 effects can use presets as low/high values. — [grandMA2 Effect using presets](https://help.malighting.com/grandMA2/en/help/key_effects_effect_using_presets.html) (documented)
- MA3 Speed: "Speed defines the overall rate at which the console plays back the steps of a phaser" in BPM, Hz or seconds. — [grandMA3 2.5 Phaser](https://help.malighting.com/grandMA3/2.5/HTML/phaser.html) (documented)
- MA3 Measure: "defines the number of beats in the repeating phaser loop. For example, a phaser with a measure of 4 beats and a speed of 120BPM will repeat every 2 seconds." — [grandMA3 2.5 Phaser](https://help.malighting.com/grandMA3/2.5/HTML/phaser.html) (documented)
- MA3 Phase: "defines the timing offset of each fixture's attributes within a phaser. Phase is displayed in degrees." — [grandMA3 2.5 Phaser](https://help.malighting.com/grandMA3/2.5/HTML/phaser.html) (documented)
- MA3 step layers: "Each phaser step also includes additional layers, which define the overall width of the step, the percentage of the step dedicated to transitioning to the new value, and the amount of acceleration and deceleration used"; "a 0% width makes the change happen instantly". Older (2.1): "Width is shown as a percentage of one beat as defined by the Speed layer." — [grandMA3 2.4 Phaser](https://help.malighting.com/grandMA3/2.4/HTML/phaser.html); [grandMA3 2.1 Phaser](https://help.malighting.com/grandMA3/2.1/HTML/phaser.html) (documented)
- MA3 Accel/Decel: linear transitions "keeping Accel and Decel values at 0%"; smooth sine-like "Accel and Decel values of -100%". "Transition values can differ for each step." — [grandMA3 2.5 Phaser](https://help.malighting.com/grandMA3/2.5/HTML/phaser.html); [grandMA3 2.2 QSG Phasers](https://help.malighting.com/grandMA3/2.2/HTML/qsg_phasers.html) (documented)
- Converter: "Effect pool objects go to preset pool 22, which is renamed Effects"; "grandMA2 effects will be converted into acceleration and deceleration values"; "stomp effects are rewritten as a hard value of 0 with a single step on the relative layer"; "Only the simple predefined forms of effects in grandMA2 are convertible, yet"; "Effect lines using attributes that the preset types lack are not turned into steps"; 3.9: "converting effects now keeps references to the cues and steps where they were used". — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html); [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html) (documented)
- Only executors "that have sequences or selective effects assigned are converted". — [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html) (documented)
- Industry view: Phaser workflow "allows for more complex outcomes and results, when compared to grandMA2". — [CX Network](https://cxnetwork.com.au/?p=38649) (community/press)

### Inferences
- Feasible mapping (consistent with what MA's converter does): MA2 sine form → 2-step Phaser (low/high) with Accel/Decel −100%; MA2 linear/ramp → 0%/0%; MA2 chase (hard steps) → width 0% / instant transition; MA2 rate/speed BPM → Phaser Speed BPM; MA2 phase range (e.g., 0…360) → Phaser Phase in degrees; MA2 low/high (size/width) → the two step values; MA2 Groups/Blocks/Wings → MAtricks on the selection (Groups/Blocks/Wings have same-named MA3 counterparts).
- No MA3 equivalent for: MA2 free-form user Forms (bitmap/drawn forms), effect lines spanning attributes outside the preset-type pool, MA2 effect "Attack/Decay" in the same sense, relative vs absolute effect modes per line (MA3 has absolute/relative layers but conversion rules not documented), and MA2 effect-pool objects as independently playable executors (MA3 phasers live in presets/cues).
- MA3 Measure has no MA2 analogue; converted phasers would use default measure.

### Gaps
- No source documents exact numeric conversion formulas (e.g., how the converter chooses accel/decel for each MA2 form) beyond the qualitative statements above.

---

## Q6. Sequences and cues: numbering, parts, timing, tracking, Assert/Release, triggers, CMD, MIB

### Takeaway
The cue model is largely congruent: both have cue numbers, cue parts, per-cue fade/delay with per-attribute override, snap %, Trig (Go/Time/Follow/Sound/BPM), Trig Time, CMD column, MIB, and tracking with Assert/Release. Differences: MA2 expresses Assert/X-Assert/Release/Break as a single cue "Mode" column while MA3 splits them into Assert, X-Assert and Release columns plus a Tracking Distance column; MA3 allows 256 parts per cue; MA3 MIB adds UponGo, Force modes, per-cue MIB Preference and MIB Target.

### Cited Findings
- MA2 sheet columns: "Trig" (Go, Follow, Sound, BPM; timecode-triggered cues always Assert); "Trig Time"; "MIB is 'Move In Black'"; Mode options "Normal, Assert, X-Assert, Release, Break, and X-Break" ("Release turns off the executor when the fade is complete"); "AE is 'Assert Effects'"; "CMD is 'Command'"; "Delay, Fade, Out Delay and Out Fade"; "Loop, Ltime, and Lcount"; Snap as % of fade. — [grandMA2 Cue Sequence](https://help.malighting.com/grandMA2/en/help/key_cs_cue_sequence.html); [grandMA2 Cue Modes](https://help.malighting.com/grandMA2/en/help/key_adv_seq_cue_modes.html); [grandMA2 Loop](https://help2.malighting.com/grandMA2/en/help/key_adv_seq_loop.html) (documented)
- MA3 triggers: five types — Go ("waits for a Go command"), Time ("countdown … starts when the previous cue is triggered"), Follow ("triggered when the previous cue is completely done with the cue transition, including all individual timing"; positive wait allowed), Sound ("one of 22 different frequency areas selectable in the Trig Sound column"), BPM. "The Trig Time value is only used if the trigger is Time or Follow." — [grandMA3 2.0 Sequence Sheet](https://help.malighting.com/grandMA3/2.0/HTML/cue_sequence_sheet.html) (documented)
- MA3 timing: "Each individual attribute can have an individual fade and/or delay time"; cue fade is "the fade time for all non-snap attributes and dimmer values that increase in value"; "cue-in delay is the delay … between the trigger and the actual cue in fade"; "Presets with no individual fade time will respect the program time setting." — [grandMA3 2.0 Cue Timing](https://help.malighting.com/grandMA3/2.0/HTML/cue_timing.html) (documented)
- MA3 parts: "It is also possible to store 256 Cue Parts to each cue. Cue part 0 is always created with the cue, and this part has all the values unless a different part is created"; "Allow Duplicates" permits same attribute in several parts. — [grandMA3 2.3 Cue Store](https://help.malighting.com/grandMA3/2.3/HTML/cue_store.html) (documented)
- MA3 Assert: "can be used to make tracked values take precedence as if they are stored values in the cue"; "values are asserted using the timing from the cue where the values are originally stored"; X-Assert "asserted using the timing from the cue where the X-Assert is set". — [grandMA3 2.1/2.4 Cue Tracking](https://help.malighting.com/grandMA3/2.4/HTML/cue_tracking.html) (documented)
- MA3 Release: "changing the value to Yes in this cell makes the cue release tracked values … from this cue and forward." — [grandMA3 2.3 Cue Tracking](https://help.malighting.com/grandMA3/2.3/HTML/cue_tracking.html) (documented)
- MA3 Tracking Distance: "sets how many cues a value should track. If the cell is empty, it tracks until changed." — [grandMA3 2.4 Tracking Distance](https://help.malighting.com/grandMA3/2.4/HTML/cue_tracking_distance.html) (documented)
- MA3 CMD: "Commands can be written in the cues. Editing the cell opens the Command Editor"; executed "on the GlobalMaster, IdleMaster, or Standalone station if Command Enabled allows it"; "cmd" label shown in cue name cell; "Command Delay" option; sequence setting "Cmd Enable … disables the execution of the commands in the CMD columns … The commands get a red text color when they are disabled." — [grandMA3 2.4 Sequence Sheet](https://help.malighting.com/grandMA3/2.4/HTML/cue_sequence_sheet.html); [grandMA3 1.0 Sequence Settings](https://help2.malighting.com/Page/grandMA3/cue_sequence_settings/en/1.0) (documented)
- MA3 MIB: modes Early ("right after the dimmer closes"), UponGo ("with the next cue transition after the dimmer closes"), Late ("latest in the cue before the dimmer opens again"); sequence defaults None/Early/UponGo; Force Early/UponGo/Late override per-cue (but respect MIB Preference); Never disables; per-cue MIB Mode Default/Defined with MIB Target cue; "MIB Preference … percentage number from 0(never) to 100(best)"; moved attributes "are not automatically active values in the programmer". — [grandMA3 2.4 Cue MIB](https://help.malighting.com/grandMA3/2.4/HTML/cue_mib.html) (documented)
- MA2 MIB: Early and Late; "a numbered cue can be set as the MIB source directly (preposition from a cue number)". — [grandMA2 Advanced Seq MIB](https://help.malighting.com/grandMA2/en/help/key_adv_seq_mib.html) (documented)
- Converter converts "sequences and cue timings". — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html) (documented)
- Community (MA2 bridge): MA2 numbering per page is 1–90 faders / 101–190 buttons. — [midimonster maweb backend](https://raw.githubusercontent.com/cbdevnet/midimonster/master/backends/maweb.md) (community)

### Inferences
- Mapping: MA2 Mode=Assert → MA3 Assert column = Assert; Mode=X-Assert → MA3 X-Assert; Mode=Release → MA3 Release=Yes (semantics differ: MA2 Release "turns off the executor when fade complete" vs MA3 Release "release tracked values from this cue forward" — not identical; flag for manual review); MA2 Break/X-Break → no direct MA3 column found (gap). MA2 AE (Assert Effects) → no obvious MA3 column (MA3 phasers are values, so Assert covers them) — inference.
- MA2 MIB Early → MA3 Early; MA2 MIB Late → MA3 Late; MA2 MIB-from-cue-number → MA3 MIB Mode=Defined + MIB Target. MA3 UponGo/Force/Preference have no MA2 source.
- MA2 Loop/Ltime/Lcount → MA3 CMD column with Goto/Go commands or MA3 "Loop" features (not found in sources) — gap.
- Trig types map 1:1 (Go, Time, Follow, Sound, BPM); MA2 "Timecode" trigger has no listed MA3 Trig type (MA3 drives cues from Timecode shows instead) — inference.

### Gaps
- MA3 "Protected" cue flag and MA3 loop columns not found. MA2 "Snap" ↔ MA3 "SnapPercent" naming not confirmed. MA2 Out Fade/Out Delay vs MA3 CueOutFade/CueOutDelay naming inferred from the manual's "CueFade/CueDelay" property names in the Set example (see Q8) but not confirmed for Out variants.

---

## Q7. Executors, pages, executor settings; executor numbering

### Takeaway
MA2 numbers fader executors 1–n and button executors 101–n per page (light: 1–15 / 101–115; full-size 1–30 / 101–130; up to 90/190 per page), with separate fader and button pages; MA3 numbers by physical row — 101–190 (button only), 201–290 (button+fader), 301–390 (button+knob) — with one page type (up to 9,999 pages per data pool) and reusable Executor Configuration pool objects. MA2 Special Masters become MA3 Masters in the official converter.

### Cited Findings
- MA2 light/ultra-light: "15 Fader Executors (numbered 1 through 15) and 15 Button Executors (numbered 101 through 115)"; full-size "30 Fader Executors (1–30) and 30 Button Executors (101–130)". Fader executor = physical fader + three keys (1 below fader, 2 above, 3 top); button executor = one key + virtual fader. Fader and button pages are separate unless "Link Fader & Button Page" is set; commands `FaderPage 5`, `ButtonPage 20`. — [grandMA2 Exec on screen](https://help.malighting.com/grandMA2/en/help/key_exec_on_screen.html); [grandMA2 What are executors](https://help.malighting.com/grandMA2/en/help/key_exec_what_are.html); [grandMA2 Exec pages](https://help.malighting.com/grandMA2/en/help/key_adv_exec_pages.html) (documented)
- MA2 per-page extents 1–90 / 101–190. — [midimonster maweb backend](https://raw.githubusercontent.com/cbdevnet/midimonster/master/backends/maweb.md) (community)
- MA3: "The bottom row is numbered from 101 up to 190. This row only has a single executor button. The row above is numbered from 201 up to 290. This row has an executor button and an executor fader. The next row is from 301 up to 390" (button + knob); hardware keys marked with 1/2 horizontal lines. "It is possible to create up to 9 999 executor pages in each Data Pool. Each page has its own setup of executors." Physical consoles may have fewer executors (compact: 2×5 columns). — [grandMA3 2.5 QSG Cue Executor](https://help.malighting.com/grandMA3/2.5/HTML/qsg_cue_executor.html); [grandMA3 2.1 Executor](https://help.malighting.com/grandMA3/2.1/HTML/executor.html) (documented)
- MA3 Executor Configurations: "stored in an Executor Configuration pool. Each object type that can be assigned to an executor has a default executor configuration"; Load/Save between pool and executors; defaults under Menu → Preference and Timings → Executor Config. — [grandMA3 2.5 Executor Configurations](https://help.malighting.com/grandMA3/2.5/HTML/executor_configurations.html) (documented)
- MA3 fader functions: options include Empty, Master ("Controls the intensity"), X (CrossFade); syntax "Assign [Function] at [Location]"; "The available functions depend on the object assigned to the executor and the executor itself"; keys assignable by Assign + key + target or typed command. — [grandMA3 2.4 Executor Assign](https://help.malighting.com/grandMA3/2.4/HTML/executor_assign.html) (documented)
- MA3 Masters: "timing and level overrides. They can be assigned to fader executors or any of the special executors in the Master section, Custom section, or the Grand Master"; by default master fader 1 = Master of selected sequence, master fader 2 = CrossFade of selected sequence; 2.5 adds a Disabled state. — [grandMA3 2.5 Masters](https://help.malighting.com/grandMA3/2.5/HTML/masters.html) (documented)
- MA3 `Set Sequence … Property Priority` example exists (sequence priority is a settable property). — [grandMA3 2.2 Set keyword](https://help.malighting.com/grandMA3/2.2/HTML/keyword_set.html) (documented)
- Converter: "Special Masters are converted into Masters in grandMA3"; "Only executors that have sequences or selective effects assigned are converted"; "The grandMA2 Xkeys X5, X6, X15, and X16 are not converted"; MA3 hardware has 16 X-keys vs MA2's 20 ("The extra four can still be reached on screen" in Mode2). — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html); [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html); [grandMA2 Mode2 Screen Layout](https://help2.malighting.com/Page/grandMA2/mode2_screen_layout/en/3.9) (documented)
- Views caveat: on MA3 default view-bar items "reference the same view pool items across displays, so changing a view on one screen can change it on the others" (2020 thread; may have changed). — [MA forum: Views](https://forum.malighting.com/forum/thread/4184-views/) (community)

### Inferences
- Numbering map: MA2 fader exec N (1–90) → MA3 2NN-row (201+N−1); MA2 button exec 1NN (101–190) → MA3 101+N−1 row. MA2's separate Fader/Button pages must be collapsed into one MA3 page (if MA2 fader page ≠ button page, converter must pick one or duplicate pages).
- MA2 executor options (priority, fader function Master/X-fade/Rate/Speed, button functions Go/Flash/Toggle…) → MA3 sequence properties (Priority etc. via Set) plus an Executor Configuration object; MA3 knob row (301–390) has no MA2 source.
- MA2 Special Masters (Grand/Speed/Rate/Prog Time/Exec Time/Sound) → MA3 Masters pool objects (documented by converter), but mapping of each individual master type was not detailed.

### Gaps
- Exact list of MA2 executor option fields vs MA3 sequence/executor properties not retrieved. Whether the converter maps X-keys 1–4/7–14 explicitly was not stated beyond the four excluded.

---

## Q8. Macros, command syntax, Worlds, Layouts, Timecode, Views

### Takeaway
Macro *objects* (pool, lines) convert, but MA Lighting states macro *commands* cannot be translated to MA3 syntax and must be verified manually. Core selection/value syntax is similar (keywords, Please, numeric ids), while property editing in MA3 uses `Set <Object> Property <name> <value>` (MA+Assign), MA3 object addressing is tree/path-based, and MA3 adds Filters as a distinct pool alongside Worlds. Worlds, filters, layouts, timecodes and remotes are listed as converted (remotes without type/target).

### Cited Findings
- MA3 macro assignment: "a macro must first exist in the macro pool before it can be assigned. The executor or view button simply run the macro in the pool." — [grandMA3 1.0 Macro Assign](https://help2.malighting.com/Page/grandMA3/macro_assign/en/1.0) (documented)
- MA3 Set: "Set [Object_Type] ['Target_Object_Name' or Target_Object_Number] Property ['Property_Name'] At [Object_Type] (['Source_Object_Name' or Source_Object_Number]) (Property ['Property_Name'])"; examples: setting a sequence's priority; copying one cue's CueFade to another cue's CueDelay; Set is entered by MA + Assign. — [grandMA3 2.2 Set keyword](https://help.malighting.com/grandMA3/2.2/HTML/keyword_set.html) (documented)
- MA3 Label: "Label … for labeling objects, with the example 'Label Cue 14'"; Assign alone = Assign keyword, MA+Assign = Set. — [grandMA3 1.0 Keys Overview](https://help2.malighting.com/Page/grandMA3/key_overview/en/1.0); [grandMA3 2.2 Assign key](https://help.malighting.com/grandMA3/2.2/HTML/key_assign.html) (documented)
- MA3 command line: keywords have own buttons and can all be typed; some commands need Please, e.g. "Delete Sequence 1". — [grandMA3 1.0 Function of the Command Line](https://help2.malighting.com/Page/grandMA3/csk_function_of_command_line/de/1.0) (documented)
- MA3 Edit preset: "edit a preset from the Edit key or the preset's Edit Options. Doing so loads its contents into the programmer, and Update lights up". — [grandMA3 1.0 Edit Presets](https://help2.malighting.com/Page/grandMA3/presets_edit/en/1.0) (documented)
- MA3 playback keywords in CMD: Go+ ("triggers the next cue with a 'Go' trigger or specifies a cue … triggers subsequent cues using a follow or timed trigger"), Go-, Goto, >>>, <<<, Kill; "GoFastForward (>>>) keyword with a specified cue triggers only that cue". — [grandMA3 2.5 Cue Playback](https://help.malighting.com/grandMA3/2.5/HTML/cue_playback.html) (documented)
- Converter: "Macro syntax have to be verified manually by the user in grandMA3"; 3.9: "macros are still converted, although the commands inside the macros cannot be translated to the grandMA3 syntax"; converts "worlds, filters, timecodes, layouts, macros, and remotes"; "type and target of remotes are not converted". — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html); [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html) (documented)
- MA3 Worlds: "the tool for limiting access to fixtures and attributes"; default world 1 "All", locked. Filters: "contain information about attributes, filter rules, and programming layers … used to block values from being stored or recalled"; stored in Filters pool, first is "All"; worlds and filters "can be assigned to objects such as a sequence or a preset", and (2.5) to sheets for masking; "assigning a filter that blocks certain ID Types to a Layout will hide these fixtures in the layout viewer." — [grandMA3 2.0/2.2/2.5 Worlds & Filters](https://help.malighting.com/grandMA3/2.5/HTML/worldfilter.html) (documented)
- MA3 Timecode: three view modes (Timeline, Text, Both); "Shows are organized into tracks inside track groups, and there are eight timecode slots that can take SMPTE, MIDI, or Art-Net timecode input." — [grandMA3 2.3 Timecode Show](https://help.malighting.com/grandMA3/2.3/HTML/timecode.html); [grandMA3 2.0 Timecode View Mode](https://help.malighting.com/grandMA3/2.0/HTML/timecode_view_mode.html) (documented)
- MA3 Data Pools "offer a more flexible organization regarding the structure of the show file" (2.4 release notes). — [grandMA3 2.5 RN other enhancements 2.4](https://help.malighting.com/grandMA3/2.5/HTML/rn_otherenhancements-2-4.html) (documented)
- MA2 Mode2 version mapping: grandMA3 0.8 ↔ grandMA2 3.4, grandMA3 1.0 ↔ grandMA2 3.8. — [grandMA2 Mode2 Version Specification](https://help2.malighting.com/Page/grandMA2/mode2_version_specification/en/3.9) (documented)

### Inferences
- Syntax-translation table (inference from the cited keyword pages; needs validation): MA2 `Assign Sequence 1 /Priority=High` style option syntax → MA3 `Set Sequence 1 Property "Priority" "High"`; MA2 `Label` → MA3 `Label` (same); MA2 `Store Preset 4.1` → MA3 `Store Preset 4.1` (same pool.index addressing, documented pool numbering 1–9 identical); MA2 `Fixture 1 Thru 10 At 50` → same in MA3; MA2 `Goto Cue 5 Executor 1.1` → MA3 `Goto Cue 5 Sequence X` or `Page P.Executor 2NN`; MA2 `FaderPage`/`ButtonPage` → MA3 single `Page`. MA2 cue "Mode" options have no single-keyword MA3 counterpart (split into Assert/X-Assert/Release properties).
- Because MA3 addressing is a tree (DataPool/Page/Executor, Preset pool.index, Sequence/Cue/Part), MA2 macros that address executors (`Executor 1.5`) are the main class that cannot be mechanically translated — consistent with MA's "verify manually" statement.
- MA2 Worlds → MA3 Worlds 1:1 (both limit fixtures/attributes); MA2 Filters → MA3 Filters pool (MA3 adds layer rules); MA2 Layouts → MA3 Layouts (converter lists them); MA2 Timecode shows → MA3 Timecode shows with track groups/tracks (structure differs; converter lists them as converted).

### Gaps
- No side-by-side official MA2↔MA3 keyword table found; MA3 keyword list for `Edit`, `Store` option syntax (e.g., `/Merge`, `/Overwrite` equivalents) not retrieved. No source compared MA2 vs MA3 Layout object data (positions, element types).

---

## Q9. Official MA statements on MA2→MA3 compatibility (show files, Mode2, converter)

### Takeaway
Officially: grandMA3 does not open grandMA2 show files directly; grandMA3 hardware can run grandMA2 software ("Mode2", grandMA2 3.4+); grandMA2 onPC 3.9 (or Mode2) provides a one-way "Save as grandMA3" converter that writes an MA3 show into the MA3 shows folder, with a documented, non-trivial list of unconverted objects. MA3's own Import keyword/menu imports MA3 XML exports (not MA2 files).

### Cited Findings
- "The option 'Save as grandMA3' works only on a grandMA2 onPC or in Mode2 on a grandMA3 console"; output "is saved in C:\ProgramData\MALightingTechnology\gma3_x.x.x\shared\shows, and this show file can be opened in the grandMA3 software"; not supported in Parallels Desktop. — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html) (documented)
- Converted: "patch data, presets with timings, sequences and cue timings, groups, worlds, filters, timecodes, layouts, macros, and remotes. Special Masters are converted into Masters in grandMA3. grandMA2 effects will be converted into acceleration and deceleration values." — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html) (documented)
- Not converted / limitations (combined from converter page and 3.9 release notes): only simple predefined effect forms; embedded presets; global and universal presets ("not converted, yet"); effect data in presets; timing-only presets; effect lines on attributes outside preset type; Xkeys X5/X6/X15/X16; macro command syntax; remote type/target; executors without sequences/selective effects. — [grandMA2 Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html); [grandMA2 3.9 Release Notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html) (documented)
- Mode2: "used to run the grandMA2 software on a grandMA3 console … runs native grandMA2 software version 3.4 and later"; some MA3 console sections/buttons unassigned; displays must be 1920×1080; MA3 screen 1 ≙ MA2 screen 2; 16 vs 20 X-keys. — [grandMA2 Mode2 Introduction](https://help2.malighting.com/Page/grandMA2/mode2_introduction/en/3.5); [grandMA2 Mode2 Screen Layout](https://help2.malighting.com/Page/grandMA2/mode2_screen_layout/en/3.9) (documented)
- MA3 Import: "The Import / Export menu presents a graphical workflow for exporting objects from the current show file as a smaller file"; Import keyword "incorporates small portions of exported show file data, available as XML files, into the current show file." — [grandMA3 2.0 Import/Export](https://help.malighting.com/grandMA3/2.0/HTML/import-export.html); [grandMA3 2.3 Import keyword](https://help.malighting.com/grandMA3/2.3/HTML/keyword_import.html) (documented)
- Community guidance: "not all parts of a grandMA2 show file can or will be converted to grandMA3. Users are advised to check the show carefully before running it." — [MA forum: Upgrading Showfile](https://forum.malighting.com/forum/thread/8131-upgrading-showfile/) (community, paraphrasing MA guidance)
- Community transition view: early MA3 "lagged grandMA2 on features and stability, so many operators ran it in 'grandMA2 mode' for years … native MA3 is now the path forward." — [lighting-console-expert.com transition guide](https://lighting-console-expert.com/en/grandma2-vs-grandma3/) (community, undated, not fetched)

### Inferences
- The brief's phrase "grandMA3 cannot load grandMA2 show files" was not found verbatim, but it follows from the documented workflow (conversion must be done from the MA2 side; MA3 Import only takes MA3 XML).
- A third-party converter should target the MA3 show-file XML / MA3 Import XML format and focus on the documented gaps (macro syntax translation, embedded presets, global/universal presets, complex effects, remotes, executors without sequences).

### Gaps
- Whether the converter's limitations changed after grandMA2 3.9.60.x or whether MA3 2.5 added any MA2 import — release-note pages unreachable; nothing in search results suggested MA3-side import of MA2 files exists.

---

## Q10. Consolidated concept-by-concept mapping table

### Takeaway
Summary table synthesised from Q1–Q9 (D = documented both sides, C = community, I = inference). Converter column = behaviour of MA Lighting's own "Save as grandMA3" where documented.

### Cited Findings
| MA2 object | MA3 equivalent | What changes / no equivalent | Evidence | Official converter |
|---|---|---|---|---|
| Fixture ID | FID (IDType Fixture) | MA3 adds 8 ID types, CID optional second ID | D ([MA3 QSG Patch](https://help.malighting.com/grandMA3/2.5/HTML/qsg_first_patch.html)) | patch converted |
| Channel ID | CID (IDType Channel) | same | D | patch converted |
| Multi-instance fixture | Fixture + subfixtures `N.k`; `N.` selects all | MA3 geometry tree | D ([Fixture sheet 2.1](https://help.malighting.com/grandMA3/2.1/HTML/operate_fixture_sheet.html)), I | fixture types "lost"/XYZ broken (C) |
| Fixture type XML (modes) | MA3 fixture type / GDTF (+geometry) | needs Activation/Feature/Deactivation groups, physical units | D ([Attr defs](https://help.malighting.com/grandMA3/2.1/HTML/patch_attribute_definitions.html)) | converted MA2 types importable |
| Layer (patch) | Layer + Class + Stage | Class/Stage new | D ([Patch add fixtures](https://help2.malighting.com/grandMA3/2.4/HTML/patch_add_fixtures.html)) | — |
| Universe (DMX) | Universe pool (1024) | more universes | D | — |
| Group (linear order) | Group with grid (X only) | MA3 adds Y/Z, grid cursor flags | D, C ([forum Selection](https://forum.malighting.com/forum/thread/69177-selection/)) | groups converted |
| MAtricks (Interleave/Block/Wings/Y) | MAtricks (Groups/Blocks/Wings/Width/Shuffle per X/Y/Z) | Width, Shuffle new | D | not listed |
| Preset type 1–9 | Feature group 1–9 (same order) | "Shapers"→"Shaper"; extra feature groups auto-add | D | — |
| Preset pool All | All 1–5 pools | 5 unfiltered pools | D | — |
| Preset modes S/G/U | S/G/U, multiple per preset, pool default mode | — | D | **G/U not converted** |
| Preset with timing | preset with timing (reference stored) | — | D | converted |
| Embedded preset | Embedded preset | — | D | **not converted** |
| Effect in preset | Phaser preset (steps) | model change | D | **not converted** |
| Effect pool object | Preset in pool 22 "Effects" (Phaser) | forms→accel/decel; stomp→single relative step; only simple forms | D ([3.9 RN](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)) | partial |
| Effect Form pool (user forms) | — | no equivalent found | I | not converted |
| Sequence / Cue / Part | Sequence / Cue / Part (≤256 parts) | Allow Duplicates | D | converted |
| Cue Trig Go/Time/Follow/Sound/BPM | same five | — | D | converted |
| Cue Mode Assert/X-Assert/Release/Break | Assert / X-Assert / Release columns + Tracking Distance | Break: none found; Release semantics differ | D | ? |
| Cue AE (Assert Effects) | — | not found | gap | ? |
| CMD column | CMD column (+Command Delay, Cmd Enable) | — | D | syntax unverified (I) |
| MIB Early/Late/from-cue | Early/UponGo/Late, Force*, Preference, Target | UponGo/Force/Preference new | D ([Cue MIB](https://help.malighting.com/grandMA3/2.4/HTML/cue_mib.html)) | — |
| Fader exec 1–90 / page | Exec 201–290 | row numbering | D | only with sequence/sel. effect |
| Button exec 101–190 / page | Exec 101–190 | — | D | same |
| — | Exec 301–390 (knob) | new | D | — |
| Fader page / Button page | Page (one) | pages merged | D, I | — |
| Executor options | Executor Configuration pool + Sequence properties (Set) | — | D | — |
| Special Masters | Masters | — | D | converted |
| X-keys 1–20 | X-keys 1–16 | X5/X6/X15/X16 dropped | D | partial |
| Macro / macro lines | Macro / macro lines | command text not translated | D | **syntax manual** |
| World | World (default "All" locked) | — | D | converted |
| Filter | Filter pool (attributes+layers) | — | D | converted |
| Layout | Layout (filters hide IDTypes) | — | D | converted |
| Timecode show | Timecode show (track groups/tracks, 8 slots) | structure differs | D | converted |
| Remote | Remote | type/target lost | D | partial |
| View | View (shared pool across displays) | behaviour differs (2020) | C | — |

### Inferences
- The converter column shows the practical boundary of 1:1 mappability as judged by MA Lighting itself.

### Gaps
- Items marked "?" or "gap" could not be confirmed because the MA help/forum domains were unreachable; the report writer should present them as needing verification on a console.
