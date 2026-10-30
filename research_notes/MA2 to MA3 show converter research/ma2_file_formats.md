# grandMA2 show file and XML export formats (for a third-party parser)

Research scope: grandMA2 v3.x (3.3 through 3.9.60) show file and XML export formats as a converter would read them.

Access note for the report writer: the hosts help.malighting.com, help2.malighting.com, forum.malighting.com, manula.com (Moving Light Assistant manual), focustrack.co.uk, cuepoints-docs.super.site, support.actentertainment.com and mschoeffmann.notion.site could not be fetched (DNS blocked). Statements attributed to those pages below come from search-engine result snippets of those pages, not from reading the full pages; they are cited to the official URL so the writer can verify. Everything marked "GitHub sample" was read directly from raw files on github.com, which was reachable. Several of those samples are console exports (identifiable by the `xml-stylesheet` processing instructions and real `Info showfile` names); others are tool-generated files that were written to be imported by the console. Each sample is labelled accordingly.

---

## Key question 1: What is the `.show.gz` show file, is it readable by third parties, and are there reverse-engineering efforts?

### Takeaway
The `.show.gz` is MA's proprietary, gzip-compressed binary show file; nothing found documents its internal layout, and no public reverse-engineering project was found. Every third-party integration found (MLA, FocusTrack, CuePoints, ETC's own MA-to-Eos service, community Lua tools) works from the console's XML exports, not from the show file.

