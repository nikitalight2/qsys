# Existing Tools and Prior Art for grandMA2 <-> grandMA3 Show Conversion

Research date: 2026-10-30. Status note on sourcing: the hosts `help.malighting.com`, `help2.malighting.com`, `forum.malighting.com`, `support.actentertainment.com`, `academy.actentertainment.com`, `fiets.de`, `gmatoolbox.app`, `mschoeffmann.com`, `ma.tools`, `gdtf-share.com` and `oreateai.com` could not be fetched directly. Findings from those sites are taken from search-engine result snippets of the pages, so they are **page-attributed but not full-text verified**. GitHub pages were fetched directly and are full-text verified. Each finding is marked **[documented]** (official MA docs/release notes or a tool's own page) or **[anecdotal]** (forum/user report/blog).

---

## Key Question 1: MA Lighting official — does grandMA3 import grandMA2 shows? What, since when, limitations, real-world quality?

### Takeaway
There is no "Import grandMA2 show" button inside grandMA3. The official path is the opposite direction: the **grandMA2 software** (onPC, or a grandMA3 console booted in Mode2) has a Backup-menu button **"Save as grandMA3 x.x.x"** (earlier labelled "Export Patch to grandMA3 1.x") that writes a grandMA3 show file. Initially (2020–2021, gMA2 3.9.60.x / gMA3 1.4) it converted only the patch; by 2022 (gMA2 3.9.60.38 / gMA3 1.7) it converted patch, fixture types, worlds, filters, groups, value-layer presets and some sequences; 3.9.60.89 added executors/pages; later 3.9.6x builds fixed cue-1 loss and preset crashes. Officially unconverted: macro command contents, effect data in presets, timing-only presets, non-"simple predefined" effects, fixture types >8192 channel sets. Users in 2022–2026 still describe results as "unsatisfactory" (lost fixture types, broken XYZ/pan-tilt), and there is no merge into an existing MA3 show.

### Cited Findings

**Existence, location, naming**
- **[documented]** The official grandMA2 help page is titled "grandMA2 to grandMA3 Show File Converter"; the feature is the Backup-menu button "Save as grandMA3 x.x.x (x.x.x is a place holder for the installed grandMA3 version number)". It "works only on a grandMA2 onPC or in Mode2 on a grandMA3 console" and "is not supported on grandMA2 onPC running in the Parallels Desktop application." — [MA help: grandMA2 to grandMA3 Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- **[anecdotal, 2020]** Earlier label of the same button: "In grandMA2 you must go to the Backup menu and press {Export Patch to grandMA3 v1.3}. The resulting file can then be opened in grandMA3 software." Also: "grandMA2 show files cannot be opened directly into grandMA3." — [MA forum thread 4617 "Import show gMA2 on pc to gMA 3 on Mac"](https://forum.malighting.com/forum/thread/4617-import-show-gma2-on-pc-to-gma-3-on-mac/)
- **[anecdotal, 2020]** "there is no possibility to merge it into an existing grandMA3 show" (the converted patch becomes its own show file). — [MA forum thread 4039 "grandMA2 fixture type import"](https://forum.malighting.com/forum/thread/4039-grandma2-fixture-type-import/)
- **[documented]** grandMA3 2.0 release notes: the Backup Menu restriction (Load/New Show disabled if none of Show Data / Local Settings / Output Stations / DMX Protocols is ticked) "also applies to show files that will be converted from grandMA2 to grandMA3 using the show file converter (in Mode 2)". — [grandMA3 Release Notes 2.0](https://help.malighting.com/grandMA3/2.0/HTML/key_releasenotes.html)
- **[documented]** grandMA3 2.1 release notes point to the separate grandMA2 release notes for converter improvements, i.e. converter changes are logged on the gMA2 side. — [grandMA3 Release Notes 2.1](https://help.malighting.com/grandMA3/2.1/HTML/key_releasenotes.html)
- **[documented]** grandMA3 2.0 manual: a show file "needs to be saved first with grandMA3 v1.9 or higher" before it can be loaded in 2.x — relevant because old converted files from gMA3 1.x must be stepped up through a 1.9 install. — [MA help: Load a Show File](https://help.malighting.com/grandMA3/2.0/HTML/sfh_load.html)

**What is converted — version history**
- **[documented/moderator, 2021]** "as of grandMA2 v3.9.60.4 and grandMA3 v1.4.2.1, only patch converts from grandMA2 to grandMA3. More should be converted in the future." — [MA forum thread 4039](https://forum.malighting.com/forum/thread/4039-grandma2-fixture-type-import/)
- **[anecdotal/moderator, 2022]** Converting from gMA2 v3.9.60.38 to gMA3 v1.7.2.2 the list of converted objects is: "Patch and Fixture Types, Worlds, Filters, Groups", "Presets (only value layer, not timing or effect layers)", and some sequences; "You have to convert from the matching grandMA2 version to get the most up-to-date functionality"; "not all parts of a grandMA2 show file can or will be converted to grandMA3." — [MA forum thread 7931 "convert show from ma2 to ma3"](https://forum.malighting.com/forum/thread/7931-convert-show-from-ma2-to-ma3/)
- **[documented]** gMA2 release notes 3.9.60.89: "added the conversion of Executors": gMA2 executors 101–190 -> gMA3 executors 101–190; gMA2 executors 1–90 -> gMA3 executors 201–290. Earlier bugs fixed in the same build: converted shows "could sometimes contain empty executors"; "If Executor Time and Prog Time were assigned to executors in grandMA2, they had no function in the converted show file." Before that fix, "the functions would be converted into custom commands instead of executor functions." Also: "Sequences that are only assigned to executors as chasers get a Trigger Time of BPM/60 per cue during conversion." — [grandMA2 Release Notes 3.9](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)
- **[documented, third-party copy]** Executors "that do not have sequences or selective effects assigned are not converted." — [Scribd copy of gMA2 3.9 release notes](https://www.scribd.com/document/856419471/Release-Notes-releasenotes-en-v3-9) (secondary copy; verify against official PDF)
- **[documented]** gMA2 release notes: under v2.4.2.2 (gMA3) "cue 1 of sequences was not converted into grandMA3, and sequences started with cue 2" — fixed later. Other converter fixes: "Circular embedded presets do not crash the software when converting show files"; "Illegal values in presets are replaced with default values during the show file conversion"; selective embedded presets no longer cause failures; 3.9.61.3 is "a version-number change to ensure the correct output folder in the show converter". Timecode shows convert but "not all properties, for example, Runs, Switch Off or Record Mode, were not converted correctly in earlier versions." — [grandMA2 Release Notes 3.9](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)
- **[documented]** Official converter page: conversion order processes "Presets with values that include timings" as step 4 and sequences/cues at step 5, then executors and pages; "Executors and Pages are converted"; "Special Masters become Masters in grandMA3"; "grandMA2 effects are turned into acceleration and deceleration values". — [MA help: Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)

**Documented limitations (official)**
- **[documented]** "Macro commands can not be converted" / "Macro syntax has to be checked by hand in grandMA3." — [MA help: Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- **[documented]** "Only the simple predefined forms of effects in grandMA2 are convertible, yet. Effect data in presets and presets that contain only timings without values are not convertible, yet." — same page.
- **[documented]** "Fixture types with more than 8,192 channel sets lose the sets past that number." — same page.
- **[documented]** Fixture profiles whose Source column says "grandMA2" "cannot be exported as GDTF files" from grandMA3. — [ACT: Importing Fixture Profiles into grandMA3](https://support.actentertainment.com/knowledgeBase/23941397); also [MA forum thread 8142](https://forum.malighting.com/forum/thread/8142-on-pc-1-8-8-2-does-not-find-xml-and-xmlp-but-gdtf-files-in-f-grandma3-gma3-libra/)
- **[documented]** grandMA3 native model differences stated in gMA3 1.0 notes: "Presets with individual timings are stored in cues, which have links to these timings; Sequences are synchronized and always have the same playback status" — these explain why MA2 preset timing layers do not map 1:1. — [Stonex copy of gMA3 1.0.0.2 release notes](https://www.stonexsl.com/wp-content/uploads/2019/descargas_pdf/Release_Notes_1.0.0.2.pdf)

**Real-world quality reports**
- **[anecdotal, 2026 (~Feb)]** "all P/T fixture types lost proper XYZ behavior after conversion show from 2->3"; a converted show "lost almost all fixture types"; users call converted shows "unsatisfactory"; suggested alternative: two-console setup, MA2 outputs DMX into an MA3 that records it into looks/presets — "time-consuming and depends on a clean preset workflow." — [MA forum thread 69773 "switch from gMA2 to gMA3 - which way?"](https://forum.malighting.com/forum/thread/69773-switch-from-gma2-to-gma3-which-way/)
- **[anecdotal, 2022]** If converted fixture types appear only as "FixtureType #", export them from the show's fixture-type list in MA3, not from the patched-fixtures list. — [MA forum thread 8066 "converted ma2 library in ma3"](https://forum.malighting.com/forum/thread/8066-converted-ma2-library-in-ma3/)
- **[anecdotal]** Fixtures whose type Source is "User" "are not created according the MA3 fixture standards" and behave oddly. — [MA forum thread 6073 "Importing fixture profiles"](https://forum.malighting.com/forum/thread/6073-importing-fixture-profiles/)
- **[documented/vendor]** ACT's fixture-profile guide: "grandMA2 profiles cannot be imported directly into grandMA3 - they have to get converted first"; start a new show in gMA2 onPC or Mode2, patch one of each fixture, "Use the grandMA2 software version that matches the grandMA3 software version", save as grandMA3, then in gMA3 export the fixture type and import into the target show. — [ACT KB 23941397](https://support.actentertainment.com/knowledgeBase/23941397)
- **[documented]** gMA3 manual, Import Fixture Types: library sources are "grandMA3 fixtures, Converted grandMA2 fixtures, Fixtures using GDTF format"; Source column distinguishes grandMA3 / grandMA2 / User. — [MA help: Import Fixture Types](https://help.malighting.com/grandMA3/2.0/HTML/ft_import.html)
- **[documented/vendor]** ACT Academy sells a course "MA2 to MA3 Show File Conversion" written against grandMA3 v1.4. — [ACT Academy course](https://academy.actentertainment.com/grandma3-show-file-conversion)
- **[anecdotal]** YouTube: "MA2 to MA3 Showfile Conversation" (short) and a Portuguese tutorial "Conversão ShowFile grandMA2 para grandMA3" exist; content not analysed. — [YouTube short](https://www.youtube.com/shorts/1nE0vkNFaeM); [YouTube PT tutorial](https://www.youtube.com/watch?v=z8MLarxk3Es)

### Inferences
- The converter is a **gMA2-side exporter** whose output is a gMA3 show file for a specific gMA3 version; a new third-party converter therefore competes with (or post-processes) that output rather than filling an empty gap for patch/groups/value presets. The gap is in macros, effects->phasers, timing/effect preset layers, selective presets edge cases, XYZ/MIB fidelity, and merging into an existing MA3 show.
- Because the converter is version-paired (gMA2 3.9.6x build <-> gMA3 version), and gMA3 2.x refuses show files older than 1.9, converted files older than 2023 may need a two-hop upgrade.
- The "record DMX from MA2 into MA3" workaround being seriously proposed in 2026 signals continued user dissatisfaction with converted-show fidelity for moving-light positions.

### Gaps
- Could not fetch the official converter help page or gMA2 3.9 release notes in full; the complete "known limitations" list and the exact build numbers for each converter improvement (e.g. which build added presets, sequences, timecode) are only partially captured.
- No release-note excerpt found describing conversion of MIB, layouts, images (a 2020 thread asks about images: [thread 4064](https://forum.malighting.com/forum/thread/4064-export-import-images-from-ma2-into-ma3/)), views, user profiles, or remotes.
- No quantitative real-world "success rate" data; only forum anecdotes.

---

## Key Question 2: Third-party / open-source tools (GitHub, Lua, Python, CSV/Excel) for MA2->MA3 patch, presets, groups, macros

### Takeaway
There is **no open-source end-to-end MA2->MA3 show converter**. What exists is fragmentary: (a) a free Python **macro converter** (fiets.de, ~2020) that rewrites gMA2 macro XML into gMA3 macro XML; (b) **GMA Toolbox** (Matthias Schöffmann, free, closed-source desktop app) with a bidirectional **Preset Mode2/3 Converter** (XML in/out, attribute-name mapping) and a **Patch Creator** that turns MVR/Depence/WYSIWYG data into gMA2/gMA3 patch macros; (c) paid Lua plugins for CSV/MVR patch import into MA3 (ma.tools PatchImporter) and MA3->MA2 patch export (Ctrl+Cee, 9.99 EUR); (d) assorted GitHub Lua/JS utilities that parse MA2/MA3 XML/CSV exports (patch-to-PDF, timecode tools) which are useful as format references but do not convert. Open MVR/GDTF Python libraries (open-stage pymvr/pygdtf, MIT) exist and are candidates for a bridge.

### Cited Findings

**Macro conversion**
- **[documented/tool page]** fiets.de "MA2 to MA3 Macro Converter": a Python script that "reads MA2 xml macrofile and spits directory full of MA3 ready macro files". Usage: unzip, place the macro XML in the script folder renamed `ma2 macros.xml`, run; output goes to `ma3macros`. License and repo not confirmed. — [fiets.de Downloads](https://fiets.de/downloads/)
- **[anecdotal]** Accompanying YouTube video "MA2 to MA3 Macro Converter" is ~6 years old (~2020), so it predates gMA3 1.5+ syntax changes. — [YouTube](https://www.youtube.com/watch?v=q_ifnfggqw0)
- **[documented]** Official position: macros are *not* converted by MA's converter; "Macro syntax has to be checked by hand". — [MA help: Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- **[documented]** gMA3 2.0 manual has "Macro Examples" that can serve as the target syntax reference. — [MA help: Macro Examples](https://help.malighting.com/grandMA3/2.0/HTML/macro_examples.html)

**Preset conversion**
- **[documented/tool page]** GMA Toolbox "Preset Mode Converter": "converts presets between grandMA2 and grandMA3 showfiles bidirectionally using XML import and export"; "transforms all key preset types, especially position and focus"; "multiple objects within one XML is possible"; added in Toolbox version 32.12, and version 36.3 "added converting attribute names between Mode2 and Mode3 presets". — [GMA Toolbox Preset Mode Converter](https://www.gmatoolbox.app/tools/preset-mode-converter/); [GMA Toolbox Changelog](https://www.gmatoolbox.app/changelog/)
- **[documented/tool page]** GMA Toolbox is described as free, standalone ("runs on its own. No Reaper plugins, no grandMA plugins"); tool list: Reaper File Maker, Timecode Creator, Timecode Fader Automate, Timecode To Marker, Macro Generator, Patch Creator, Layer Patch Macro, Preset Mode Converter, Report Generator (gMA2/3 patch, sequence and timecode XML exports -> CSV/XLS/PDF), Attribute Report, Number Converter, Range Value Translator, Pandora Inpoint Calculator. — [GMA Toolbox](https://www.gmatoolbox.app/)
- **[documented/tool page]** A separate site grandma.tools lists a "Preset Mode2/3 Converter" among many tools; relationship to GMA Toolbox unconfirmed. — [grandma.tools](https://grandma.tools/)
- **[documented, GitHub]** kevinhayen/grandma3_fixture_to_presets: Lua plugin generating presets from fixture files by executing visible console commands; tested on gMA3 v1.9.7.0. Not a converter but shows the "generate via command line" approach. — [GitHub](https://github.com/kevinhayen/grandma3_fixture_to_presets)

**Patch conversion / CSV / MVR import tools**
- **[documented/tool page]** GMA Toolbox "Patch Creator": "unified successor for both DEP2GMA and WYG2GMA converter tools - with MVR support"; MVR import "experimental"; "For grandMA3, support is currently limited to macro generation for patching, positioning, and group creation." Generates grandMA2 or grandMA3 macros from MVR/Depence/WYSIWYG data. — [GMA Toolbox Patch Creator](https://www.gmatoolbox.app/tools/patch-creator/)
- **[documented/tool page]** Legacy MVR2GMA (mschoeffmann.com): builds a grandMA2 fixture setup from MVR — fixture import, 3D positions/rotation, patch macro, "Generate groups based on MVR fixture type"; page says it is now part of GMA Toolbox and "this website will not be updated anymore." DEP2GMA FAQ: its macros "are just updating existing fixtures"; rotation export "experimental"; "no grandMA3 version of that converter is planned, since Depence2/R3 supports MVR natively." — [MVR2GMA](https://www.mschoeffmann.com/tools/mvr2gma-converter/); [DEP2GMA FAQ](https://www.mschoeffmann.com/tools/dep2gma-converter/faq/)
- **[documented/tool page]** ma.tools **PatchImporter** (paid, Lua plugin for gMA3): imports a CSV, maps CSV headers to MA3 patch properties, can create new fixtures or update existing ones; can "partially update patch and 3D positions from an MVR"; aimed at WYSIWYG/gaffer spreadsheets; current version V1.5.2.0 requires MA3 software V2.5.0.0 or higher; works on Console, onPC and onMac once registered. — [ma.tools PatchImporter](https://ma.tools/plugins/patchimporter); [ma3.tools mirror](https://ma3.tools/PatchImporter/)
- **[documented/tool page]** **MA3 Patch to MA2** (Ctrl+Cee via AddOnDesk, 9.99 EUR excl. tax): "automatically exports your current MA3 patch, including fixture addresses and 3D positions, and converts it into a format that can be directly imported into grandMA2", with "easy import via included MA2 macro"; fixture types are not converted; one 5/5 review. — [AddOnDesk MA3 Patch to MA2](https://addondesk.com/product/ma3-patch-to-ma2/)
- **[anecdotal, 2024]** Before that plugin, the suggested MA3->MA2 patch route was: export MVR from MA3 -> import into Vectorworks -> export with the Vectorworks grandMA2 plugin ("File → Export → Export grandMA2 Setup (XML)"); the plugin's import overwrites the existing MA2 patch. — [MA forum thread 8961 "Grandma 3 patch"](https://forum.malighting.com/forum/thread/8961-grandma-3-patch/); [ACT: Vectorworks and MA plugin](https://support.actentertainment.com/knowledgeBase/11589468)
- **[documented, GitHub]** schw4rzlicht/gma2.lua.importCSVPatch: gMA2 Lua plugin; onPC only, semicolon-delimited CSV without headers, fixtures must already exist before auto-patch. (gMA2 direction only.) — [GitHub](https://github.com/schw4rzlicht/gma2.lua.importCSVPatch)
- **[anecdotal, 2023]** MA3 has no built-in patch->Excel export; users point to a paid MAtools plugin and mvr-reader.com; a forum post includes a custom Lua script writing the patch to CSV on USB. — [MA forum thread 7813 "Patch export to csv file"](https://forum.malighting.com/forum/thread/7813-patch-export-to-csv-file/); [thread 8344](https://forum.malighting.com/forum/thread/8344-printing-out-my-patch-sheet/)

**GitHub utilities that parse MA2/MA3 formats (format references, not converters)**
- **[verified, GitHub]** Jannik-Hm/DEPRECATED-MA-Patch2PDF: JS web app (pdfmake), MIT; inputs "MA2 (MA3 with Exporter Plugin) CSV and XML (JSON with MA3 Plugin) patch files" from the Patch & Fixture Schedule view; archived read-only 18 Feb 2024; no named successor. — [GitHub](https://github.com/Jannik-Hm/DEPRECATED-MA-Patch2PDF)
- **[verified, GitHub]** leonreucher/grandma3-patch2pdf: gMA3 Lua plugin exporting the patch (Type, FID/CID, FixtureType+Mode, Name, Universe/Address) to PDF, based on catseye/pdf.lua; no license stated ("delivered as is"); 51 commits. — [GitHub](https://github.com/leonreucher/grandma3-patch2pdf)
- **[verified, GitHub]** patopesto/GrandMA3-Plugins: AGPL-3.0; ViewScaler, ScreenSwap, TimecodeExporter (CSV), APIDump (dumps Lua API to generate reference docs at grandma3.bambinito.net), PluginTemplate; 22 stars, updated Oct 2025. Useful as the most current open gMA3 Lua API reference. — [GitHub](https://github.com/patopesto/GrandMA3-Plugins)
- **[verified, GitHub topic page]** Other repos under topic `ma-lighting` (7 total): MacTirney/Audio-Visual-Scripts-and-Plugins (Lua for gMA2/gMA3/MagicQ, 10 stars, May 2024); chienchuanw/gma2-plugins (gMA2 Lua, Sep 2026) and gma2-vscode-extension (Jun 2026); oje-studio/ma2-tc-cut (gMA2 timecode ripple-cut tool, topic `grandma2-xml`, Aug 2026); linusgke/pyMAdot2. None convert MA2<->MA3. — [GitHub topic ma-lighting](https://github.com/topics/ma-lighting)
- **[documented, GitHub]** badasslighting/grandma-devkit: VS Code extension for writing gMA2/gMA3 Lua plugins (API completion, scaffolding, deploy, XML manifest checks). — [GitHub](https://github.com/badasslighting/grandma-devkit)
- **[documented, GitHub]** kinglevel/TimecodeBPMConvertMA3: changes timecode BPM inside gMA3; supports only CmdEvent and FaderEvent. — [GitHub](https://www.github.com/kinglevel/TimecodeBPMConvertMA3)
- **[verified, GitHub]** Niasus17/grandMA2-show-downgrade (MIT, 2026, 1 commit): Windows tool that downgrades gMA2 3.9.x `.show.gz` files to older 3.9 builds by rewriting the 4-byte little-endian version field at bytes 8–11 of the gzip-wrapped binary stream that starts with `MA DATA`; author states object layout is identical across 3.9.60/61/63; "MA Lighting does not offer this". Key insight for converter authors: **the native gMA2 `.show.gz` is a binary stream, not XML** — XML is only available via Export. — [GitHub](https://github.com/Niasus17/grandMA2-show-downgrade)
- **[documented/vendor]** Moving Light Assistant: gMA3 "exports its data as a series of XML files" via a shipped plugin whose versions are tied to gMA3 releases (1.x, 2.0.x, 2.1.x, 2.2.x); import into gMA3 via `Import Sequence Y "NAME.xml"` with files in `grandMA3/export`. Also documents exporting gMA2 data. — [MLA: Exporting grandMA3 Data](https://www.manula.com/manuals/avld/mla/14/en/topic/exporting-grandma3-data); [MLA: Importing into grandMA3](https://www.manula.com/manuals/avld/mla/14/en/topic/importing-sequence-and-timecode-files-into-the-grandma3); [MLA: Exporting grandMA2 Data](https://www.manula.com/manuals/avld/mla/131/en/topic/exporting-grandma-2-data)
- **[documented, app store]** "Export CueList for gma3" macOS app (App Store) exists; function not analysed. — [App Store](https://apps.apple.com/us/app/export-cuelist-for-gma3/id1518496291?mt=12)
- **[anecdotal, 2022]** Users hand-craft gMA3 XML files containing presets/macros for import; a Macro "Import Library" command with wildcard sometimes fails to load all macros (suspected async loading). — [MA forum thread 68183](https://forum.malighting.com/forum/thread/68183-create-custom-xml-file-with-presets-macros-etc/)

**Open MVR/GDTF libraries**
- **[verified, GitHub]** open-stage/python-mvr (`pymvr`, MIT, v1.0.6, 92 commits, 19 stars): reads and writes "most aspects of MVR 1.6 (DIN SPEC 15801:2023-12)"; used by BlenderDMX; MVR-xchange not implemented here (BlenderDMX has one). Sibling library pygdtf exists (topic tag). — [GitHub python-mvr](https://github.com/open-stage/python-mvr)

### Inferences
- The community has converged on **XML-export-based, object-type-specific converters** (macros, presets, patch) rather than whole-show conversion, because the native show file is binary and version-locked while `Export`/`Import` XML is stable and documented at the keyword level.
- The two most mature third-party pieces are closed-source freeware (GMA Toolbox) or cheap paid Lua plugins; a new open-source project would be the first OSS codebase covering MA2->MA3 preset/patch/group/macro translation.
- Attribute-name mapping (Mode2 -> Mode3 names) was a late addition (GMA Toolbox v36.3), confirming that attribute naming is a concrete, solvable sub-problem and a known pain point.

### Gaps
- Could not read fiets.de, GMA Toolbox, ma.tools, mschoeffmann pages directly: licenses, exact release dates, and supported gMA3 versions are unconfirmed.
- No Reddit or Facebook-group threads surfaced on this topic via web search (Reddit content is poorly indexed in search engines); r/grandMA / r/lightingdesign experience is therefore absent from these notes.
- "Convert2TCTo3" (plugins.apox.hu) appeared as a result title suggesting an MA2->MA3 timecode converter, but the page could not be found/fetched; unverified.
- GitHub API search was blocked at research time, so the GitHub topic page was the only systematic enumeration; repos not tagged `ma-lighting` may have been missed.

---

## Key Question 3: Commercial tools, consultants, services

### Takeaway
No dedicated "MA2->MA3 show conversion service" was found. Commercial offerings are: ACT Academy's paid training course on the official converter (written for gMA3 1.4), cheap Lua plugins (ma.tools PatchImporter, Ctrl+Cee MA3 Patch to MA2 at 9.99 EUR, Fixture Fix for gMA2 XML fixture libraries), and freeware GMA Toolbox. ETC runs a free grandMA->Eos conversion mailbox (m2e@etcconnect.com) — a relevant precedent for a service model, but a different target console.

### Cited Findings
- **[documented/vendor]** ACT Academy "MA2 to MA3 Show File Conversion": "short official-training course" for "anyone who has a grandMA2 show file they want to migrate to grandMA3"; "references grandMA3 version 1.4". — [ACT Academy](https://academy.actentertainment.com/grandma3-show-file-conversion/671562)
- **[documented/vendor]** ETC: "send your Grand MA show file to m2e@etcconnect.com and they will send the converted file back within 2 business days", converting "to the most recent Eos software version unless otherwise communicated." — [ETC: GrandMA Showfile to Eos Conversion](https://support.etcconnect.com/ETC/Consoles/Eos_Family/Software_and_Programming/GrandMA_Showfile_to_Eos_Conversion)
- **[documented/tool page]** Carrot Industries "Fixture Fix": paid editor for "GrandMa 2 XML librairies for now, I'm working on the GDTF support for the next update" (GDTF support status unconfirmed); also listed on AddOnDesk. — [Carrot Industries](https://carrot-industries.com/product/fixture-fix-full-version/); [AddOnDesk Fixture Fix](https://addondesk.com/product/fixture-fix/)
- **[documented/tool page]** AddOnDesk is a marketplace listing multiple MA Lighting plugins (Ctrl+Cee store: MA3 Patch to MA2, Single Step, One Shot). — [AddOnDesk MA Lighting](https://addondesk.com/manufacturers/ma-lighting/)
- **[documented/tool page]** ma.tools PatchImporter is paid (registration required); price not captured. — [ma.tools](https://ma.tools/plugins/patchimporter)
- **[anecdotal/blog]** An "Oreate AI Blog" post "Bridging the Gap: Seamlessly Migrating Your GrandMA2 Shows to GrandMA3" repeats the matching-version advice; appears to be a low-quality secondary source. — [Oreate AI blog](https://www.oreateai.com/blog/bridging-the-gap-seamlessly-migrating-your-grandma2-shows-to-grandma3/4b6d95339e6b5b189d44f8ed886d632b)

### Inferences
- The market treats migration as a **programmer-skill task** (training) rather than a product; the only "service" precedent is from a competitor (ETC) using migration as a sales tool.

### Gaps
- No pricing for ACT course or PatchImporter captured. No consultants explicitly advertising MA2->MA3 showfile migration were found.

---

## Key Question 4: MVR as a bridge — can MA2 export MVR? MA2-XML -> MVR converters?

### Takeaway
grandMA2 does **not** export MVR (no source found claiming it does); it exports its own XML (patch/fixture types via `Export`, and Vectorworks' "grandMA2 Setup (XML)" exchange format). grandMA3 both imports and exports MVR natively (Patch > Import MVR; Patch Export pop-up offers grandMA3 XML or MVR). No ready-made MA2-XML->MVR converter was found; the practical bridges people use are Vectorworks (gMA2 XML plugin on one side, MVR on the other) or GMA Toolbox Patch Creator (MVR -> gMA2/gMA3 patch macros). MVR import into gMA3 carries positions, addresses and IDs but produces "dummy" fixture types when GDTFs are missing or when the types are converted gMA2 types.

### Cited Findings
- **[documented]** gMA3 2.4 manual: Patch Export pop-up can write the whole patch or selected fixtures "in either grandMA3 XML or MVR format"; MVR import is under Partial Show Read / Show Creator. — [MA help: Patch and Fixture Setup (2.4)](https://help.malighting.com/grandMA3/2.4/HTML/patch.html)
- **[documented/vendor]** ACT: place the `.mvr` in `gma3_library/mvr`, open Patch, use "Import MVR", exit Patch saving changes. — [ACT KB 24789197](https://support.actentertainment.com/knowledgeBase/24789197)
- **[anecdotal/moderator, ~2022]** On gMA3 v1.7 an MVR "can carry positions, DMX addresses and IDs even when the fixture types are converted grandMA2 types, but those types may create dummy fixtures that must be swapped back for library fixtures." — [MA forum thread 7861 "Import XML patch"](https://forum.malighting.com/forum/thread/7861-import-xml-patch/)
- **[anecdotal, Feb 2026]** Plain MVR import can leave fixtures as dummies; re-importing MVR into an already patched show "can reset XYZ data"; advice: import the needed fixture types first, then assign them in the patch. — [MA forum thread 69763 "How to import a patch correctly?"](https://forum.malighting.com/forum/thread/69763-how-to-import-a-patch-correctly/)
- **[documented/vendor]** Depence guide: after MVR import "Replace the imported dummy fixtures with fixtures from the grandMA3 library" by selecting same-type fixtures, right-clicking the FixtureType column and choosing library fixture+mode. — [Depence: How to export MVR to grandMA3](https://help.depence.com/depence-tips-and-tricks/how-to-export-mvr-to-grandma3)
- **[anecdotal, 2020]** Vectorworks "will generate 'dummy-GDTF' files for the non-existing ones"; "an export from grandMA3 afterwards will not automatically generate the GDTF files"; "every data point in the MVR file will increase the patch parameter count in the MA3 patch." — [MA forum thread 3705 "Export MVR to Vectorworks"](https://forum.malighting.com/forum/thread/3705-export-mvr-to-vectorworks/); [thread 4081](https://forum.malighting.com/forum/thread/4081-vectorworks-2020-to-ma-3-gtdf-patch-issue/)
- **[documented/vendor]** Vectorworks has a grandMA2 export plugin: "File → Export → Export grandMA2 Setup (XML)"; MVR is "an open protocol created by Vectorworks, MA Lighting and Robe". — [ACT: Vectorworks and MA plugin](https://support.actentertainment.com/knowledgeBase/11589468); [MLP MVR Import/Export](https://www.mlp-lighting.com/import/mvr-import-export/)
- **[documented/tool page]** GMA Toolbox Patch Creator: MVR -> grandMA2 or grandMA3 macros (patch, position, groups); MVR import experimental. — [GMA Toolbox Patch Creator](https://www.gmatoolbox.app/tools/patch-creator/)
- **[documented]** gMA2 `Export` keyword documentation exists (XML export of objects). — [MA help gMA2: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- **[verified, GitHub]** pymvr (MIT) can write MVR 1.6, so an MA2-XML -> MVR writer is technically straightforward to build. — [GitHub python-mvr](https://github.com/open-stage/python-mvr)

### Inferences
- MVR is a viable **patch+position** bridge only; it cannot carry groups (except via Toolbox-generated macros), presets, cues or macros. An MA2-XML->MVR tool would be new prior art but would still hit the GDTF/fixture-type mapping problem (dummy fixtures).
- For a new converter, writing gMA3 XML patch directly (which gMA3 can import alongside MVR) avoids the dummy-fixture round trip, while MVR remains useful for interop with visualizers/CAD.

### Gaps
- No source explicitly stating "grandMA2 cannot export MVR" was found; this is inferred from absence (no gMA2 release note or help page mentions MVR export, and the 2024 forum workaround routes through Vectorworks).
- mvr-reader.com was mentioned by users but not examined.

---

## Key Question 5: Fixture-type mapping MA2 -> GDTF/MA3; attribute-name mismatches; helper tools

### Takeaway
The only official route for an MA2 fixture profile is to convert it via the gMA2 converter (Mode2/onPC) into a gMA3 fixture type with Source="grandMA2"; such types cannot be re-exported as GDTF, are reported to lose XYZ/pan-tilt behavior, and the recommended best practice is to swap them for native gMA3-library or GDTF types. No MA2-XML->GDTF converter was found (GDTF Share forum: "not aware of such tool"; GDTF is a zip with description.xml so custom scripts are feasible). MA's own Fixture Share offers only the reverse (GDTF -> gMA2). Attribute-name mapping Mode2->Mode3 is handled by GMA Toolbox's preset converter; attribute-level official mapping tables were not found.

### Cited Findings
- **[documented/vendor]** "grandMA2 Fixture Profiles must be converted before they can be used in a grandMA3 show"; use matching gMA2/gMA3 versions; profiles with Source "grandMA2" cannot be exported as GDTF. — [ACT KB 23941397](https://support.actentertainment.com/knowledgeBase/23941397)
- **[documented]** MA Fixture Share provides a "grandMA2 GDTF Converter" that turns a GDTF into a grandMA2 fixture profile (GDTF -> MA2 only). — [MA Fixture Shares](https://www.malighting.com/training-support/fixture-shares/)
- **[anecdotal, GDTF forum, older]** Thread "Create GDTF fixture from MA2 and CAD": reply "not aware of such tool"; another: "GDTF is just a zipped folder, you can open it and edit the description.xml by hand or by custom tools". — [GDTF Share forum topic 1003](https://gdtf-share.com/forum/index.php?%2Ftopic%2F1003-create-gdtf-fixture-from-ma2-and-cad%2F=)
- **[anecdotal, 2026]** "all P/T fixture types lost proper XYZ behavior after conversion show from 2->3". — [MA forum thread 69773](https://forum.malighting.com/forum/thread/69773-switch-from-gma2-to-gma3-which-way/)
- **[anecdotal, Feb 2024]** gMA2's patch-level "swap pan and tilt" has no gMA3 equivalent; workaround is to copy the fixture type and swap pan/tilt addresses; built-in visualizer did not follow. — [MA forum thread 8954 "SWAP PAN AND TILT"](https://forum.malighting.com/forum/thread/8954-swap-pan-and-tilt/)
- **[anecdotal]** Inverted pan in MA3D fixed by editing "from phys"/"to phys" of the pan attribute in the fixture type. — [MA forum thread 50375](https://forum.malighting.com/forum/thread/50375-fixtures-pan-tilt-the-wrong-way-in-ma3d/)
- **[documented/vendor]** ACT: several pan/tilt pairs map to the same XYZ point; conversions from extreme pan/tilt to XYZ can flip. — [ACT: General XYZ Programming Suggestions](https://support.actentertainment.com/knowledgeBase/20655378)
- **[documented]** gMA2 XYZ docs: XYZ adds virtual channels; pan/tilt converted to stage coordinates with a Dist value. — [MA help gMA2: XYZ](https://help.malighting.com/grandMA2/en/help/key_xyz.html)
- **[anecdotal, 2022]** gMA3 onPC 1.8.8.2 does not list `.xml`/`.xmlp` (gMA2 fixture files) in `gma3_library/fixturetypes`, only `.gdtf` — i.e. gMA2 fixture XML cannot be side-loaded. — [MA forum thread 8142](https://forum.malighting.com/forum/thread/8142-on-pc-1-8-8-2-does-not-find-xml-and-xmlp-but-gdtf-files-in-f-grandma3-gma3-libra/)
- **[anecdotal, 2022]** gMA3 `.pxml` fixture files vs `.xml` conversion question exists (fiets.de author involved). — [MA forum thread 7629](https://forum.malighting.com/forum/thread/7629-convert-pxml-fixture-type-files-to-xml/)
- **[documented/tool page]** GMA Toolbox v36.3 "added converting attribute names between Mode2 and Mode3 presets" — evidence that attribute names differ and a mapping table exists inside that tool. — [GMA Toolbox Changelog](https://www.gmatoolbox.app/changelog/)
- **[documented/vendor]** ACT guide on replicating gMA2 Forms with gMA3 Phasers: "any standard grandMA2 Form can be replicated with two or more grandMA3 Phaser Steps using the right combination of Width, Transition, Acceleration, and Deceleration." — [ACT KB 25504931](https://support.actentertainment.com/knowledgeBase/25504931)
- **[documented, vendor]** Unreal Engine's DMX plugin documents the GDTF description schema (FDMXGDTFFixtureType etc.), one of several public GDTF schema references. — [Epic docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Plugins/DMXGDTF/FDMXGDTFFixtureType)

### Inferences
- A new converter should **not** try to carry MA2 fixture types; it should map MA2 fixture type+mode names to gMA3 library / GDTF Share types (fuzzy match on manufacturer/model/mode and DMX footprint) and emit a review list. Converted "Source=grandMA2" types are a known dead end (no GDTF export, XYZ problems).
- Attribute-name mapping tables (e.g. gMA2 `COLORRGB1` vs gMA3 `ColorRGB_R`, etc.) must be built; GMA Toolbox demonstrates feasibility but is closed source.

### Gaps
- No official published MA2<->MA3 attribute-name mapping table found.
- No tool found that converts gMA2 fixture XML to GDTF; Fixture Fix's promised GDTF support is unverified.
- Could not verify GDTF-forum thread date.

---

## Key Question 6: Forum/Reddit/community lessons — what is realistically convertible vs must be re-programmed; recommended workflows

### Takeaway
Community consensus (MA forum 2020–2026): patch/groups/worlds/filters and value-layer presets come across; sequences/executors partially; effects (gMA2 Forms -> gMA3 Phasers), macros, timing/effect preset layers, MIB and XYZ-based position work must be rebuilt. Recommended workflow: export with the **matching** gMA2 3.9.6x build for your gMA3 version, use Mode2/onPC not Parallels, convert fixture types separately and replace them with native gMA3/GDTF types, then audit. Some 2026 users prefer re-programming from scratch or recording MA2 DMX output into MA3.

### Cited Findings
- **[anecdotal/moderator, 2022]** Convert from the matching gMA2 version; list of converted objects; "not all parts... can or will be converted". — [MA forum thread 7931](https://forum.malighting.com/forum/thread/7931-convert-show-from-ma2-to-ma3/)
- **[anecdotal, 2026]** Converted shows "unsatisfactory"; fixture types lost; XYZ behavior lost; alternative of two-console DMX recording. — [MA forum thread 69773](https://forum.malighting.com/forum/thread/69773-switch-from-gma2-to-gma3-which-way/)
- **[anecdotal, 2020]** Only patched fixtures convert; "you can't program your show in MA2 and convert it to MA3 then." — [MA forum thread 4617](https://forum.malighting.com/forum/thread/4617-import-show-gma2-on-pc-to-gma-3-on-mac/)
- **[anecdotal, 2022]** Converted MA2 libraries are usable but the workflow "isn't obvious": export patch from MA2, reimport into MA3, export fixture type from fixture-type list. — [MA forum thread 8066](https://forum.malighting.com/forum/thread/8066-converted-ma2-library-in-ma3/)
- **[anecdotal, 2022]** "Upgrading Showfile" thread covers version-stepping of converted shows. — [MA forum thread 8131](https://forum.malighting.com/forum/thread/8131-upgrading-showfile/)
- **[anecdotal, 2020]** Custom MA2 fixture profiles thread (same conversion path). — [MA forum thread 3860](https://forum.malighting.com/forum/thread/3860-custom-ma2-fixture-profiles/); [thread 3968](https://forum.malighting.com/forum/thread/3968-import-grand-ma-2-fixtures-to-grand-ma-3/)
- **[documented]** Effects: only "simple predefined forms" convert; converted effects become acceleration/deceleration values; macros not converted. — [MA help: Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- **[documented/vendor]** Forms -> Phasers rebuild guidance. — [ACT KB 25504931](https://support.actentertainment.com/knowledgeBase/25504931)
- **[documented/vendor]** Mode2 boot on gMA3 hardware is how to run the gMA2 software (and thus the converter) on consoles/nodes. — [ACT KB 19641288](https://support.actentertainment.com/knowledgeBase/19641288)
- **[documented]** Selective pan/tilt presets and phaser circles improved in gMA3 2.4 ("AS OF 2.4 THIS IS MUCH BETTER"), relevant to how converted selective position presets behave. — [MA forum thread 68858](https://forum.malighting.com/forum/thread/68858-is-it-even-possible-to-create-a-true-circle-form-with-selective-pan-tilt-presets/); [gMA3 2.4 news](https://www.malighting.com/news/article/grandma3-software-release-version-24-is-out-now-1500/)

### Inferences
- Realistic automated scope: patch (with type re-mapping), groups, worlds/filters, value-layer presets (dimmer/color/gobo/beam; position with caution), sequence cue values and basic fade/delay, executor assignments, macro *text* with a syntax translation table. Must be re-done: Forms->Phasers, MIB, bitmap/layout effects, timecode details (Runs/Switch Off/Record Mode), user profiles/views, XYZ.
- The single most-repeated piece of workflow advice is **version pairing** (gMA2 3.9.60.x build must match the target gMA3 version), which implies any third-party tool must also pin its output schema to a gMA3 version.

### Gaps
- No Reddit, Facebook-group, Blue Room, ControlBooth or Lighting-Network threads were surfaced by web search; community evidence here is entirely MA-forum based.
- No large-scale or quantified user survey; all quality claims are single-user anecdotes.

---

## Key Question 7: Published schema/format documentation (gMA2 XML xsd, gMA3 XML) that tools rely on

### Takeaway
No official XSD for either gMA2 or gMA3 XML exports was found. Tools rely on the documented `Export`/`Import` keywords (per-object XML files), reverse-engineered export samples, and the gMA3 Lua API (official Plugins manual plus community APIDump-generated references). The native gMA2 `.show.gz` is a gzip-wrapped binary ("MA DATA" header), not XML; gMA3 show files likewise are not plain XML in the library folder. Export XML schemas are implicitly versioned: MLA ships separate export plugins per gMA3 release, and gMA3 2.x refuses pre-1.9 shows.

### Cited Findings
- **[documented]** gMA3 `Export` keyword: "save objects from the current show file as a smaller file"; syntax `Export [Object] ["Object_Name" or Object_Number] (If Drive [Drive_Number])`; multiple objects go to separate XML files unless a shared name is given. — [MA help gMA3: Export Keyword](https://help.malighting.com/grandMA3/2.0/HTML/keyword_export.html)
- **[documented]** gMA2 `Export` keyword page exists. — [MA help gMA2: Export](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- **[documented]** gMA3 Plugins manual: plugin exports as XML plus optional separate Lua files; import needs the XML. — [MA help gMA3: Plugins](https://help.malighting.com/grandMA3/2.0/HTML/plugins.html)
- **[anecdotal]** Patch export writes to `grandMA3/export/` on USB; exporting a grouping fixture yields one XML with a child entry per sub-fixture. — [MA forum thread 4440](https://forum.malighting.com/forum/thread/4440-export-pacth-list-pdf/)
- **[documented/vendor]** Vyv Photon docs: gMA3 fixture types export as one XML per type; fixture layers export as a single XML. — [docs.vyv.ca](https://docs.vyv.ca/step-by-step-tutorials/albion/albion-and-lighting-console-workflow-integration/photon-grandma-project-link/3.-export-fixture-types-and-grandma-patch)
- **[documented/vendor]** MLA: gMA3 export plugin versions tied to gMA3 1.x / 2.0.x / 2.1.x / 2.2.x (schema drift per release). — [MLA Exporting grandMA3 Data 1.4.1](https://www.manula.com/manuals/avld/mla/141/en/topic/exporting-grandma3-data)
- **[verified, GitHub]** gMA2 `.show.gz` internal format facts (binary stream, version bytes 8–11 LE, pointer bytes 16–19). — [Niasus17/grandMA2-show-downgrade](https://github.com/Niasus17/grandMA2-show-downgrade)
- **[verified, GitHub]** Community gMA3 Lua API reference generated by APIDump (grandma3.bambinito.net), unofficial GitHub wiki and TypeScript type definitions referenced from patopesto/GrandMA3-Plugins; AGPL-3.0. — [GitHub](https://github.com/patopesto/GrandMA3-Plugins)
- **[documented]** gMA3 Lua-based MCP servers (bdstark/gma3-mcp, chienchuanw/gma2-mcp) exist, exposing object get/store operations — another indication the Lua object model is the de-facto API rather than a schema. — [glama gma3-mcp](https://glama.ai/mcp/servers/bdstark/gma3-mcp); [glama gma2-mcp](https://glama.ai/mcp/servers/chienchuanw/gma2-mcp/tree)
- **[documented, legacy]** The old gMA2 manual had a "Show Converter" concept page (grandMA1 -> grandMA2), a precedent for MA's converter design. — [manual.malighting.com Conc_ShowConverter](http://www.manual.malighting.com/view/concept/Conc_ShowConverter.html)

### Inferences
- A new converter should treat **gMA2 XML exports** (Export Fixture/Group/Preset/Sequence/Macro ... and the Patch & Fixture Schedule CSV/XML) as input and emit **gMA3 per-object XML** for `Import`, pinned to a gMA3 version, plus macros for anything without an import path. Schema must be derived empirically from export samples per version; no XSD exists to validate against.
- Working from the binary `.show.gz` is not realistic (undocumented, version-locked); only Niasus17's byte-patching exists as prior art.

### Gaps
- No official or community XSD/DTD located for gMA2 or gMA3 export XML.
- No public element-by-element documentation of gMA3 XML (e.g. `<GMA3 DataVersion=...>` root, Preset/Sequence/Cue structures) found via search; this must come from sample files.
