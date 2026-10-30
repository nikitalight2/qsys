# grandMA3 show file format, XML import/export, and programmatic content creation (for a third-party generator)

Research note on access: the hosts `help.malighting.com`, `help2.malighting.com`, `forum.malighting.com`, `manula.com`, `glama.ai` and `grandma3.bambinito.net` could not be fetched directly. Facts from the official grandMA3 manual below come from search-engine extracts of those pages (URL cited), not from a full page read, so attribute lists on those pages may be incomplete. GitHub (github.com / raw.githubusercontent.com) was fully reachable and the XML samples quoted here were downloaded and read verbatim.

---

## KQ1. The `.show` file: format, folder layout, offline generation

### Takeaway
The grandMA3 `.show` file is a proprietary, undocumented binary (it starts with the ASCII bytes `GMA3`); nobody outside MA has published a parser, and no source describes it as XML, zipped XML, or SQLite. The practical "offline" route is therefore not to write a `.show` but to generate the open XML export files that grandMA3 reads from `gma3_library/...` and import them (command line, Show Creator menu, Lua, or a macro) in the free onPC software.

### Cited Findings
- Show files are proprietary and undocumented; a third-party importer explicitly refuses to open them: "PhotonBoard does not open grandMA `.show` files. The grandMA3 and grandMA2 show files are a proprietary, undocumented format of MA Lighting. PhotonBoard recognises them (a grandMA3 show starts with the bytes `GMA3`) and explains how to export the data instead." — [PhotonBoard docs/format/grandma3-show-file.md](https://github.com/Achorius/PhotonBoard/blob/main/docs/format/grandma3-show-file.md)
- Repeated web searches found no document describing the internal `.show` structure (whether XML, compressed, or SQLite); the only "XML" exports are the library XML files produced by Export — search summary of [MA manual: Load a Show File](https://help.malighting.com/grandMA3/2.4/HTML/sfh_load.html), [Organize Show Files](https://help.malighting.com/grandMA3/2.2/HTML/shf_organize.html)
- Show-file segments: loading a show can pull in patch, pool objects, user and user profiles; "Local settings such as web remote settings and onPC settings are a separate segment"; shows saved with v1.8.8.2 or earlier do not contain Local Settings, Output Configuration and DMX Protocols — [MA manual: Load a Show File (2.4)](https://help.malighting.com/grandMA3/2.4/HTML/sfh_load.html)
- Show-file categories: Shows, Backup Shows, Demo Shows, Template Shows; `LoadShow` keyword loads from the command line; a backup is generated on each save, up to 10 backups per show; Template Shows folder is read-only — [MA manual: Backup and Template Show Files (2.5)](https://help.malighting.com/grandMA3/2.5/HTML/sfh_backup.html), [2.0](https://help.malighting.com/grandMA3/2.0/HTML/sfh_backup.html)
- Forward-compat only: "When loading a show file from a future version (for example, from v2.1), a pop-up informs the user that the show file cannot be loaded as it comes from a future version"; show files from v1.9.7 or earlier are migrated on load into v2.0+ — [MA Release Notes 2.0](https://help.malighting.com/grandMA3/2.0/HTML/key_releasenotes.html)
- Folder structure: versioned folder `gma3_x.y.z` ("installed v1.4.2.1 gives a folder named gma3_1.4.2"); on an onPC computer the tree sits under `MALightingTechnology/gma3_x.y.z/shared/` (2.5 manual); Windows root is `C:\ProgramData\MALightingTechnology`; console internal drive uses `/actual/shared/shows` and `/actual/shared/backups`; on USB: `grandMA3/shared/shows` and `grandMA3/shared/backups` — [MA manual: Folder Structure 2.5](https://help.malighting.com/grandMA3/2.5/HTML/fm_folder_structure.html), [2.0](https://help.malighting.com/grandMA3/2.0/HTML/fm_folder_structure.html)
- `gma3_library` is where exported "smaller portions" of show data go (fixture profiles, user profiles, macros ...), with type-specific subfolders including `datapools`, `fixturetypes`, `inout`, `media`, `mvr`, `patch`, `userprofiles` — [MA manual: Folder Structure 2.0](https://help.malighting.com/grandMA3/2.0/HTML/fm_folder_structure.html)
- The default folder structure changed in v1.5; a USB stick with the old layout is offered a migration — [MA manual: Folder Structure 2.3](https://help.malighting.com/grandMA3/2.3/HTML/fm_folder_structure.html)
- File names must not contain `\ " $ * ? ^ | / : < > \`` — [MA manual: File Management 2.0](https://help.malighting.com/grandMA3/2.0/HTML/file_management.html)
- Concrete datapool paths used by third-party generators: `gma3_library/datapools/sequences/*.xml`, `.../datapools/timecodes/*.xml`, `.../datapools/plugins/<Name>.xml` + `<Name>.lua` (copied to `grandMA3/` at the root of a USB stick) — [reacue lighting.py](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py); macOS: `/Users/USERNAME/MALightingTechnology/gma3_library/datapools/macros/` and `.../datapools/timecodes/` — [Reaper_Markers_GrandMA3 README](https://github.com/edendolev1/Reaper_Markers_GrandMA3); Windows plugins: `C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins` — [MA forum: grandMA3/VSCode Workflow](https://forum.malighting.com/forum/thread/68211-grandma3-vscode-workflow/) (via search extract); USB plugin path `grandMA3/gma3_library/datapools/plugins` — [kevinhayen/grandma3_fixture_to_presets](https://github.com/kevinhayen/grandma3_fixture_to_presets), [leonreucher/grandma3-patch2pdf](https://github.com/leonreucher/grandma3-patch2pdf)
- Presets default export path: `MALightingTechnology/gma3_library/datapools/presets` — [MA forum: EXPORT PRESET PHASER](https://forum.malighting.com/forum/thread/5037-export-preset-phaser/) (via search extract)
- Patch export: grandMA3 format = XML in `/gma3_library/patch`; MVR = `.mvr` in `/gma3_library/mvr` — [MA manual: My Virtual Rig (MVR) 2.4](https://help.malighting.com/grandMA3/2.4/HTML/patch_mvr.html)
- GDTF/fixture type default library path on USB: `/grandMA3/gma3_library/fixturetypes` — [MA manual: Import GDTF 2.0](https://help.malighting.com/grandMA3/2.0/HTML/ft_import_gdtf.html); MA's own bundled plugins/libs live under `grandMA3/shared/resource/lib_plugins/` (LuaSocket and JSON ship there in `lib_plugins/requirements`) — [hossimo/GMA3Plugins](https://github.com/hossimo/GMA3Plugins), [gma3-mcp bridge plugin header](https://github.com/bdstark/gma3-mcp/blob/main/plugin/gma3_mcp_bridge.lua)
- The onPC manual HTML is installed locally at `gma3_<version>/shared/language/HTML` — [gma3-mcp docs/reference.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/reference.md)
- Data-folder naming trap: grandMA2 for Windows is `ProgramData/MA Lighting Technologies`, grandMA3 is `ProgramData/MALightingTechnology` — [MA forum thread 7635](https://forum.malighting.com/forum/thread/7635-where-do-i-find-converted-grandma3-fixture-type-files-when-exporting-show-from-g/) (via search extract)

### Inferences
- A generator should target the XML library files (one per pool type) plus, optionally, a macro or plugin that imports them, and let onPC produce the `.show`. Writing `.show` directly is not feasible with public information.
- Because the folder tree is `MALightingTechnology/gma3_library/...` (shared across installed versions) the generator can drop files there and they appear in the Show Creator import dialogs of any installed 2.x version.

### Gaps
- No public documentation or reverse-engineering of the `.show` binary layout was found.
- Could not fetch the full 2.5 folder-structure page, so the complete list of `gma3_library` sub-folders (beyond those listed) and the `shared/` sub-folders is partial.

---

## KQ2. grandMA3 XML export/import format: root element, per-object structure, DataVersion handling

### Takeaway
All library XML files share `<?xml version="1.0" encoding="UTF-8"?><GMA3 DataVersion="a.b.c.d"> ... </GMA3>`; the child element is the object class (`Sequence`, `Preset`, `Group`, `Macro`, `Timecode`, `Plugin`/`UserPlugin`, `FixtureType`, `Patch`...). The schema is not published by MA; everything known comes from inspecting real exports. DataVersion equals the software build that wrote the file (e.g. `2.3.1.1`, `2.4.2.2`), and import is lenient: files with older DataVersions (2.3.0.0, 1.9.7.0, 1.4.0.2) import into 2.5.x.

### Cited Findings

**Root and version attribute**
- Real plugin export, header: `<?xml version="1.0" encoding="UTF-8"?>` / `<GMA3 DataVersion="1.9.7.0">` / `<UserPlugin Name="fixture_to_presets" Guid="BA AD F0 0D 28 AE D5 66 E5 8C D8 B0 6D 9E 29 63" Version="0.0.0.0" UserRights="Presets">` / `<ComponentLua Guid="...">` / `<FileContent Size="43">` followed by Base64 `<Block>` children (embedded Lua) — [kevinhayen fixture_to_presets.xml](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml)
- GUIDs are written as 16 space-separated hex bytes (`Guid="DE 8A 3A D0 13 3D 56 0A C9 46 4D 1F 52 3F 59 6D"`) — [PhotonBoard sequence.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/sequence.xml), [reacue lighting.py](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py)
- "grandMA3's XML format is not publicly documented"; generator structures are "assumptions confirmed in practice" only for tested versions; recommended practice is to make a reference export from the target onPC version and mirror it — [jorgen-iden/kjoreplan-ma3 README](https://github.com/jorgen-iden/kjoreplan-ma3)
- Validated-on-console generator notes: "DataVersion 2.4.2.2, UTF-8 BOM, OffCue + CueZero, `No` padded to 3 characters, `Target` without quotes, `Object="13.13.0.5.<track>"`, `ValCueDestination="0.5.<track>.<n*1000>"`, `CueDestination` = exact cue name. Do not 'clean' them." — [reacue lighting.py docstring](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py)

**DataVersion ↔ software version and import strictness**
- DataVersion values seen in real/validated files: `1.4.0.2` (macro export), `1.9.7.0` (plugin export), `2.3.1.1`, `2.4.0.2`, `2.4.2.2` — [PhotonBoard test fixtures](https://github.com/Achorius/PhotonBoard/tree/main/test-fixtures/interchange/ma3), [kevinhayen xml](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml), [reacue](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py)
- A macro file with `DataVersion="2.3.0.0"` "imported successfully and ran in grandMA3 onPC 2.5.1.0"; the generator's version table maps 2.5→`2.5.1.0`, 2.3→`2.3.0.0`, 2.2→`2.2.0.0`, 2.1→`2.1.0.0`, 2.0→`2.0.0.0`, 1.9→`1.9.0.0` (import menu "Show Creator" for 2.x, "Import/Export" for 1.9), with only 2.3.0.0 confirmed — [kjoreplan-ma3 ma-versions.json](https://github.com/jorgen-iden/kjoreplan-ma3/blob/main/src/lib/config/ma-versions.json)
- A plugin maintainer declined to bump DataVersion for v2.5 because "the correct value wasn't verified, and the older value still imports" — [Naostage/grandma3-autozoom-plugin PR #2](https://github.com/Naostage/grandma3-autozoom-plugin/pull/2)
- Third-party exporter (Moving Light Assistant) ships separate plugin builds for 1.x, 2.0.x, 2.1.x and 2.2.x lines, i.e. the data model/API differs per minor version — [MLA: Importing grandMA3 Data](https://www.manula.com/manuals/avld/mla/14/en/topic/importing-grandma3-data) (via search extract)
- Lua `Import(handle, ...)` "merges the content of the XML file into the object without any confirmation pop-up"; file must exist — [MA manual: Import(handle, string, string) 2.1](https://help.malighting.com/grandMA3/2.1/HTML/lua_object_import.html)

**Sequence / Cue / Part / values** (hand-crafted sample modelled on real 2.x exports, DataVersion 2.3.1.1 — [PhotonBoard sequence.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/sequence.xml)):
```xml
<GMA3 DataVersion="2.3.1.1">
  <Sequence Name="Act 1" Guid="DE 8A 3A D0 ..." AutoStart="Yes" AutoStop="Yes" Tracking="Yes" WrapAround="No" Priority="High" SequMIB="Enabled">
    <Cue Name="OffCue" Release="Yes" Assert="Assert" AllowDuplicates="" TrigType="">
      <Part Guid="..." Mode="0" Action="Pool Default"/>
    </Cue>
    <Cue Name="CueZero" No="  0">
      <Part Guid="..." Mode="0" Action="Pool Default"/>
    </Cue>
    <Cue Name="Preset" No="  1">
      <Part Name="Preset" Part="0" CueInFade="3.000" CueOutFade="5.000" CueInDelay="0.500" Preset2Fade="6.000" Preset4Fade="1.500">
        <Phaser IDType="0" ID="101" Attribute="Dimmer"><Step Function="Dimmer" Absolute="100" /></Phaser>
        <Phaser IDType="0" ID="101" Attribute="Pan"><Step Function="Pan" AbsolutePhys="-90" /></Phaser>
        <Phaser IDType="0" ID="101" Attribute="Color1" AbsPreset="4.1"><Step Function="Color1" Absolute="20" /></Phaser>
        <Phaser IDType="0" ID="102" Attribute="Dimmer" Fade="8"><Step Function="Dimmer" Absolute="50" /></Phaser>
        <Phaser IDType="1" ID="11" Attribute="Dimmer"><Step Function="Dimmer" Absolute="80" /></Phaser>
      </Part>
      <Part Name="Late part" Part="1" CueInFade="10" CueInDelay="2"> ... </Part>
    </Cue>
    <Cue Name="Wave" No="  2" TrigType="Follow"> <Part Part="0" CueInFade="2"> <Phaser ...><Step .../><Step .../></Phaser> ... </Cue>
    <Cue Name="Timed" No="  2.5" TrigType="Time" TrigTime="4"> ... </Cue>
    <Cue Name="Out" No="  3" TrigType="Timecode"> ... </Cue>
  </Sequence>
</GMA3>
```
- Full Sequence attribute set as written by a 2.4.2.2 console (validated import): `AutoStart="Yes" AutoStop="Yes" AutoFix="No" AutoStomp="No" SoftLTP="Yes" XFadeReload="No" SwapProtect="No" KillProtect="No" UseExecutorTime="Yes" OffwhenOverridden="Yes" SequMIB="Enabled" AutoPrePos="Yes" WrapAround="Yes" MasterGoMode="None" SpeedfromRate="No" Tracking="Yes" IncludeLinkLastGo="Yes" RateScale="One" SpeedScale="One" PreferCueAppearance="No" ExecutorDisplayMode="Data and&#xD;Appearance" Action="Pool Default"`; Part attributes `AlignRangeX="No" AlignRangeY="No" AlignRangeZ="No" PreserveGridPositions="No" MAgic="No" Mode="0" Action="Pool Default"`; cue `No` right-justified to 3 chars (`No="  1"`), file begins with a UTF-8 BOM — [reacue lighting.py build_sequence_xml](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py)
- Parser attribute names (what a reader must accept): Cue `No`, `Name`, `TrigType` (Follow/Time/Timecode...), `TrigTime`; Part `CueInFade`, `CueOutFade`, `CueInDelay`, `Preset1Fade..Preset7Fade`, `Preset1Delay..`; value rows `<Phaser IDType ID Attribute [AbsPreset] [Fade]><Step Function Absolute|AbsolutePhys|Relative/>` — [PhotonBoard ma3.ts](https://github.com/Achorius/PhotonBoard/blob/main/src/main/interchange/ma/ma3.ts)
- Cue properties exist by the same names on the command line: `Set Cue Property "TrigType" "Follow"`, `Set Cue Property "TrigTime" 2` — [MA forum: Syntax For Cue Settings](https://forum.malighting.com/forum/thread/8781-syntax-for-cue-settings/) (via search extract)
- IDType convention in exports: `0` = Fixture (FID), `1` = Channel (CID), `2` = universal fixture (ID 1) — [PhotonBoard presets-group.xml comment](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/presets-group.xml)

**Preset and Group** (sample modelled on real `lib_presets` XML and a real 2.0 group export — [PhotonBoard presets-group.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/presets-group.xml)):
```xml
<Preset Name="Red" No="4.1" PresetModeInternal="Selective">
  <PresetData Size="2">
    <Phaser IDType="0" ID="101" Attribute="Color1"><Step Function="Color1" Absolute="20" /></Phaser>
    <Phaser IDType="0" ID="102" Attribute="Color1"><Step Function="Color1" Absolute="20" /></Phaser>
  </PresetData>
</Preset>
<Preset Name="Full" No="1.1" PresetModeInternal="Universal">
  <PresetData Size="1"><Phaser IDType="2" ID="1" Attribute="Dimmer"><Step Function="Dimmer" Absolute="100" /></Phaser></PresetData>
</Preset>
<Group Name="Spots R-L" Guid="0D 49 20 01 ..." AlignRangeX="No" PreserveGridPositions="No">
  <SelectionData Size="3">
    <Item IDType="0" ID="102" X="0" Y="0" Z="0" />
    <Item IDType="0" ID="101" X="1" Y="0" Z="0" />
    <Item IDType="1" ID="11" X="2" Y="0" Z="0" />
  </SelectionData>
</Group>
```
- Preset modes Selective / Global / Universal (and Force Global) — [MA manual: Presets 2.2](https://help.malighting.com/grandMA3/2.2/HTML/presets.html)

**Macro** (real export, DataVersion 1.4.0.2 — [PhotonBoard macro-vivaldi.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/macro-vivaldi.xml)):
```xml
<GMA3 DataVersion="1.4.0.2">
  <Macro Name="Macro vivaldi" Guid="00 00 00 00 A8 F8 B9 20 78 06 00 00 A5 46 09 AA">
    <MacroLine Command="Store Sequence 100 Cue 1 thru 21" Wait="0.10" />
    <MacroLine Command="Label Sequence 100 Cue 1 &quot;elsobumm&quot;" Wait="0.10" />
    <MacroLine Command="Drive 2" />
    <MacroLine Command="import Timecode &quot;vivaldi_timecode&quot;" Wait="0.10" />
  </Macro>
</GMA3>
```
- Macro line properties as exposed to `Set`: Command, Wait, Enabled, AddToCmdline, Execute, Name, Note; waits may be seconds, Follow or Go; "The console rewrites command text outside quotes" (trims, collapses spaces, expands abbreviations) — [gma3-mcp docs/tools/macros.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/macros.md)

**Timecode** (validated import on 2.4.2.2 — [reacue lighting.py build_timecode_xml](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py)):
```xml
<GMA3 DataVersion="2.4.2.2">
  <Timecode Name="" Guid="..." Cursor="123.45" Duration="123.45" LoopCount="0" TCSlot="-1" AutoStop="No" SwitchOff="Keep Playbacks" TimeDisplayFormat="Default" FrameReadout="Seconds">
    <TrackGroup Play="" Rec="">
      <MarkerTrack Name="Marker" Guid="..."/>
      <Track Name="Song" Guid="..." Play="" Rec="" Target="ShowData.DataPools.Default.Sequences.Song">
        <TimeRange Guid="..." Duration="To End" Play="" Rec="" Start="0.000">
          <CmdSubTrack>
            <CmdEvent Name="Goto" Time="12.345" CueDestination="Verse 1">
              <RealtimeCmd Type="Key" Source="Original" UserProfile="0" Environment="0" User="1" Status="On" IsRealtime="1" IsXFade="0" IgnoreFollow="0" IgnoreCommand="0" Assert="0" IgnoreNetwork="0" FromTriggerNode="0" IgnoreExecTime="0" IssuedByTimecode="0" FromLocalHardwareFader="1" IgnoreExecXFade="0" IsExecXFade="0" Object="13.13.0.5.0" ExecToken="Goto" ValCueDestination="0.5.0.1000"/>
            </CmdEvent>
          </CmdSubTrack>
        </TimeRange>
      </Track>
    </TrackGroup>
  </Timecode>
</GMA3>
```
- Timecode object model: show → track group → track (target = a sequence) → time range → command subtrack → events (time, token such as Go/Goto/Off/Flash/Temp, cue for Goto, On/Off status) — [gma3-mcp docs/tools/timecode.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/timecode.md)

**Plugin** (minimal, validated 2.4.2.2, external Lua file): `<Plugin Name="ReaCue" Author="ReaCue" Version="1.0.0.0"><ComponentLua Name="ReaCue" FileName="ReaCue.lua" Installed="No"/></Plugin>` — [reacue lighting.py plugin_files](https://github.com/herve8940/reacue/blob/main/reacue_mcp/lighting.py). The manual: each Lua file is one `ComponentLua`; `FileName` is required to export; components without a valid file name are stored inside the XML as base64; on import the XML is always required and separate `.lua` files must sit in the plugins folder on the target drive; `FilePath` holds an optional sub-folder — [MA manual: Plugins 2.1](https://help.malighting.com/grandMA3/2.1/HTML/plugins.html), [2.0](https://help.malighting.com/grandMA3/2.0/HTML/plugins.html) (via search extract). Older exports use `<UserPlugin ... UserRights="Presets">` with `<FileContent Size><Block>…` base64 — [kevinhayen xml](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml)

**Patch / FixtureType** (hand-crafted 2.4 patch export modelled on real fixture-type XML — [PhotonBoard patch.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/patch.xml)):
```xml
<GMA3 DataVersion="2.4.0.2">
  <Patch>
    <FixtureTypes>
      <FixtureType Name="Spot 18" ShortName="Spot18" Manufacturer="Demo">
        <DMXModes><DMXMode Name="Standard" Geometry="Body"><DMXChannels>
          <DMXChannel Coarse="1" Fine="2" Default="800000"><LogicalChannel Attribute="Pan"><ChannelFunction Attribute="Pan" /></LogicalChannel></DMXChannel>
          <DMXChannel Coarse="8" Default="000000"><LogicalChannel Attribute="Dimmer" Master="Grand"><ChannelFunction Attribute="Dimmer" /></LogicalChannel></DMXChannel>
        </DMXChannels></DMXMode></DMXModes>
      </FixtureType>
    </FixtureTypes>
    <Stages><Stage Name="Stage 1"><Fixtures>
      <Fixture Name="Spot 1" FID="101" IDType="Fixture" FixtureType="1 Spot 18" Mode="Standard" Patch="1.001" PosX="-2" PosY="1.5" PosZ="6" RotX="0" RotY="0" RotZ="90" />
      <Fixture Name="Front 1" CID="11" IDType="Channel" FixtureType="Generic@Dimmer" Mode="Mode 0" Patch="2.001" />
    </Fixtures></Stage></Stages>
  </Patch>
</GMA3>
```
- A user fixture-type `.xml` for the library "must be well-formed XML with a `GMA3` root and a `FixtureType` child with a `Name`"; a `.gdtf` is a zip whose `description.xml` has a `GDTF` root with a `FixtureType` child; header fields read from the XML: name, manufacturer, short name, DMX mode names — [gma3-mcp docs/tools/patch.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/patch.md)
- Exported fixture types are named `manufacturer@name.xml` or `manufacturer@name.gdtf` — [MA manual: Export Fixture Types 2.0](https://help.malighting.com/grandMA3/2.0/HTML/ft_export.html)
- Patch export from the Patch window writes XML to a `grandMA3/export/` folder on USB (older forum report) and grouped fixtures become one file with each fixture as a child node — [MA forum: EXPORT PATCH LIST PDF](https://forum.malighting.com/forum/thread/4440-export-pacth-list-pdf/) (via search extract)

**Export behaviour**
- `Export` saves objects from the current show as a smaller file; exporting several objects without a file name writes one XML per object; with a shared file name they are combined into one file; e.g. `Export Macro 1 thru 10 "my_macro_lib.xml"` — [MA manual: Export keyword 2.1](https://help.malighting.com/grandMA3/2.1/HTML/keyword_export.html), [2.0](https://help.malighting.com/grandMA3/2.0/HTML/keyword_export.html)
- Import/Export menus automatically include referenced objects (e.g. an appearance referenced by a macro); options "Include Dependencies" and "Gaps" exist in the Show Creator import/export — [MA manual: Import / Export 2.5](https://help.malighting.com/grandMA3/2.5/HTML/import-export.html)
- `/Path "folder"` option sets the folder for import/export; a path starting with a letter/number is relative to the default folder structure, one starting with `/` is from the device root; missing folders are created — [MA manual: /Path option (1.9)](https://help2.malighting.com/Media/TopicPdf/81596/43) (via search extract)
- Command-line export examples used by third parties: `Export Sequence 1 "Act1"`, `Export Preset 4.1 Thru 4.50 "Colors"`, `Export Group 1 Thru 100 "Groups"`, `Export Macro 1 Thru 100 "Macros"`, `Export Fixture Thru /File "rig" /MVR` — [PhotonBoard grandma3-show-file.md](https://github.com/Achorius/PhotonBoard/blob/main/docs/format/grandma3-show-file.md)

**Layouts / Appearances / Pages**
- Layout import/export is reported to leave objects empty in one forum thread title — [MA forum 68044: Import-Export of Layouts leaves Objects empty](https://forum.malighting.com/forum/thread/68044-import-export-of-layouts-leaves-objects-empty/) (title only; body not fetchable)
- Appearances exist as a pool ("Appearance Builder" plugins exist) and the MA2 converter maps MA2 object appearances into "the grandMA3 appearance pool" — [hossimo/GMA3Plugins](https://github.com/hossimo/GMA3Plugins), [MA2 manual: Save as grandMA3](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)

### Inferences
- A safe generator strategy: emit DataVersion equal to the oldest 2.x build you have validated against (e.g. `2.3.0.0`) since newer onPC imports older DataVersions; never emit a DataVersion newer than the target console (show-file loading refuses "future" versions and import may behave the same — unverified for XML).
- Attributes with defaults may be omitted (the hand-crafted PhotonBoard samples omit most Sequence attributes), but the validated reacue sample suggests mirroring a real export in full is the lowest-risk approach.
- Cue values referencing fixtures by `IDType`/`ID` (FID/CID) means the patch must exist (same FIDs) before importing sequences/presets; MLA states patch + fixture type XML "must be included when importing preset data."
- Layout, Appearance, Page/Executor XML structure was not found in any public sample; treat as unknown.

### Gaps
- No real console export of `Layout`, `Appearance`, `Page`/executor assignment, `World`, `Filter`, or `MAtricks` XML was found; element names unknown.
- No real export of a `Recipe` node (preset/cue-part recipes with Group/Preset/MAtricks references) was found; gma3-mcp confirms recipe lines exist on presets and cue parts and are edited via `Assign`/`Move`/`Delete`/`Cook`, but not their XML.
- The exact import-time behaviour for a DataVersion newer than the running software was not confirmed.
- The Import keyword's full `/Option` list could not be read (only `/Type "User"|"System"` and `/Path` are confirmed).

---

## KQ3. Lua plugin API: Cmd(), Patch(), ObjectList, handles, properties, creating fixtures

### Takeaway
Lua (5.4 in 1.9–2.4, 5.5.0 in 2.5) runs inside the console; the Object-Free API provides `Cmd()`, `CmdIndirect()`, `Patch()`, `ObjectList()`, `Root()`, `DataPool()`, `Import()`, `Export()`, `AddFixtures()`, `CreateMultiPatch()`, `FindBestDMXPatchAddr()`, `CheckFIDCollision()`, `CheckDMXCollision()`; the Object API gives handles `:Children()`, `:Get()`, `:Set()`, `:Create()`, `:Append()`, `:Insert()`, `:Import()`, `:Export()`, `:Dump()`. Patch creation via Lua is possible (`AddFixtures` with a dmx_mode handle, FID and `"U.AAA"` address, after moving the command-line destination into the patch), and everything else can be done by issuing command-line strings through `Cmd()`.

### Cited Findings
- Official reference locations: Object-Free API index — [MA manual: Lua Functions – Object-Free API 2.3](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree.html); Object API — [MA manual: Lua Functions – Object API 2.0](https://help.malighting.com/grandMA3/2.0/HTML/lua_object.html); Plugins chapter — [MA manual: Plugins 2.1](https://help.malighting.com/grandMA3/2.1/HTML/plugins.html)
- `Cmd(string[, handle])` executes a command in the command line, runs in a Lua task, is synchronous and "a bad command has the potential to block the system"; alternatives `CmdIndirect(string[, handle[, handle]])` and `CmdIndirectWait` — [MA manual: Cmd 2.1](https://help.malighting.com/grandMA3/2.1/HTML/lua_objectfree_cmd.html)
- `ObjectList(string[, table])` returns a table of handles for a command-line-style selection string (e.g. "Fixture 1 Thru 10"); optional flags reverse order / restrict to selected pool item — [MA manual: ObjectList 2.5](https://help.malighting.com/grandMA3/2.5/HTML/lua_objectfree_objectlist.html)
- `AddFixtures(table)`: table with `mode` = handle to a valid `dmx_mode` (e.g. `Patch().FixtureTypes[...].DMXModes["Mode 0"]`), `amount`, optional `fid` and `patch` (e.g. `"10.001"`); "must be run with the command line in the correct patch destination"; returns true on success — [MA manual: AddFixtures 2.1](https://help.malighting.com/grandMA3/2.1/HTML/lua_objectfree_addfixtures.html)
- `CreateMultiPatch({handles}, integer[, string])` creates multipatch fixtures; `Patch()` is the entry point (`Patch().Stages[1].Fixtures[2]`); example uses `Cmd("ChangeDestination ...")` — [MA manual: CreateMultiPatch 2.0/2.5](https://help.malighting.com/grandMA3/2.5/HTML/lua_objectfree_createmultipatch.html)
- Forum: `AddFixtures()` crashed for a user until the destination was moved into the patch first ("you have to move into the patch path"); `Acquire` (not `Aquire`) is the current name (v2.3.2) — [MA forum: Patch with LUA](https://forum.malighting.com/forum/thread/68001-patch-with-lua/) (via search extract)
- Working production pattern (gma3-mcp on onPC 2.5.1): open a patch copy, check `CheckFIDCollision`, find free DMX with `FindBestDMXPatchAddr`, call `AddFixtures` once per fixture (amount 1, own FID and address), set addresses as `"U.AAA"`, unpatch with empty string `""`; fixtures are added at a stage's top level; fixture rows expose `fid, cid, idType, name, type, mode, patch, breaks[{break,address}], stage, parentFid, subfixtures, cells` — [gma3-mcp docs/tools/patch.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/patch.md)
- Importing a fixture type by command: `Import Library` "names the file only" (so the same file name in two libraries is ambiguous); the console "would silently add a second type with the same name" on re-import — [gma3-mcp docs/tools/patch.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/patch.md)
- Object-Free API function index (v2.0.0.4, unofficial): AddFixtures, CheckDMXCollision, CheckFIDCollision, Cmd, CmdIndirect, CmdIndirectWait, CmdObj, CreateMultiPatch, CreateUndo/CloseUndo, DataPool, Export, ExportCSV, ExportJson, FindBestDMXPatchAddr, FixtureType, FromAddr/ToAddr, GetApiDescriptor, GetObjApiDescriptor, GetPresetData, GetShowFileStatus, Import, MasterPool, ObjectList, Patch, Programmer, Root, ShowData, ShowSettings, StrToHandle/HandleToStr, Version, etc.; Object API: Children, Get, Set, Dump, Import, Export, AddListChildren, Copy, Find, Remove, Save; `HelpLua` exports the full list for the installed version — [hossimo GMA3Plugins wiki](https://github.com/hossimo/GMA3Plugins/wiki)
- `HelpLua` writes `grandMA3_lua_functions.txt`; `Lua "Printf('Hello')"` runs inline; `LuaFile "hello"` runs `hello.lua` from the plugins directory; output in System Monitor — [enlore/grandma3-stuff](https://github.com/enlore/grandma3-stuff)
- Object creation: `Create(handle, child_index[, class[, undo]])`, `Append(handle[, class[, undo[, count]]])`, `Insert(...)`; use `parent:Create(slot)` for pool slots (macros in a pool), `parent:Append()`/`:Insert(index)` for children like macro lines; example `Root().ShowData.DataPools.Default.Macros:Create(N)` then `Macros[N]:Set("Name","Hello")` — [MA forum: Lua group macro](https://forum.malighting.com/forum/thread/9185-lua-group-macro/), [MA forum: Object API Documentation](https://forum.malighting.com/forum/thread/8220-object-api-documentation/) (via search extract)
- `Dump(handle)` returns name, class, path, properties and children; `Children(handle)` returns table of child handles — [MA manual: Dump 2.0](https://help.malighting.com/grandMA3/2.0/HTML/lua_object_dump.html), [Children 2.0](https://help.malighting.com/grandMA3/2.0/HTML/lua_object_children.html)
- Lua handle: "light_userdata ... a unique identifier that refers to a grandMA3 object" — [MA forum: Set Value in Object directly from lua](https://forum.malighting.com/forum/thread/8237-set-value-in-object-direcly-from-lua-without-the-cmd/) (via search extract)
- Lua version: grandMA3 1.9 supports Lua 5.4.4 — [MacTirney/GrandMA3-API-Documentation](https://github.com/MacTirney/GrandMA3-API-Documentation); v2.5 updates the Lua core to 5.5.0 and deprecates `HasActivePlayback`; hard-coded datapool child indices (e.g. `datapool[6]` for Sequences) broke in 2.5 — walk `Children()` and match by class instead — [Naostage autozoom PR #2](https://github.com/Naostage/grandma3-autozoom-plugin/pull/2)
- Real plugin that builds presets by issuing commands from Lua: `Cmd("Fixture <ftIndex>.<no>")`, `Cmd('Attribute "ColorRGB_R" At Absolute Decimal8 255')`, `Cmd('Store Preset "<type>".<n> /m')`, `Cmd('Label Preset "<type>".<n> "<name>"')`, `Cmd("ClearAll")` — [kevinhayen fixture_to_presets.xml (decoded)](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml)
- Lua `Import(handle, string, string)` merges XML into an object without a confirmation pop-up — [MA manual 2.1](https://help.malighting.com/grandMA3/2.1/HTML/lua_object_import.html)
- LuaSocket and a JSON library ship with grandMA3 (`shared/resource/lib_plugins/requirements`), enabling TCP bridges from Lua — [gma3-mcp bridge plugin](https://github.com/bdstark/gma3-mcp/blob/main/plugin/gma3_mcp_bridge.lua)
- Tooling: VS Code extension "grandma-devkit" (API completion, scaffolding, deploy) — [badasslighting/grandma-devkit](https://github.com/badasslighting/grandma-devkit); `GetApiDescriptor` exposes the live API description — [hossimo wiki](https://github.com/hossimo/GMA3Plugins/wiki), [gma3-mcp reference](https://github.com/bdstark/gma3-mcp/blob/main/docs/reference.md)

### Inferences
- For a generator, the most robust Lua strategy is "command-driven": generate a plugin (XML + .lua) that calls `Cmd()` for Store/Label/Assign/Patch and, where a bulk structure is needed, `Import()` of generated XML — exactly what reacue's plugin does (it imports Sequence and Timecode XML and sets the TC slot).
- Direct object-tree writes via `Create()/Set()` are possible but version-sensitive (pool indices changed in 2.5); prefer property names over indices.

### Gaps
- Official signatures for `Import(handle, string, string)` argument meaning (file name, path?) could not be read in full.
- Whether `AddFixtures` accepts a stage/layer target other than the current destination was not confirmed.

---

## KQ4. Command-line syntax for creating content (Store/Label/Assign/Patch/Import)

### Takeaway
Everything in a grandMA3 show can be built from command strings (in a macro, via OSC `/cmd`, via Lua `Cmd()`, or via a telnet/OSC remote): `Store Group N`, `Store Preset T.N /Selective|/Global|/Universal /Merge|/Overwrite`, `Store Cue N "Name" CueFade x CueDelay y`, `Set Cue N Property "TrigType" "Follow"`, `Assign Sequence N At Page P.E`, `Patch Fixture N U.AAA`, `Set Fixture N Property "Patch" "U.AAA"`, `Import <Object> Library "file.xml" [At <Object> N]`, `Store Macro N /NoConfirmation` + `Set Macro N.L Property "Command" "..."`.

### Cited Findings
- `Import [Object] Library "File Name.xml"` with optional `If Drive`, `At`, `/Option`; shortcut `Im` (was `I` before 2.3); default reads from the library folder structure on console/PC/USB; loads into "the first free pool object when no certain pool object is given"; examples `Import Library "color.xml"` (after `ChangeDestination`), `Import Macro Library "color.xml" At Macro 42`, `Import Library "*.xml"`; `/Type "User"|"System"` chooses library — [MA manual: Import keyword 2.5](https://help.malighting.com/grandMA3/2.5/HTML/keyword_import.html), [2.3](https://help.malighting.com/grandMA3/2.3/HTML/keyword_import.html)
- Community forms: `Import Sequence Y "NAME_OF_FILE.xml"`; `ChangeDestination Preset 3 ; Import Library "preset.xml" ; ChangeDestination Root`; `Import Preset 3.1 "preset.xml"`; set the drive first (`Drive 2`) — [MA forum: Import Presets](https://forum.malighting.com/forum/thread/3766-import-presets/) (via search extract); `Import Library "my_macro_lib.xml" At Macro 4` — [MA forum 7816](https://forum.malighting.com/forum/thread/7816-export-import-ranges-w-gaps-macro-share/) (via search extract); macro using `Drive 2` then `import Timecode "vivaldi_timecode"` — [macro-vivaldi.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/macro-vivaldi.xml)
- Patch: `Patch Fixture ["Name"|Number] [Universe.Address]`, example `Patch Fixture 2 3.123`; `Patch Fixture 1 Thru 10` with no address opens the Edit Patch window — [MA manual: Patch keyword 2.2](https://help.malighting.com/grandMA3/2.2/HTML/keyword_patch.html); quoted address works (`Patch Fixture 1 "1.1"`), empty string unpatches; alternative `Set Fixture 1 Thru 3 Property "Patch" "1.1"` — [MA forum 5777](https://forum.malighting.com/forum/thread/5777-patch-non-congruent-fixtures-on-command-line/), [MA forum 7780](https://forum.malighting.com/forum/thread/7780-macro-for-unpatching-fixtures/) (via search extracts); via OSC `SendOSC 1 "/cmd,s,Patch Fixture 1 3.42"` — [ACT Entertainment: OSC with grandMA3](https://support.actentertainment.com/knowledgeBase/26283481)
- Adding fixtures (type + FID) is documented as a GUI/Patch-menu operation ("Add Fixtures to the Show") — [MA manual 2.5](https://help.malighting.com/grandMA3/2.5/HTML/patch_add_fixtures.html); programmatic add = Lua `AddFixtures` (see KQ3). No `Store Fixture`-style command-line keyword was found in any source.
- Cues: `Store Cue [No]`, `Store Cue [No] Sequence [Name|No]`, `Store Cue [No] Executor [No]`, `Store Cue [No] "My Cue Name"`, `Store Cue 4 CueFade "6" CueDelay "1"`, `CueFade [In]/[Out]`, `Store Cue "BO*" /Merge`; Assign to cue: `Assign [Object] At (Sequence [..]) Cue [..]` — [MA manual: Store Cues 2.2](https://help.malighting.com/grandMA3/2.2/HTML/cue_store.html), [Cue keyword 2.2](https://help.malighting.com/grandMA3/2.2/HTML/keyword_cue.html), [CueFade 2.3](https://help.malighting.com/grandMA3/2.3/HTML/keyword_cuefade.html), [Cue Timing 2.3](https://help.malighting.com/grandMA3/2.3/HTML/cue_timing.html)
- Cue parts: `Part` keyword segments cues; store a second part from the command line — [MA manual: Part keyword 2.2](https://help.malighting.com/grandMA3/2.2/HTML/keyword_part.html)
- Cue trigger: `Set Cue Property "TrigType" "Follow"`, `Set Cue Property "TrigTime" 2` — [MA forum 8781](https://forum.malighting.com/forum/thread/8781-syntax-for-cue-settings/) (via search extract)
- Presets: option keywords `/Global`, `/Overwrite`, `/Selective`, `/Universal` — [MA manual: Preset keyword 2.0](https://help.malighting.com/grandMA3/2.0/HTML/keyword_preset.html); validated full form on onPC 2.5.1: `Store Preset P.N /Programmer /Active /<Selective|Global|Universal> [/Merge|/Overwrite] /Embed "Yes|No" /MAtricks "Yes|No" /KeepActivation`, plus `/ForceGlobal`, `/ForceUniversal` with `/Merge` — [gma3-mcp docs/tools/presets.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/presets.md); `/m` short form for Merge — [kevinhayen plugin](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml)
- Executors: `Assign Sequence 4 At Page 2.301`; general `Assign [Function] At Page [page].[executor]`; ranges `Assign Sequence 1 Thru 5 At Page 1.201 Thru 205` — [MA manual: Assign Object to an Executor 2.3](https://help.malighting.com/grandMA3/2.3/HTML/executor_assign.html), [Assign keyword 2.1](https://help.malighting.com/grandMA3/2.1/HTML/keyword_assign.html), [MA forum 68254](https://forum.malighting.com/forum/thread/68254-store-executors-in-cues/) (via search extract); 2.3 redesigned the Assign menu "Handle" tab — [MA Release Notes 2.3](https://help.malighting.com/grandMA3/2.3/HTML/key_releasenotes.html)
- Macros by command: `Store Macro N /NoConfirmation`, `Store Macro N.L /NoConfirmation` (append a line), `Insert Macro N.L`, then `Set Macro N.L Property "Command" "..."` / `"Wait"` / `"Enabled"` / `"AddToCmdline"` / `"Execute"` / `"Name"` / `"Note"`; `Go+ Macro N`, `Off Macro N` — [gma3-mcp docs/tools/macros.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/macros.md)
- Timecode by command: `Store Timecode N /NoConfirmation`, then track group / tracks (target = sequence) / events; the console creates a group's first track and a track's time range one frame later, so building must be stepwise — [gma3-mcp docs/tools/timecode.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/timecode.md)
- Attribute values from the command line: `Attribute "Dimmer" At Absolute Decimal8 255`, `Fixture 1.3` (sub-fixture), `Label Preset ...`, `ClearAll` — [kevinhayen plugin](https://raw.githubusercontent.com/kevinhayen/grandma3_fixture_to_presets/main/fixture_to_presets.xml)
- Generated macro content used by a show-generator: `ClearAll`; `Store Sequence 101 Cue 1`; `Label Sequence 101 Cue 1 "<name>"`; `Set ... Property "Note" "..."`; `Label Sequence 101 "<seq name>"` — [kjoreplan-ma3 README](https://github.com/jorgen-iden/kjoreplan-ma3)
- Cloning between shows: `Clone fixture 101 thru 110 at fixture 1001 thru 1010 if preset 4.*` (works for groups and sequences) — [MA forum 8431: Partial show read](https://forum.malighting.com/forum/thread/8431-partial-show-read-in-grandma-3/) (via search extract)
- Recook after import/upgrade: `Cook DataPool Thru /MergeLowPriority` — [MA Release Notes 2.0](https://help.malighting.com/grandMA3/2.0/HTML/key_releasenotes.html)
- Remote command entry: OSC `/cmd` string messages (onPC: Menu > In & Out > OSC) — [ACT: OSC with grandMA3](https://support.actentertainment.com/knowledgeBase/26283481), [gma3-mcp reference](https://github.com/bdstark/gma3-mcp/blob/main/docs/reference.md)

### Inferences
- A generator can emit a single macro XML (`<Macro><MacroLine Command=... Wait=.../>`) that performs `Drive`, `Import ... Library`, `Patch Fixture`, `Store`, `Label`, `Assign ... At Page` in order — this is exactly the pattern of the real `macro-vivaldi.xml`.
- `Store Group N` with a selection active is standard MA syntax; it appears in the Show Creator ("Create Groups") but the explicit keyword page could not be read, so it is inferred from the general `Store [Object]` pattern.

### Gaps
- Could not read the `Store` keyword page itself; `Store Group`'s option list and any `/Fade`/`/Delay` options on Store Cue were not confirmed (timing is set via `CueFade`/`CueDelay` keywords).
- Full `Import` `/Option` list unknown.

---

## KQ5. GDTF, MA3 fixture types, GDTF Share, MA2 fixture XML ↔ GDTF

### Takeaway
grandMA3 imports GDTF (`.gdtf` zip with `description.xml`) from GDTF Share (via MA World Server) or from `gma3_library/fixturetypes`, and exports its own types either as grandMA3 "User" XML (`manufacturer@name.xml`, root `<GMA3><FixtureType>`) or as GDTF — except types whose source is "grandMA2", which cannot be exported as GDTF. grandMA2 fixture XML/.pxml cannot be imported directly; the only MA-supported path is MA2 onPC "Save as grandMA3" conversion, then export of the converted types.

### Cited Findings
- "a GDTF file is a zip archive that holds the fixture description, geometry data, and gobo images"; import from GDTF Share when connected to a World Server, or from USB; Patch > Fixture Types > Import; default USB path `/grandMA3/gma3_library/fixturetypes`; a running GDTF import can be cancelled with MA+ESC / Shift+ESC held 5 s (2.5) — [MA manual: Import GDTF 2.0](https://help.malighting.com/grandMA3/2.0/HTML/ft_import_gdtf.html), [2.5](https://help.malighting.com/grandMA3/2.5/HTML/ft_import_gdtf.html)
- Export types "in either grandMA3 'User' format or GDTF"; default file name `manufacturer@name.xml` or `.gdtf`; "fixture profiles whose 'source' column says 'grandMA2' cannot be exported as GDTF files" — [MA manual: Export Fixture Types 2.0](https://help.malighting.com/grandMA3/2.0/HTML/ft_export.html)
- grandMA3 includes a Fixture Type Editor (Wheels, Physical Descriptions, Models, Geometries, DMX Modes); fixtures can also be built in the GDTF Builder (https://fixturebuilder.gdtf-share.com/) and imported — [MA manual: Build Fixture Types 2.3](https://help.malighting.com/grandMA3/2.3/HTML/ft_build.html), [2.0](https://help.malighting.com/grandMA3/2.0/HTML/fixture_types.html)
- "you cannot import grandMA2 fixture types directly into grandMA3"; workaround: import the MA2 type into a grandMA2 show, Save as grandMA3, export the converted type; MA2 export is `.xml` (open) while `.pxml` is "a packed/encrypted fileformat" — [MA forum 4039](https://forum.malighting.com/forum/thread/4039-grandma2-fixture-type-import/), [MA forum 7629](https://forum.malighting.com/forum/thread/7629-convert-pxml-fixture-type-files-to-xml/) (via search extracts); manual: "it is possible to import fixture types from converted grandMA2 fixtures" — [MA manual: Import Fixture Types 2.0](https://help.malighting.com/grandMA3/2.0/HTML/ft_import.html)
- A grandMA2 `.pxml` "is encrypted: its modes are known only after the import"; a user `.xml` fixture type must have `GMA3` root + `FixtureType` child with `Name`; GDTF description.xml has its own `DataVersion` attribute — [gma3-mcp docs/tools/patch.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/tools/patch.md)
- MA3 fixture-type XML mirrors GDTF structure: `FixtureType > DMXModes > DMXMode > DMXChannels > DMXChannel(Coarse, Fine, Default) > LogicalChannel(Attribute, Master) > ChannelFunction(Attribute)` — [PhotonBoard patch.xml](https://github.com/Achorius/PhotonBoard/blob/main/test-fixtures/interchange/ma3/patch.xml) (hand-crafted, modelled on real `gma3_library/fixturetypes` files); GDTF hierarchy `FixtureType > AttributeDefinitions, Wheels, Geometries, DMXModes > DMXChannel > LogicalChannel > ChannelFunction > ChannelSet` — [enlore/grandma3-stuff](https://github.com/enlore/grandma3-stuff)
- MVR export/import: Patch > Export pop-up offers grandMA3 XML (`/gma3_library/patch`) or MVR (`/gma3_library/mvr`), whole patch or selection; MVR import goes through Partial Show Read (2.4) — [MA manual: MVR 2.4](https://help.malighting.com/grandMA3/2.4/HTML/patch_mvr.html); MVR import matches fixtures by the UUID generated by the creating application (so re-importing adds/matches unexpectedly); "MVR doesn't include FixtureTypes that were converted from grandMA2" — [MA forum 68957](https://forum.malighting.com/forum/thread/68957-mvr-import-adding-fixtures-instead-of-matching/), [ACT: grandMA3 v2.1 FAQ](https://support.actentertainment.com/knowledgeBase/36053570) (via search extracts)
- Older onPC 1.8.8.2 only listed `.gdtf` (not `.xml`/`.xmlp`) in `gma3_library/fixturetypes` on USB — [MA forum 8142](https://forum.malighting.com/forum/thread/8142-on-pc-1-8-8-2-does-not-find-xml-and-xmlp-but-gdtf-files-in-f-grandma3-gma3-libra/) (title; via search extract)
- GDTF spec and tools: official spec repo [mvrdevelopment/spec](https://github.com/mvrdevelopment/spec) (not fetched); community GDTF builders exist (gdtf-build.com, GoGobo, FixtureForge) — [search results](https://gdtf-build.com/), [FixtureForge](https://freeman-shop.com/FixtureForge/index.html)

### Inferences
- For a MA2→MA3 tool, the cleanest fixture-type route is GDTF: translate the MA2 fixture XML into a GDTF `description.xml` (DMXModes/LogicalChannel/ChannelFunction/ChannelSet) and drop the `.gdtf` into `gma3_library/fixturetypes`, then `Import Library "manufacturer@name.gdtf"`; alternatively emit MA3 User XML (`<GMA3><FixtureType>`) — but no official schema for the User XML format was found, so a reference export is required.
- MVR is attractive for patch + positions but references fixture types by GDTF, so MA2-converted types cannot ride along.

### Gaps
- No published schema/documentation of the grandMA3 "User" fixture-type XML; the PhotonBoard sample is modelled, not a console file.
- Could not fetch the GDTF spec repo to confirm the current GDTF version supported by 2.5.

---

## KQ6. Built-in import of grandMA2 shows/XML into grandMA3

### Takeaway
grandMA3 itself cannot read MA2 show files or MA2 XML; the official converter lives in grandMA2 (v3.9, onPC or Mode2 on an MA3 console): Backup menu > "Save as grandMA3", which writes an MA3 show with patch, fixture types, groups, presets (values + timings), sequences/cues, executors/pages, appearances, worlds-era "infos" as notes, and simple effects converted to acceleration/deceleration values in preset pool 22 — but not macro semantics, embedded/timing-only presets, complex effects, remotes, or some Xkeys.

### Cited Findings
- "The option 'Save as grandMA3' works only on a grandMA2 onPC or in Mode2 on a grandMA3 console" (not under Parallels) — [grandMA2 manual: grandMA2 to grandMA3 Show File Converter](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- Converted: Patch (Setup) incl. fixture types, attributes, fixtures, DMX profiles, universes, multipatch; object appearances → appearance pool; executors and pages; infos → notes; "Only executors that have sequences or selective effects assigned are converted" — same page
- Effects: "Effect pool objects are converted into preset pool 22 (All 2). This pool will be renamed to Effects"; effects become acceleration/deceleration values; Stomp → hard 0 on relative layer; "Only the simple predefined forms of effects in grandMA2 are convertible, yet"; selective effects → preset pool 22 — same page; 3.9 release notes: converted effects keep their links to cues/steps — [grandMA2 Release Notes 3.9](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)
- Presets: "The values and timings of presets will now be converted. Effect data in presets and presets that contain only timings without values are excluded"; embedded presets "not convertible, yet"; conversion previously failed with selective embedded presets — [grandMA2 Release Notes 3.9](https://help.malighting.com/grandMA2/en/help/release_notes/key_releasenotes.html)
- Macros: "Macro commands can not be converted. Macro syntax have to be verified manually by the user in grandMA3." — [converter page](https://help.malighting.com/grandMA2/en/help/key_backup_menu_save_as_grandma3.html)
- Other limits: "Type and target of remotes are not converted" (another revision says DMX/MIDI/analog remotes do convert — version-dependent); fixture types with >8192 channel sets per attribute truncated; Xkeys X5, X6, X15, X16 not converted — same page / search extracts
- Converted fixture types carry source "grandMA2" and cannot be re-exported as GDTF; MVR export excludes them — [MA manual: Export Fixture Types](https://help.malighting.com/grandMA3/2.0/HTML/ft_export.html), [ACT v2.1 FAQ](https://support.actentertainment.com/knowledgeBase/36053570)
- Export name shows the target version, e.g. "Save as grandMA3 1.6.3.x" — [MA forum 7635](https://forum.malighting.com/forum/thread/7635-where-do-i-find-converted-grandma3-fixture-type-files-when-exporting-show-from-g/) (via search extract)
- No grandMA3-side "import grandMA2 show/XML" function was found in any 2.x manual search; grandMA3 imports only grandMA3 XML, GDTF, MVR, and other grandMA3 shows via Partial Show Read — [MA manual: Show Creator 2.0](https://help.malighting.com/grandMA3/2.0/HTML/show-creator.html), [MVR 2.4](https://help.malighting.com/grandMA3/2.4/HTML/patch_mvr.html)
- Third-party MA2 plugin converting MA2 timecode to MA3: "Convert2TCTo3" — [plugins.apox.hu](https://plugins.apox.hu/Convert2TCTo3)

### Inferences
- A third-party converter's value-add is precisely the areas MA's converter skips: macros, effects → phasers, MA2 layouts, embedded presets, and anything requiring MA2 XML as the only input (no MA2 onPC available).

### Gaps
- Could not read the full converter page; the Groups/Sequences/Layouts/Timecode handling lines were not in the extracts (groups and sequences are implied by "executors with sequences are converted" but not quoted).
- Recent (2025–2026) forum reports on converter quality under grandMA2 3.9.63 / grandMA3 2.5 were not retrievable.

---

## KQ7. Version landscape (2024–2026), data-model changes, onPC availability

### Takeaway
grandMA3 2.0.0.4 (April 2024) was the big data-model break (Show Creator replaced Import/Export; show files from a future version refuse to load); 2.3 (mid-2025) brought Assign-menu/filters; 2.4.2.2 (≈June 2026) added Phaser Recipes, cross-fixture-type presets, Preview and MVR via Partial Show Read; 2.5.0.3 shipped 2026-09-01 with 2.5.1.0 (2026-09-24) and 2.5.1.1 (2026-10-15) following, Lua core 5.5.0. onPC for Windows and macOS is a free download; a Command/Fader Wing is only needed for parameter output beyond the free 4096 (not confirmed here) and is irrelevant for file testing.

### Cited Findings
- v2.0.0.4 released ~April 2024 (webinar 5 April 2024); Show Creator "combines the functionality of the old Import/Export menu with new options", filter for cloned data types; Fixture Type Presets added — [MA news (de)](https://www.malighting.com/de/news/artikel/die-grandma3-software-version-20-ist-jetzt-verfuegbar-1-1358/), [soundlightup](https://en.soundlightup.com/news/the-grandma-3-takes-off-with-v2-0-0-4.html), [MA Release Notes 2.0](https://help.malighting.com/grandMA3/2.0/HTML/key_releasenotes.html)
- 2.0 notes: shows ≤1.9.7 migrated on load (mask settings → Column Set 1); future-version shows refuse to load; `Cook DataPool Thru /MergeLowPriority` to recook — [MA Release Notes 2.0](https://help.malighting.com/grandMA3/2.0/HTML/key_releasenotes.html)
- 2.3: release-note PDFs dated 2025-07-21, 2025-09-03, 2025-11-03; build 2.3.1.1 onPC; redesigned Handle tab in Assign menu; "New grandMA3 Lua Functions" section; `Import` shortcut changed to `Im` — [MA downloads](https://www.malighting.com/downloads/products/grandma3/), [MA Release Notes 2.3](https://help.malighting.com/grandMA3/2.3/HTML/key_releasenotes.html), [Import keyword 2.3](https://help.malighting.com/grandMA3/2.3/HTML/keyword_import.html)
- 2.4.2.2 (≈June 2026): Phaser Recipes; presets usable across all fixture types regardless of origin, MAgic presets can act as universal; Preview of cues/sequences; Phone Tethering; "MVR imports are now managed through the Partial Show Read window" — [e-techasia](https://www.e-techasia.com/?p=15266), [TPi](https://www.tpimagazine.com/?p=86552)
- 2.5: announced late Aug/Sep 2026; onPC 2.5.0.3 listed 2026-09-01, 2.5.1.0 on 2026-09-24, 2.5.1.1 on 2026-10-15 (Windows + macOS); features: Masters window, Locate, Channel Map in Patch, improved Phaser Recipes, QoL pass; released alongside grandMA2 v3.9.63.10; "available for download free of charge" — [MA news: 2.5 out now](https://www.malighting.com/news/article/grandma3-software-release-version-25-is-out-now-1521/), [MA downloads](https://www.malighting.com/downloads/products/grandma3/), [iSquint](https://isquint.net/2026/grandma3-version-2-5-masters-window-channel-map-locate-and-a-big-qol-pass/), [Live Design](https://www.livedesignonline.com/news/grandma3-software-release-version-25-out-now)
- 2.5 Lua core updated to 5.5.0; `HasActivePlayback` deprecated; DataPool child ordering changed (hard-coded index 6 for Sequences broke) — [Naostage autozoom PR #2](https://github.com/Naostage/grandma3-autozoom-plugin/pull/2)
- onPC free: "The free-of-cost grandMA3 software" page; onPC builds for Windows and macOS on the downloads page — [MA special page](https://www.malighting.com/special/grandma3-software/), [MA downloads](https://www.malighting.com/downloads/products/grandma3/)
- Live third-party verification baseline as of Oct 2026 is onPC 2.5.1.0 on macOS (Windows 11 partially) — [gma3-mcp docs/compatibility.md](https://github.com/bdstark/gma3-mcp/blob/main/docs/compatibility.md)
- MLA ships separate export plugins for 1.x / 2.0.x / 2.1.x / 2.2.x — [MLA docs](https://www.manula.com/manuals/avld/mla/14/en/topic/importing-grandma3-data) (via search extract)
- 1.x → 2.x folder/menu differences: 1.9 used the "Import/Export" menu; 2.x uses "Show Creator" — [kjoreplan-ma3 ma-versions.json](https://github.com/jorgen-iden/kjoreplan-ma3/blob/main/src/lib/config/ma-versions.json)

### Inferences
- Target 2.5.x for new work; validate generated XML against onPC 2.5.1.x but write DataVersion ≤ 2.3.x–2.4.x (known to import), because 2.5's own DataVersion string is not publicly confirmed.
- Expect the Lua object tree (pool indices) and Lua core version to shift between minors; XML has been far more stable (1.4.0.2 macro XML still structurally identical to 2.x).

### Gaps
- Release dates/contents of 2.1 and 2.2 were not found in retrievable sources.
- The exact DataVersion string a 2.5.1.x console writes was not found in any public sample.
- onPC free parameter/output limits were not researched (out of scope for file generation).