### Cited Findings
- The grandMA2 show file carries the `.show.gz` extension; the Load Show pop-up lists "all saved shows as .show.gz file and their backups as .backup file" (up to ten `.backup` copies are kept, oldest deleted after the tenth) — [grandMA2 manual: Load show](https://help.malighting.com/grandMA2/en/help/key_backup_menu_load_show.html); [grandMA2 manual: Backup menu](https://help.malighting.com/grandMA2/en/help/key_backup_menu.html)
- Command-line form: `LoadShow` "loads the show file my_showfile.show.gz from the gma2/shows folder of the corresponding software version" — [grandMA2 manual: Load show](https://help.malighting.com/grandMA2/en/help/key_backup_menu_load_show.html)
- MA 3D and the grandMA2 console "use the same show files (.show.gz)" — [grandMA2 manual: MA 3D data management](https://help.malighting.com/grandMA2/en/help/ma_3d/key_ma3d-data-management.html)
- The manual states "it is not possible to export or import the show, or a part of the show to any other console format" — [grandMA2 manual: Export and Import](https://help.malighting.com/grandMA2/en/help/key_export_and_import.html)
- ETC staff on ControlBooth: an MA2 show file cannot be used directly; "Because of the way the MA2 show file is packaged, that conversion is best done by our tech support group" — ETC runs a conversion service (send the show to m2e@etcconnect.com, returned within 2 business days) — [ControlBooth thread](https://www.controlbooth.com/goto/post?id=342403); [ETC support article: GrandMA Showfile to Eos Conversion](https://support.etcconnect.com/ETC/Consoles/Eos_Family/Software_and_Programming/GrandMA_Showfile_to_Eos_Conversion)
- An older ETC community thread reports that exporting to ASCII from grandMA2 onPC loses fixture information because MA2 treats channels and fixtures as separate item types — [ETC Community thread](https://community.etcconnect.com/control_consoles/eos-family-consoles/f/eos-family/16169/is-it-possible-to-convert-a-showfile-from-grandma2-gz-or-show-to-an-etc-showtime-for-ion-or-an-ascii-file)
- MA's official migration path is "Save as grandMA3" in the grandMA2 Backup menu, available "only on a grandMA2 onPC or in Mode2 on a grandMA3 console"; output is written to `C:\ProgramData\MALightingTechnology\gma3_x.x.x\shared\shows` — [grandMA2 manual: Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- The MA2-to-MA3 converter carries patch (fixture types, attributes, fixtures), DMX profiles, DMX universes, multipatch fixtures, presets with timings, sequences, cues and cue timings, groups, worlds, filters; MA2 effects are converted into acceleration/deceleration values; barndoor attributes become shaper attributes; object Infos become Notes — [grandMA2 manual: Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html); [help2 PDF "Limitations"](https://help2.malighting.com/Media/TopicPdf/86298/31)
- Documented converter limitations: embedded presets "not convertible, yet"; only simple predefined effect forms; effect data in presets and timing-only presets excluded; macros not converted; X-keys X5/X6/X15/X16 not converted; remote type/target not converted; "Only executors that have sequences or selective effects assigned are converted"; not supported in Parallels Desktop — [grandMA2 manual: Limitations 3.9](https://help2.malighting.com/Page/grandMA2/limitations/en/3.9)
- Release notes for 3.9.x mention converter bug fixes such as "preset links in cues could get lost during conversion process" — [grandMA2 release notes](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)
- Third-party converter pages (convert.guru) describe the .show file only generically as "entirely proprietary" and are not technically reliable — [convert.guru](https://convert.guru/fr/ma2-convertisseur)

### Inferences
- (Inferred) Because MA itself documents no binary structure, the ETC service exists, and every community tool goes through XML, a converter should treat the `.show.gz` as opaque and rely on the console/onPC `Export` keyword plus `Save as grandMA3` as its only data paths.
- (Inferred) gunzipping a `.show.gz` yields a binary blob (not XML); no source was found that says otherwise, and the name pattern `*.show.gz` with MA's "gzip" suffix is the only hard fact.

### Gaps
- No source found describing the decompressed content of `.show.gz` (serialization format, headers, versioning). No GitHub project parsing `.show.gz` was found in code search.
- No MA forum thread on show-file internals could be read (forum blocked).

---

## Key question 2: XML export formats, disk locations, root element and namespace/schema header

### Takeaway
Every grandMA2 export is a UTF-8 XML file (often with BOM) whose root is `<MA>` in namespace `http://schemas.malighting.de/grandma2/xml/MA`, carrying `xsi:schemaLocation` pointing at `http://schemas.malighting.de/grandma2/xml/<major>.<minor>.<stream>/MA.xsd` and `major_vers`/`minor_vers`/`stream_vers` attributes, followed by one `<Info datetime showfile>` element and then one or more object elements (`Layer`, `FixtureType`, `Group`, `Preset`, `Sequ`, `Macro`, `Timecode`, `Plugin`, ...). Files land in `gma2/importexport` (USB), `/data/ma/actual/gma2/ImportExport` (console) or `C:\ProgramData\MA Lighting Technologies\grandMA\gma2_V_x.x\importexport` (onPC), with some object types going into dedicated sibling folders.

### Cited Findings

Locations and command behaviour (official manual, via search snippets):
- "The function can be done, either by the Command Line or the Graphical User Interface (GUI)"; "Exported content stores in a .XML file"; it "is located in an importexport directory on the console, an USB stick in gma2/importexport" and on onPC e.g. `C:\ProgramData\MA Lighting Technologies\grandMA\gma2_V_3.3\importexport` — [grandMA2 manual: Export and Import](https://help.malighting.com/grandMA2/en/help/key_export_and_import.html)
- "Commonly exported object types are organized in folders according to object type, e.g. Effect-folder, Macro-folder, FixtureType (library-folder). Object types without a dedicated folder will be placed in the importexport folder" — [grandMA2 manual: Export and Import](https://help.malighting.com/grandMA2/en/help/key_export_and_import.html)
- Exportable object types listed on that page include Effects, Macros, Presets, Sequences, Executors, Groups, Timecodes, Cameras "among others"; Layouts and Worlds are not named in the snippet. For Macros, Effects, Masks, MAtricks, Gobo Bitmaps, User Profiles and DMX nodes "it is easier to use the GUI" (Setup > Import Export) — [grandMA2 manual: Export and Import](https://help.malighting.com/grandMA2/en/help/key_export_and_import.html); [Export GUI](https://help.malighting.com/grandMA2/en/help/key_ei_export_gui.html)
- The `path` option example in the manual is `"/data/ma/actual/gma2/ImportExport"` (console path) — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- Export writes to "the current selected hard drive"; to target USB "select it at the Backup Menu, or type `selectdrive 4`" (4 = first USB stick) — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- Fixture layer GUI export: Setup > Patch and Fixtures, select layer, "Export Layer" with "Only XML" option; result lands on the USB stick by default — [VYV Photon docs](https://docs.vyv.ca/step-by-step-tutorials/albion/albion-and-lighting-console-workflow-integration/photon-grandma-project-link/3.-export-fixture-types-and-grandma-patch); each fixture type "is exported in a separate .xml file on the USB stick by default" — [Pixera guide](https://pixera.helpjuice.com/timeline-/pixera-to-grandma2-fixture-export-guide)
- Lua plugins locate the export folder at runtime via `gma.show.getvar('PATH') .. '/importexport/'` — [FlorianANAYA/GrandMA2-help AttributePicker.lua (GitHub sample)](https://github.com/FlorianANAYA/GrandMA2-help/blob/master/AttributePicker/AttributePicker.lua)

Root element header (all GitHub samples agree):
- 3.9.60 layer export header (console export, has stylesheet PIs):
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <?xml-stylesheet type="text/xsl" href="styles/fixture+layer+layers@html@default.xsl"?>
  <?xml-stylesheet type="text/xsl" href="styles/fixture+layer+layers@csv.xsl" alternate="yes"?>
  <MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60">
  	<Info datetime="2021-09-28T09:21:41" showfile="testshow" />
  ```
  — [bozi6/hello-world testshow.xml (GitHub sample)](https://github.com/bozi6/hello-world/blob/master/ma2xml2capture/xmlz/testshow.xml); same header in [thisis-romar/nomad-toronto-av NOMADFIXPATCHJUNE2026.xml](https://github.com/thisis-romar/nomad-toronto-av/blob/main/08-lighting/source-showfile/NOMADFIXPATCHJUNE2026.xml)
- Other observed version triples: 3.2.2, 3.3.2, 3.3.4, 3.4.0, 3.5.0, 3.6.187, 3.7.0, 3.8.0, 3.9.0, 3.9.60 — [aGuyNamedJonas/grandma2-snippets](https://github.com/aGuyNamedJonas/grandma2-snippets), [yoep/gma2-plugins 2_groups.xml](https://github.com/yoep/gma2-plugins/blob/master/2_groups.xml), [locimation/ma2-tc-import TC_Import.xml](https://github.com/locimation/ma2-tc-import/blob/master/TC%20Import/TC_Import.xml), [cbdevnet/xlaser](https://github.com/cbdevnet/xlaser/blob/master/console-support/kitinfo@xlaser@opengl.xml)
- The XSL stylesheet PIs differ per object type: sequences use `styles/sequ@html@default.xsl`, `styles/sequ@executorsheet.xsl`, `styles/sequ@trackingsheet.xsl`; timecode uses `styles/timecode@sheet.xsl`; layers use `styles/fixture+layer+layers@html@default.xsl` and `...@csv.xsl` — [joeyjoestar111/AuraLuxMuse to_xml_cue.py](https://github.com/joeyjoestar111/AuraLuxMuse/blob/main/outputs_pamoe_softalign_show9/to_xml_cue.py); [bozi6 halaltimecode.xml](https://github.com/bozi6/hello-world/blob/master/ma2tc2ma3_xmls_factory/halaltimecode.xml); [gelframe/GrandMA2-Patcher XML.cs](https://github.com/gelframe/GrandMA2-Patcher/blob/master/Config/XML.cs)
- The manual's `style` option says the default is "xml with a style sheet for timecode, messages, sequence, fixture, layer, and layers"; other styles are `html` and `csv`; option `transform` converts into the style; option `schema` "exports MA .xml schema definition" — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- The console accepts import files whose `major_vers`/`minor_vers` do not match the schemaLocation (community plugins write `major_vers="1" minor_vers="0"` against a 3.9.0 schema URL) — [gauthierGrsse/JDC1-GMA2-Layout-View main.lua](https://github.com/gauthierGrsse/JDC1-GMA2-Layout-View/blob/master/main.lua); [FlorianANAYA ColorPicker.lua](https://github.com/FlorianANAYA/GrandMA2-help/blob/master/ColorPicker/ColorPicker.lua)
- A community tool exists specifically to batch-change the version attributes of MA2 XML files (MA2-xml-version-changer), implying version headers matter for import — [szymonplotkowski GitHub profile](https://github.com/szymonplotkowski)
- File naming: when no filename is given "one .xml file will be created for each object in object list", named from the object's properties; fixture type library files follow the pattern `manufacturer@fixture@mode.xml` (e.g. `bitfocus@companion_v2.0@00.xml`, `kitinfo@xlaser@opengl.xml`, `paul_hermann@pi_medienserver_rocky@04.xml`) — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html); [bitfocus/companion](https://github.com/bitfocus/companion/blob/main/webui/public/bitfocus%40companion_v2.0%4000.xml); [Pahegi/sacn-mediaserver](https://github.com/Pahegi/sacn-mediaserver)

Top-level object elements observed directly under `<MA>` (GitHub samples):
| Object | Root child element | Source |
|---|---|---|
| Fixture layer / patch | `<Layer index name>` (one per layer) | bozi6 testshow.xml, chienchuanw/gma2-plugins test fixtures |
| Fixture type | `<FixtureType index name mode>` | cbdevnet/xlaser, qmsk/gma2, bitfocus/companion |
| Group | `<Group index name>` | stooEe/Ma2-Sandbox group_102_all.xml |
| Layout | `<Group index name>` containing `<LayoutData>` (layouts are exported as a Group with LayoutData) | stooEe/Ma2-Sandbox layout.xml, FlorianANAYA ColorPicker.lua |
| Preset | `<Preset index name preset_mode SpecialUse>` | stooEe preset_*.xml, aGuyNamedJonas dimmer-fade-presets.xml |
| Sequence | `<Sequ index name timecode_slot forced_position_mode>` | only-cue, TCHelper, AuraLuxMuse |
| Macro | `<Macro index name>` with `<Macroline index>` children | aGuyNamedJonas apc40-macros.xml |
| Timecode | `<Timecode index name lenght play_mode slot frame_format>` | bozi6 halaltimecode.xml |
| Plugin | `<Plugin index execute_on_load name luafile>` | yoep/gma2-plugins, locimation |

### Inferences
- (Inferred) A parser should match on `localName` and ignore the namespace, which is what ma2-patch-viewer does; it should also tolerate missing `Info`, BOM, and `xml-stylesheet` PIs — [routmoute/ma2-patch-viewer](https://github.com/routmoute/ma2-patch-viewer)
- (Inferred) Since `Export ... /schema` exists, a developer with onPC can obtain the authoritative MA.xsd directly from the console rather than from the (unreachable) `schemas.malighting.de` URL.
- (Inferred) The `styles/` folder referenced by the PIs is shipped with the console/onPC under the importexport directory; the PIs are harmless to a parser.

### Gaps
- MA.xsd itself was not found on any reachable host or on GitHub (searched by targetNamespace and filename).
- Exact dedicated-folder names (e.g., whether presets or sequences get their own folder, and the exact "library" folder name for fixture types) were not readable from the manual page; only the examples "Effect-folder, Macro-folder, FixtureType (library-folder)" were in the snippet. No source confirmed a folder literally named `fixture_layers`.
- No sample of World, Executor/Page, Effect, Camera, Mask, MAtricks, Gobo Bitmap, User Profile, DMX node, or Message exports was found on GitHub.

---

## Key question 3: How the exported sequence/cue XML represents values, fades/delays, parts, tracking, effects

### Takeaway
A sequence export is `<Sequ index name timecode_slot forced_position_mode>` whose children are `<Cue>` elements (first is a `xsi:nil="true"` placeholder for cue zero); each cue holds `<Number number sub_number>`, optionally `<MibCue number sub_number>`, `<CueDatas>` with one `<CueData value_multipart_index effect_multipart_index>` per fixture-attribute containing `<Channel fixture_id attribute_name>` and `<Value>text</Value>`, then `<CuePart index name basic_fade basic_outfade ...>` and optional `<InfoItems><Info>`. Values appear as plain numbers or keywords such as `Release`. Fade/delay at attribute level, preset references, and effect references were NOT observed in any reachable sample.

### Cited Findings
- Sequence header and cue-zero placeholder exactly as generated for import (derived by the author "from real v3.9.x console exports"): 
  ```xml
  <?xml-stylesheet type="text/xsl" href="styles/sequ@html@default.xsl"?>
  <MA ... major_vers="3" minor_vers="9" stream_vers="60">
  	<Info datetime="2026-07-19T12:00:00" showfile="MyShow" />
  	<Sequ index="0" name="Opening" timecode_slot="255" forced_position_mode="0">
  		<Cue xsi:nil="true" />
  		<Cue index="1">
  			<Number number="1" sub_number="0" />
  			<CuePart index="0" name="Tied first" />
  		</Cue>
  ```
  — [chienchuanw/only-cue MA2SequenceXMLGeneratorTests.swift](https://github.com/chienchuanw/only-cue/blob/main/OnlyCueTests/MA2SequenceXMLGeneratorTests.swift); [only-cue golden/ma2-export-v1.json](https://github.com/chienchuanw/only-cue/blob/main/golden/ma2-export-v1.json)
- Same `Sequ`/`Cue`/`Number` pattern is used by the TCHelper Lua plugin that writes sequences for import — [mittim88/TCHelper TCHelper.lua](https://github.com/mittim88/TCHelper/blob/main/TC_Helper/TCHelper.lua)
- `sub_number` is in thousandths (cue 3.5 → `sub_number="500"`); MA2 cue numbers carry at most three decimals; the generator's comments say "cue-only imports (no CueDatas) are proven by TCHelper / MLA" and "All cue data (name, fades) lives on part 0 in MA2. Zero fades and empty names are omitted — the import fills defaults"; fades are written as `basic_fade` and `basic_outfade` attributes on `<CuePart>` — [chienchuanw/only-cue MA2SequenceXMLGenerator.swift](https://github.com/chienchuanw/only-cue/blob/main/OnlyCue/MA2/MA2SequenceXMLGenerator.swift)
- Cue IDs allowed in MA2 range 0.001 to 9999.999; "cues are arranged in sequences and are divided in parts" — [grandMA2 manual: Cue keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_cue.html)
- `CueDatas` structure as parsed from real console exports by a Python reader (`read_sequence_cue.py`): a `SequencePool` container may wrap `Sequ` elements or `Sequ` may be top-level; each cue child with `index` is a cue; cue children are `Number` (`number`, `sub_number`), `MibCue` (`number`, `sub_number`), `CueDatas`, `CuePart` (`index`); each `CueData` has attributes `value_multipart_index` and `effect_multipart_index` and children `Channel` (`fixture_id`, `attribute_name`) and `Value` (element text) — [joeyjoestar111/AuraLuxMuse utils/read_sequence_cue.py](https://github.com/joeyjoestar111/AuraLuxMuse/blob/main/utils/read_sequence_cue.py)
- Regenerated sequence file (tool output in MA2 import format, 3.9.60 header), showing `Value` as a keyword:
  ```xml
  	<Sequ index="0" timecode_slot="255" forced_position_mode="0">
  		<Cue index="1">
  			<Number number="1" sub_number="0"/>
  			<CueDatas>
  				<CueData value_multipart_index="0" effect_multipart_index="0">
  					<Channel fixture_id="201" attribute_name="DIM"/>
  					<Value>Release</Value>
  				</CueData>
  				<CueData value_multipart_index="0" effect_multipart_index="0">
  					<Channel fixture_id="201" attribute_name="IRIS MACRO"/>
  					<Value>Release</Value>
  				</CueData>
  ```
  — [AuraLuxMuse cue_xml/Jazz_c.xml](https://github.com/joeyjoestar111/AuraLuxMuse/blob/main/outputs_pamoe_softalign_show9/cue_xml/Jazz_c.xml); emitter: [to_xml_cue.py](https://github.com/joeyjoestar111/AuraLuxMuse/blob/main/outputs_pamoe_softalign_show9/to_xml_cue.py)
- Export command examples: `Export Sequence 1 "FT_MA2_Cues.xml"`, ranges `Export Sequence a thru b`; file size and import time grow with the number of sequences, fixtures and instructions — [FocusTrack grandMA2 tips](https://focustrack.co.uk/tips/grandMA2/grandMA2.html)
- A forum answer confirms a sequence can be exported as XML with `Export Sequence` — [MA forum: Export Sequence Sheet](https://forum.malighting.com/forum/thread/66059-export-sequence-sheet/)
- MA2 cue timing can be stored per cue or per preset type (`/fade_<presettype>`, `/delay_<presettype>` Assign options) and individual attribute timings take precedence — [ACT Entertainment: gMA2 Syntax Options - Assign](https://support.actentertainment.com/knowledgeBase/11662799)
- Moving Light Assistant has a script "MA2 Export Cue List XML" that writes a cue list as XML with a default fade time per cue — [MLA manual](https://www.manula.com/manuals/avld/mla/14/en/topic/script-ma2-export-cue-list-xml)

### Inferences
- (Inferred from attribute names) `value_multipart_index`/`effect_multipart_index` on `CueData` map a value to a cue part; `MibCue` records the Move-In-Black target cue; `CuePart` carries part-level timing and name. Attribute-level fade/delay, preset links and effect references almost certainly appear as additional attributes/children inside `CueData`/`CuePart` in a full console export, but no sample proving this was reachable.
- (Inferred) Values are stored per fixture and attribute (not per DMX channel), keyed by `fixture_id` + `attribute_name` (library attribute name such as `DIM`, `PAN`, `COLORRGB1`), the same keys used in preset exports (see Q5). Tracking is therefore implicit: a cue only lists the attributes it changes; `Release` is written as a value keyword.

### Gaps
- No console-original sequence export containing `CueDatas` with preset references, fade/delay, or effect data was reachable. The AuraLuxMuse sample is tool-regenerated from parsed exports (header lacks stylesheet PIs on the second declaration and `showfile="generated_showfile"`), so attributes it does not emit (preset links, timings) are unknown.
- The exact attributes on `CuePart` (beyond `index`, `name`, `basic_fade`, `basic_outfade`), on `Sequ`, and how an effect in a cue is referenced remain undocumented in reachable sources.

---

## Key question 4: Fixture type XML (Modules / ChannelTypes / ChannelFunctions / ChannelSets, attributes, features, preset types)

### Takeaway
The fixture type export is `<FixtureType index name mode>` holding `short_name`, `manufacturer`, `short_manufacturer`, optional `InfoItems`, then `<Modules><Module index name class beamtype beam_angle beam_intensity><Body><Size/></Body><ChannelType .../>...</Module></Modules>`, `<Instances><Instance index module_index patch X/>...</Instances>`, plus `Wheels`, `VirtualFunctionBlocks`, `FixtureMacroCollect`, `AutoPresets`, `RdmNotifications`. Each `ChannelType` names the MA2 library `attribute`, `feature` and `preset` (preset type) and its `coarse`/`fine` DMX offsets; `ChannelFunction` children carry from/to physical ranges and 24-bit DMX ranges, and `ChannelSet` children are named DMX ranges.

### Cited Findings
- Conceptual model: a fixture type has at least one Module and one Instance of that module; modules contain the attributes mapped to DMX channels; Module `Class` (None, Conventional, Marker, ...) affects MA 3D visualization — [grandMA2 manual: Fixture anatomy](https://help.malighting.com/grandMA2/en/help/key_adv_fixture_anatomy.html); [Modules](https://help2.malighting.com/grandMA2/en/help/key_adv_fixture_anatomy_modules.html)
- Attribute hierarchy: "Attributes are organized into features. Features are organized in Preset Types"; "An attribute is a single unit no matter if it uses 1, 2 or 3 DMX channels"; subattributes sit below attributes; numeric addressing `PresetType 3.2.1` = preset type 3, feature 2, attribute 1, but the manual warns attribute numbers can change when new fixtures are added and advises referencing "the unique attribute library name instead" — [grandMA2 manual: Attribute, Feature, Preset](https://help.malighting.com/grandMA2/en/help/key_basic_fixture_attribute_feature_preset.html); [Attribute keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_attribute.html); [PresetType keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_presettype.html); [Patch attributes](https://help.malighting.com/grandMA2/en/help/key_patch_attributes.html)
- Full-structure sample (v3.2.2 library file written for the console; GitHub sample):
  ```xml
  <FixtureType index="2" name="XLaser" mode="OpenGL">
    <InfoItems>
      <Info>XLaser OpenGL Mode ...</Info>
      <Info type="Revision" date="2017-05-22T00:00:00">Initial file</Info>
    </InfoItems>
    <short_name>XLsr</short_name>
    <manufacturer>#kitinfo</manufacturer>
    <short_manufacturer>#ktnfo</short_manufacturer>
    <Modules index="0">
      <Module index="0" name="Main Module" class="Headmover" beamtype="Spot" beam_angle="10" beam_intensity="10000">
        <Body><Size x="0.5" y="0.42" z="0.66" /></Body>
        <ChannelType index="0" attribute="PAN" feature="POSITION" preset="POSITION" coarse="1" fine="2" default="32767.5">
          <ChannelFunction index="0" from="-270" to="270" min_dmx_24="0" max_dmx_24="16777215" physfrom="-270" physto="270"
              subattribute="PAN" subattribute_user_name="Pan" attribute="PAN" attribute_user_name="Pan"
              feature="POSITION" feature_user_name="Position" preset="POSITION" preset_user_name="Position">
            <ChannelSet index="0" name="center" from_dmx="32768" to_dmx="32768" />
          </ChannelFunction>
        </ChannelType>
        <ChannelType index="6" attribute="SHUTTER" feature="SHUTTER" preset="BEAM" coarse="9" highlight_value="0">
          <ChannelFunction index="0" name="Open" from="0" to="1" min_dmx_24="0" max_dmx_24="65535" physfrom="1" ... />
          <ChannelFunction index="1" name="Strobe" from="1.1" to="50" min_dmx_24="65536" max_dmx_24="8388607" physfrom="1" ... />
        </ChannelType>
  ```
  — [cbdevnet/xlaser kitinfo@xlaser@opengl.xml](https://github.com/cbdevnet/xlaser/blob/master/console-support/kitinfo@xlaser@opengl.xml)
- Element inventory from that file: MA, Info, FixtureType, InfoItems, short_name, manufacturer, short_manufacturer, Modules, Module, Body, Size, ChannelType, ChannelFunction, ChannelSet, Instances, Instance, Wheels, AutoPresets. ChannelType attributes: index, attribute, feature, preset, coarse, fine, default, highlight_value. ChannelFunction attributes: index, name, from, to, min_dmx_24, max_dmx_24, physfrom, physto, subattribute, subattribute_user_name, attribute, attribute_user_name, feature, feature_user_name, preset, preset_user_name. ChannelSet attributes: index, name, from_dmx, to_dmx. Instance attributes: index, module_index — same source
- A 3.9.60-era multi-instance (pixel) fixture type adds `color="ff0000"` on RGB ChannelTypes, `preset="DIMMER"`, and the trailing blocks `<Wheels index="2"/>`, `<VirtualFunctionBlocks index="3"/>`, `<FixtureMacroCollect index="5"/>`, `<Body/>`, `<AutoPresets index="4"/>`, `<RdmNotifications index="6"><RdmNotification index="0" Type="Absent" Subcategory="RDM Warning"/></RdmNotifications>`; its `<Instances index="1">` lists 20 `<Instance index module_index patch X/>` entries whose `patch` values step by the module footprint (4, 7, 10 ... 58) and `X` gives 3D position — [qmsk/gma2 library/qmsk-led@...20xrgb.xml](https://github.com/qmsk/gma2/blob/master/library/qmsk-led%40qmsk-led-24v-ws2811-20xrgb%4020xrgb.xml); generator: [qmsk/gma2 fixture-gen.py](https://github.com/qmsk/gma2/blob/master/library/fixture-gen.py)
- Companion's officially distributed MA2 profile (3.4.0) uses ChannelFunction with `subattribute="MACROSELECT" attribute="MACROS" feature="MACRO" preset="CONTROL"` and many `ChannelSet` entries (`from_dmx`/`to_dmx` single-value ranges) — [bitfocus/companion bitfocus@companion_v2.0@00.xml](https://github.com/bitfocus/companion/blob/main/webui/public/bitfocus%40companion_v2.0%4000.xml)
- Media-server profiles exported from 3.9.60 use `attribute="MEDIASERVERINPUTDIRECTORY" feature="MEDIA" preset="GOBO"` with `physto="255"` — [Pahegi/sacn-mediaserver](https://github.com/Pahegi/sacn-mediaserver/blob/main/fixtures/paul_hermann%40pi_medienserver_rocky%4004.xml)
- Community guidance: to modify a fixture, "export into XML via the console's Export feature, then edit that XML file, and then Import"; `.xmlp` is a different (packed) format, so export XML instead — [MA forum: Import fixture to fixture builder](https://forum.malighting.com/forum/thread/63037-import-fixture-to-fixture-builder/)
- Several open-source generators write MA2 fixture XML (RCG-Fixture-Creator, tecnicaRCG; DmxBox; music-auto-show), confirming the format is stable enough to hand-author — [tecnicaRCG/RCG-Fixture-Creator-](https://github.com/tecnicaRCG/RCG-Fixture-Creator-); [hansimglueck/DmxBox](https://github.com/hansimglueck/DmxBox); [AlexProgrammerDE/music-auto-show](https://github.com/AlexProgrammerDE/music-auto-show)

### Inferences
- (Inferred) `min_dmx_24`/`max_dmx_24` express ranges on a 24-bit scale regardless of the channel's real resolution (16777215 = full), while `from`/`to` are the MA "percent-like" encoder range and `physfrom`/`physto` are physical units; `default` is on a 16-bit scale (32767.5 = centre). A converter to GDTF/MA3 must rescale accordingly.
- (Inferred) MA2 attribute library names in `ChannelType@attribute` (`DIM`, `PAN`, `TILT`, `COLORRGB1..3`, `GOBO1`, `SHUTTER`, `ZOOM`, `FOCUS`, `CTO`, `BLADE1A`, `MSPEED`, `DIMMERCURVE`, `COLORMIXER`, `IRIS MACRO`) are the same strings that appear in `Channel@attribute_name` in preset and cue exports, so they are the join key between patch, presets and cues.

### Gaps
- The show-wide attribute/feature/preset-type definition export (the "Attribute & Encoder Grouping" table) was not found as an XML sample; only its concept is documented.
- No sample of `Wheels` with content, `VirtualFunctionBlocks` with content, or `AutoPresets` with content was found.

---

## Key question 5: Preset XML (universal / global / selective) and the values inside

### Takeaway
A preset export is `<Preset index name preset_mode SpecialUse>`; selective values are listed under `<Values><Channels><PresetValue Value="..."><Channel fixture_id attribute_name [subfixture_id]/></PresetValue>...`, while universal/global data appears under `<Attributes><PresetValue><Attribute name/>` (attribute-wide) and `<ChannelTypes><PresetValue><ChannelType fixture_type module attribute/>` (per fixture type); timing-only presets use a `<Fades>` container instead of `<Values>`. `preset_mode="Universal"` was observed; the exact strings for Global and Selective were not observed.

### Cited Findings
- Selective-style preset export (v3.8.0, pan/tilt values per fixture):
  ```xml
  <Preset index="0" SpecialUse="Normal">
    <Values>
      <Channels>
        <PresetValue Value="-10">
          <Channel fixture_id="1" attribute_name="PAN" />
        </PresetValue>
        <PresetValue Value="60">
          <Channel fixture_id="1" attribute_name="TILT" />
        </PresetValue>
  ```
  — [stooEe/Ma2-Sandbox data/preset_2.1.xml](https://github.com/stooEe/Ma2-Sandbox/blob/main/data/preset_2.1.xml)
- Dimmer preset export with many attributes per fixture, values on a 0-100 scale (`DIM` 0, `COLORRGB1..3` 100, `SHUTTER` 41.601875, `IRIS` 51.365948, `PAN` -0.0041199359) and multi-cell fixtures addressed with `<Channel fixture_id="101" subfixture_id="2" attribute_name="DIM"/>`; attributes seen include DIM, DIM2, FOCUSDISTANCE, COLORRGB1-3, SHUTTER, IRIS, PAN, TILT, CTO, GOBO1, BLADE1A/B, ZOOM, FOCUS, MSPEED — [stooEe/Ma2-Sandbox data/preset_0.1.xml](https://github.com/stooEe/Ma2-Sandbox/blob/main/data/preset_0.1.xml)
- Universal timing-only presets (v3.3.4, console export with `Info showfile`):
  ```xml
  <Preset index="0" name="F 0.0" preset_mode="Universal" SpecialUse="Normal">
    <Fades>
      <Attributes>
        <PresetValue Value="0">
          <Attribute name="DIM" />
        </PresetValue>
      </Attributes>
      <ChannelTypes>
        <PresetValue Value="0">
          <ChannelType fixture_type="Sharpy Standard Lamp on" module="1" attribute="DIM" />
        </PresetValue>
        <PresetValue Value="0">
          <ChannelType fixture_type="Sharpy Standard Lamp on" module="1" attribute="DIMMERCURVE" />
        </PresetValue>
      </ChannelTypes>
    </Fades>
  </Preset>
  ```
  — [aGuyNamedJonas/grandma2-snippets single-cue-magic/dimmer-fade-presets.xml](https://github.com/aGuyNamedJonas/grandma2-snippets/blob/master/single-cue-magic/dimmer-fade-presets.xml)
- Manual definitions: Selective presets (marked with a red "S") are locked to the fixtures that had values when stored; Universal presets apply to fixture types other than those used during creation; older (3.3) manual text defines Global as usable "by all the fixtures of the same fixture type" — [grandMA2 quick start: Making presets (3.9)](https://help.malighting.com/grandMA2/en/help/grandma2_quick_start_guide/key_13_making_presets.html); [same page, 3.3](https://help2.malighting.com/Page/grandMA2/13_making_presets/en/3.3)
- Presets reference fixtures by Fixture ID (reported for v3.0.0.5 onward), so the recommended workflow is to export the fixture profile too and patch to the same Fixture IDs in the destination show; reported import syntax `Import "filename" At Preset x.a` — [MA forum: Exporting Presets](https://forum.malighting.com/forum/thread/56396-exporting-presets/)
- Export syntax: `Export Preset x.y Thru z "filename"` where x is the preset type (pool) number — [ACT Entertainment: Exporting & Importing Presets](https://support.actentertainment.com/knowledgeBase/2177377); MLA's macro uses `Export Preset 0.1 thru 0.999 "mla_presets_all"` and notes the range must be widened for pools with more than 999 presets — [MLA manual: Exporting grandMA2 data](https://www.manula.com/manuals/avld/mla/14/en/topic/exporting-grandma-2-data)
- A community "Preset Mode Converter" claims bidirectional MA2<->MA3 preset conversion via XML export/import — [mschoeffmann.notion.site Preset Mode Converter](https://mschoeffmann.notion.site/Preset-Mode-Converter-2259d45a5e8480f1a6c7e5212206c34d)
- The MA2->MA3 built-in converter does not convert embedded presets, effect data inside presets, or timing-only presets — [grandMA2 manual: Limitations 3.9](https://help2.malighting.com/Page/grandMA2/limitations/en/3.9)

### Inferences
- (Inferred) The three containers map to the three preset scopes: `Channels/Channel` = selective (per fixture [+subfixture]); `ChannelTypes/ChannelType` = global (per fixture type + module); `Attributes/Attribute` = universal (per attribute). A universal preset export carries all three (or at least the latter two) so the console can apply it to any fixture.
- (Inferred) `<Values>` holds the stored values and `<Fades>` the stored fade times; a `<Delays>` sibling is likely for delay times (pattern-based guess, not observed).
- (Inferred) When `preset_mode` is absent (stooEe samples) the preset is selective, the default mode; the stooEe preset files have `showfile="lua"`, so they may have been written by a Lua plugin or exported from a show literally named "lua"; the structure matches the console-exported dimmer-fade file, so it is treated as representative.

### Gaps
- Exact `preset_mode` strings for Global and Selective were not observed (only "Universal").
- No sample of a preset containing effect data, a `Delays` block, color-mixing (CMY/HSB) data, or embedded-preset references was found.
- The ACT and MA forum pages could not be read in full; the fixture-ID dependency statement comes from a search snippet.

---

## Key question 6: Command-line / macro automation for bulk export (exact syntax)

### Takeaway
`Export [Object-list] ["filename"] /option=value` with shortcut `Exp`; omit the filename to get one XML per object; options include `noconfirm` (`nc`), `overwrite` (`o`), `path` (`p`), `style`, `transform` (`t`), `schema`, and `Export /?` lists them. Third-party tools (MLA, FocusTrack, CuePoints) ship macros that chain `Export Layer`, `Export FixtureType`, `Export Preset x.1 Thru x.999`, `Export Group`, `Export Sequence`, `Export Timecode` lines to dump a whole show.

### Cited Findings
- Syntax: `Export [Object-list] ["filename"] / [option] = [option value]`; typed as `Export` or `Exp`; "If no filename is entered to the keyword, one .xml file will be created for each object in object list"; examples `Export Macro 1 Thru 10 "MyMacros"`, `Export Effect 1`; `Export /?` lists options — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- Options: `noconfirm` (nc) suppresses the confirmation pop-up; `path` (p) e.g. `"/data/ma/actual/gma2/ImportExport"`; `style` = html | csv | default (default = xml + stylesheet); `overwrite` (o) replaces an existing file; `transform` (t) converts into the given style; `schema` exports the MA XML schema definition — [grandMA2 manual: Export keyword](https://help.malighting.com/grandMA2/en/help/key_keyword_export.html)
- Drive selection: `selectdrive 4` for the first USB stick, or pick the drive in the Backup menu — same source
- Command-line export topic exists separately from the GUI export topic — [grandMA2 manual: Export via command line](https://help.malighting.com/grandMA2/en/help/key_ei_export_commandline.html); [Export via GUI](https://help.malighting.com/grandMA2/en/help/key_ei_export_gui.html)
- MLA's bulk-export macro lines include `Export Preset 0.1 thru 0.999 "mla_presets_all"` (repeated per preset type, first 999 presets of each pool) and `Export FixtureType 31 "mla_fixture_Type_31"` (its macro covers only the first 30 fixture types; more need extra lines) — [MLA manual: Exporting grandMA2 data](https://www.manula.com/manuals/avld/mla/14/en/topic/exporting-grandma-2-data); MLA ships a `gma2` folder to drop on a USB stick containing the macro — [MLA installed components](https://www.manula.com/manuals/avld/mla/14/en/topic/installation-installed-components)
- FocusTrack: run an "export all layers" macro for the patch, then `Export Sequence 1 "FT_MA2_Cues.xml"`; ranges accepted — [FocusTrack grandMA2 tips](https://focustrack.co.uk/tips/grandMA2/grandMA2.html)
- CuePoints: `Export Timecode X` (X e.g. `1 Thru 10`) creates XML in the import/export folder; CuePoints only imports cues within track bounds so timecode offsets must match — [CuePoints docs: import grandMA2](https://cuepoints-docs.super.site/import-grandma2)
- Timecode export files use `styles/timecode@sheet.xsl`; Waerfa publishes an "Export Timecode for grandMA2" tool and an "Export CueList" tool — [waerfa.com Export Timecode](https://www.waerfa.com/export-timecode-gma2); [waerfa.com Export CueList](https://www.waerfa.com/export-cuelist-gma2)
- Import side (for round-trip testing): `Import "filename" At Preset x.a` — [MA forum: Exporting Presets](https://forum.malighting.com/forum/thread/56396-exporting-presets/); Lua plugins import generated XML with `gma.cmd('Import "layouttemp.xml" At Layout N')`-style commands after writing into `importexport` — [FlorianANAYA/GrandMA2-help](https://github.com/FlorianANAYA/GrandMA2-help)
- Macro XML format (for writing an export macro as a file): 
  ```xml
  <Macro index="9" name="REFRESH LEDs">
    <Macroline index="0">
      <text>SetVar $apc40-op = &quot;refresh-leds&quot;</text>
  ```
  — [aGuyNamedJonas/grandma2-snippets apc40-macros.xml](https://github.com/aGuyNamedJonas/grandma2-snippets/blob/master/apc40-mapping/apc40-macros.xml); contrast with grandMA3 macro XML (`<GMA3 DataVersion="1.4.0.2"><Macro Name Guid><MacroLine Command Wait/>`) — [bozi6/hello-world orig/vivaldi_macro.xml](https://github.com/bozi6/hello-world/blob/master/ma2tc2ma3_xmls_factory/orig/vivaldi_macro.xml)
- Timecode export sample (console export, 3.9.60):
  ```xml
  <Timecode index="0" name="Halalba" lenght="89171" play_mode="Play" slot="TC Slot 2" frame_format="30 FPS">
    <Track index="0" active="true" expanded="true">
      <Object name="Halalba tancoltatott lany 2.3">
        <No>30</No><No>1</No><No>2</No><No>3</No>
      </Object>
      <SubTrack index="0">
        <Event index="0" command="Goto" pressed="true" step="1">
          <Cue name="Sotet 100"><No>1</No><No>18</No><No>1</No></Cue>
        </Event>
        <Event index="1" time="450" command="Goto" pressed="true" step="2">
          <Cue name="Nyito kep 101"><No>1</No><No>18</No><No>2</No></Cue>
        </Event>
  ```
  Other attributes seen later in the file: `fader_command`, `fader_level`, `fade_overwrite` — [bozi6/hello-world halaltimecode.xml](https://github.com/bozi6/hello-world/blob/master/ma2tc2ma3_xmls_factory/halaltimecode.xml)
- Group export sample (console export, 3.8.0): `<Group index="101" name="ALL"><Appearance Color="ff0003"/><Subfixtures><Subfixture fix_id="201"/>...<Subfixture fix_id="1" sub_index="2"/>...</Subfixtures></Group>` — [stooEe/Ma2-Sandbox group_102_all.xml](https://github.com/stooEe/Ma2-Sandbox/blob/main/data/group_102_all.xml)
- Layout export sample (3.9.60): `<Group index="1" name="SSLEDm6"><Subfixtures>...</Subfixtures><LayoutData index marker_visible background_color visible_grid_h visible_grid_w snap_grid_h snap_grid_w default_gauge subfixture_view_mode><SubFixtures><LayoutSubFix center_x center_y size_h size_w background_color icon show_id show_type function_type select_group><image/><Subfixture fix_id sub_index/></LayoutSubFix>...` ; plugins also emit `<CObjects>` for macro/executor objects in layouts — [stooEe/Ma2-Sandbox layout.xml](https://github.com/stooEe/Ma2-Sandbox/blob/main/data/layout.xml); [FlorianANAYA ColorPicker.lua](https://github.com/FlorianANAYA/GrandMA2-help/blob/master/ColorPicker/ColorPicker.lua)
- Patch/layer export sample (3.9.60 console export):
  ```xml
  <Layer index="1" name="robotz">
    <Fixture index="0" name="SSLEDm6 1" fixture_id="201">        <!-- dimmer-type fixtures use channel_id="1" instead -->
      <FixtureType name="5 Sunstrip LED RGB Mode 6"><No>5</No></FixtureType>
      <AbsolutePosition><Location x="0" y="0" z="0"/><Rotation x="0" y="-0" z="0"/><Scaling x="1" y="1" z="1"/></AbsolutePosition>
      <SubFixture index="0" react_to_grandmaster="true" color="ffffff">
        <Patch><Address>1</Address></Patch>
        <AbsolutePosition>...</AbsolutePosition>
        <Channel index="0"/><Channel index="1"/><Channel index="2"/><Channel index="3"/>
      </SubFixture>
  ```
  `FixtureType@name` is "<index> <name>" and `<No>` is the fixture type index; `Address` is the absolute DMX address (e.g. 7974 = universe 16 address 294); multi-instance fixtures list one `SubFixture` per instance — [stooEe/Ma2-Sandbox patch.xml](https://github.com/stooEe/Ma2-Sandbox/blob/main/data/patch.xml); [bozi6 testshow.xml](https://github.com/bozi6/hello-world/blob/master/ma2xml2capture/xmlz/testshow.xml); [chienchuanw/gma2-plugins test fixtures](https://github.com/chienchuanw/gma2-plugins/blob/main/tests/repatch-from-layer/fixtures/single-instance.xml); GrandMA2-Patcher additionally emits `is_multipatch`, `module_index`, `patch`, `x/y/z` names and a `Layers` element with index 3 — [gelframe/GrandMA2-Patcher XML.cs](https://github.com/gelframe/GrandMA2-Patcher/blob/master/Config/XML.cs)

### Inferences
- (Inferred) A complete "dump everything" macro for a converter would be: `SelectDrive 4` (or set path), then `Export Layer 1 Thru` / `Export FixtureType 1 Thru`, `Export Group 1 Thru`, `Export Preset 0.1 Thru 0.999` ... `Export Preset 9.1 Thru 9.999` (and higher pools as needed), `Export Sequence 1 Thru`, `Export Macro 1 Thru`, `Export Effect 1 Thru`, `Export Timecode 1 Thru`, `Export Executor ...`, each with `/nc /o`. Only the individual object-type keywords (Layer, FixtureType, Preset, Sequence, Macro, Effect, Timecode, Group, Executor) are documented; World/Layout/Page export keywords were not confirmed for MA2.
- (Inferred) The absolute `Address` in layer exports equals `(universe-1)*512 + address`, based on the 7974 sample; not confirmed by documentation.

### Gaps
- The full option table and the complete list of exportable object keywords on the Export keyword page could not be read (page blocked); e.g. whether `Export World`, `Export Layout`, `Export Page`, `Export Filter` are valid is unconfirmed.
- No sample of Effect or Executor export XML was found.

---

## Key question 7: grandMA2 onPC availability for generating test exports

### Takeaway
grandMA2 onPC is a free Windows download from malighting.com (product-archive page), runs offline without hardware, is capped at 4,096 parameters (output requires MA hardware), supports `Export` and `Save as grandMA3`, and writes exports to `C:\ProgramData\MA Lighting Technologies\grandMA\gma2_V_<ver>\importexport`.

### Cited Findings
- "grandMA2 onPC is available free of charge" with a Downloads section on the product page — [MA Lighting product archive: grandMA2 onPC](https://www.malighting.com/product-archive/product/grandma2-onpc-grandMA2_onPC/)
- Installation: download from www.malighting.com, run installer with admin rights, standard directory `C:\ProgramData\MA Lighting Technologies\grandma`; "the install directory is not modifiable in the grandMA2 onPC"; installs .NET Framework 4.0; Windows 7 through Windows 11 listed — [grandMA2 manual: onPC installation](https://help.malighting.com/grandMA2/en/help/key_introduction_installation_of_grandma2_onpc.html); [onPC system requirements](https://help.malighting.com/grandMA2/en/help/key_introduction_system_requirements_grandma2_onpc.html)
- Parameter limit: "The maximum parameter count with grandMA2 onPC is 4.096 parameters" regardless of connected wings/nodes; onPC alone outputs nothing without MA hardware (command wing unlocks 2,048, 2Port Node onPC 512, 2Port Node onPC PRO 1,024) — [grandMA2 wing quick manual](https://help.malighting.com/grandMA2/en/help/grandma2_quick_manual_onpc_solutions/key_grandma2_wing_intended_use.html); [Thomann onPC command wing](https://www.thomann.co.uk/ma_lighting_grandma3_onpc_command_wing.htm)
- grandMA2 3.9 documentation is dated 2025-06-06; the latest schema seen in exports is 3.9.60; grandMA3 "Mode2" runs the grandMA2 software on MA3 hardware (version table: MA3 1.0 = MA2 3.8, etc.) — [grandMA2 help home](https://help.malighting.com/grandMA2/en/help/); [Mode2 version specification](https://help2.malighting.com/Page/grandMA2/mode2_version_specification/en/3.9)
- "Save as grandMA3" is available on onPC; not supported under Parallels Desktop — [grandMA2 manual: Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- Export folder on onPC: `C:\ProgramData\MA Lighting Technologies\grandMA\gma2_V_3.3\importexport` (version-specific folder name) — [grandMA2 manual: Export and Import](https://help.malighting.com/grandMA2/en/help/key_export_and_import.html)

### Inferences
- (Inferred) For a converter developer, onPC 3.9.x is sufficient to load any `.show.gz`, run bulk `Export` macros, run `Export /schema` to get MA.xsd, and run "Save as grandMA3" to produce reference MA3 output for validating a custom converter.

### Gaps
- Direct download URL and exact current installer build (3.9.60.x) could not be verified from the archive page (not fetchable).
- macOS availability was not checked.

---

## Useful GitHub repositories found (for the report writer)

| Repo | What it offers |
|---|---|
| [stooEe/Ma2-Sandbox](https://github.com/stooEe/Ma2-Sandbox) | Real preset, group, layout, patch exports in `data/` |
| [bozi6/hello-world](https://github.com/bozi6/hello-world) | 3.9.60 layer exports (`ma2xml2capture/xmlz`), timecode export, MA2-timecode-to-MA3 scripts |
| [joeyjoestar111/AuraLuxMuse](https://github.com/joeyjoestar111/AuraLuxMuse) | Python reader of sequence exports (`utils/read_sequence_cue.py`) and writers for sequence/timecode XML |
| [chienchuanw/only-cue](https://github.com/chienchuanw/only-cue) | Swift/C# generators for MA2 sequence and timecode XML with golden files |
| [chienchuanw/gma2-plugins](https://github.com/chienchuanw/gma2-plugins) | Layer-export test fixtures |
| [routmoute/ma2-patch-viewer](https://github.com/routmoute/ma2-patch-viewer) | JS parser of layer/patch XML |
| [gelframe/GrandMA2-Patcher](https://github.com/gelframe/GrandMA2-Patcher) | C# element/attribute name constants for layer XML |
| [szymonplotkowski/GrandMA2---Python-lib](https://github.com/szymonplotkowski/GrandMA2---Python-lib) | Python writer for groups etc.; same author has MA2-xml-version-changer and MA2-macros-to-MA3-macros |
| [cbdevnet/xlaser](https://github.com/cbdevnet/xlaser), [qmsk/gma2](https://github.com/qmsk/gma2), [bitfocus/companion](https://github.com/bitfocus/companion) | Complete fixture type XML files |
| [aGuyNamedJonas/grandma2-snippets](https://github.com/aGuyNamedJonas/grandma2-snippets) | Macro exports and Universal timing presets |
| [mittim88/TCHelper](https://github.com/mittim88/TCHelper), [locimation/ma2-tc-import](https://github.com/locimation/ma2-tc-import) | Lua plugins writing sequence/timecode XML for import |
