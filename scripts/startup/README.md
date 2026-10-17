# Desktop startup card

The deployment hosts display this shared local HTML at 800 × 494 logical pixels
(aspect ratio 1.6194, approximately the golden ratio).
The left 384 pixels contain the official Hanhai Quantum emblem, product typography,
project version, live startup phase and substate, and copyright. The right 416 pixels
contain the materials-science illustration. Keep the layout and JavaScript
compatible with Windows WebView2, the legacy system HTML fallback (ES5), and
macOS WKWebView.

The version is never embedded in the HTML. Windows reads `launcher.ini`'s
`Version`, supplied by the packager from `KSSOLV_Toolbox.Version`, and injects
it at document creation (the legacy fallback uses `StartupCardBridge.GetVersion()`).
macOS uses the same project version passed
by `package_pkg.sh` to `build_startup_app.sh`, stored in `startup-host.json` and
injected at document start as `window.kssolvStartup.version`. The copyright
year follows the current calendar year. Startup time is not displayed.
The copyright displays the full company name: 合肥瀚海量子科技有限公司 in
Chinese and Hefei Hanhai Quantum Technology Co., Ltd. in English. The company
name stays together and wraps below the year when necessary.

The macOS card floats above the Runtime's separate application. On macOS 13 and
later, `canJoinAllApplications` keeps it visible when Stage Manager switches to
the initializing Runtime, instead of moving the card into the recent-app strip.
At handoff the host activates only the CEF application in its Runtime process
group, so Stage Manager can reveal the Toolbox window in the active set.
See Apple's [window collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications).

On macOS Dock ownership is handed off serially. The startup host first displays
its branded tile, then becomes an accessory before acknowledging the CEF
process's foreground request. CEF becomes the regular application so its native
menu bar and Stage Manager behavior remain available. This avoids concurrent
foreground owners, but the separate system operations may briefly leave no tile;
the accepted tradeoff prioritizes native window behavior. Both tiles use the
existing `companyLOGO.png` branding, composited on one opaque white rounded
plate by the existing Swift host at build time. The host and private window
bundle receive identical ICNS bytes. The signed, launch-scoped
`KssolvDockBridge.dylib` applies that image before promotion; AppKit draws the
standard Dock tile without a custom content view.

The macOS package identifier and public application's bundle identifier are both
`com.pwdft.kssolv`. The private window bundle and its signing identifier use
`com.pwdft.kssolv.window`; scoped Dock notifications use `com.pwdft.kssolv.dock.`
followed by the launch nonce. Keep the packager, signer, host and bridge in sync
when changing these identifiers.

The copied Compiler bundle remains an `LSUIElement`. The host validates the
bridge nonce, PID, process group and regular policy before revealing Toolbox.
A private registry in `~/Library/Caches/KSSOLV Toolbox/dock` binds the launch to
its host and signed library. Only the identified Compiler startup window is prevented
from ordering onscreen until explicit reveal; panels, alerts and sheets retain
their normal behavior, and the ordering hook is removed after reveal. Native
CEF handles Dock activation and menus. Launch-specific notifications cover
Finder reopen and host cleanup. Process-exit sources clean the owned session
when its Runtime or window process exits. Unexpected host exit leaves CEF
reachable. Shared Runtime files are untouched.

The package embeds a signed, branded copy of `MATLABWindow.app`, keeping its
executable name for Runtime compatibility. Only the validated Compiler process's
exact window path at the `execvp`/`execv`/`execve` boundary is redirected; argv and environment are preserved.
The host copies the template into an owner-only cache keyed by its content and
the Runtime root, verifies its bytes on reuse, and provides sibling framework
and helper aliases there. Those external aliases cannot live inside the sealed
application bundle. The cache copy survives process exit so Dock can still read
its branded icon while removing the tile. macOS can evict the cache; the host
recreates it on the next launch. The cache uses the configured Runtime root and
does not patch library load commands or require additional entitlements.

All standalone builds (Windows, macOS, and Linux), including the docking probe,
use the documented [`mcc -R -nojvm`](https://www.mathworks.com/help/compiler/matlab-runtime-startup-options.html) startup option through
`kssolv.util.StandaloneBuild`. Runtime metadata records `JVMEnabled=false` on
every platform. Startup locale paths use native environment variables.
`test_startup_app.sh` exercises the policy interception and lifecycle with a native fixture, without MATLAB
or a JVM; the signed real payload also requires installation acceptance tests.

macOS installation prewarm uses a separate background path. The native entry
does not construct `NSApplication` or WKWebView. It publishes a `mode=prewarm`
bridge registration before starting Runtime, reuses the private branded window
cache, and keeps the Compiler and CEF applications as UI elements. In this mode
the bridge suppresses foreground promotion, regular activation policy and window
ordering; it never requests a Dock handoff or reveals the main window. Runtime
still initializes the full application and must emit `KSSOLV_UI_PREWARM_OK`.
Both `orderWindow:relativeTo:` and `orderFrontRegardless` are guarded before
ordering: the latter can bypass the former in AppKit. Prewarm also clamps native
window opacity to zero from both public initializers through teardown, including
later opacity requests; the real CEF window can bypass the public ordering guard.
These guards are installed only in the validated prewarm CEF process. Foreground
activation and key-window requests are also suppressed, so an invisible accessory
application cannot take keyboard focus during prewarm. Foreground registration
alone is insufficient evidence of background operation. Real-payload
acceptance must sample WindowServer for the owned process group through startup
and exit, and require no visible windows or frontmost application samples as well
as the successful prewarm marker. A zero-opacity window may still be registered
as onscreen.
Prewarm runs in a dedicated process group led by its supervisor. The installer
watchdog terminates that group on timeout; the supervisor reaps Runtime, bounds
residual helper cleanup and removes its registry and communication directory.
Failure diagnostics go to the installation log rather than a modal alert.
The native fixture exercises successful background rendering, failure exit
status and the real installer watchdog with an actual held window process.

The 32-pixel margins and 8-pixel spacing grid align the issuer, product, status and
footer. KSSOLV Toolbox is one title group; the issuer uses a smaller horizontal
lockup. CSS clips the emblem, Chinese lettering and English lettering from the
unchanged official logo bitmap into three viewports; no brand text is typeset.
Copyright and the right-hand caption share a baseline-aligned bottom row, 16 CSS
pixels from the lower edge, including the legacy MSHTML flexbox prefixes.
The original right-hand artwork is unchanged, with only
its display framing adjusted and a single caption. There are no decorative badges.

Typography uses Segoe UI on Windows, with Microsoft YaHei UI first for Chinese;
macOS falls back to its system UI font and PingFang SC. Loading status is 14 px
semibold, substate and copyright are 12 px. The left panel uses only three type
sizes: 36 px for the complete product title, 14 px for primary information, and
12 px for supporting information. Secondary text uses dark slate on white.
The main phase, indeterminate progress bar and gray technical substate have fixed
positions. The headline stays "Starting KSSOLV Toolbox". The single-line substate
uses the approved ordered set of 25 Chinese/English messages. As requested, these
are estimated presentation stages, separate from the window handoff signals.
Stages 1–23 get fresh, weighted random durations per launch, normalized to a
24–27 second budget. After them, stage 24 holds without looping until the real
window is ready. Fast startup skips the remaining estimated stages. There is no
percentage or elapsed-time display and no fixed dwell that delays a ready window.
Before acknowledgement, both hosts call `prepareStartupHandoff()`: stage 24 and
then stage 25 each get two animation frames to paint. The native host acknowledges
only after this short paint sequence, then hands off immediately. Diagnostic
`presentation` records include the generated plan, monotonic displayed history,
and final paint flag. Native liveness polls do not change the visible substate.
The close button has a 44 × 36 hit target and hover/pressed states, with no focus
outline. Its native preview overlay is excluded from tab order and suppresses focus cues.
Escape does not cancel startup, in either the preview or HTML host; deliberate
cancellation uses the close button. The artwork is completely static: no drift, scaling animation
or breathing overlay. The activity segment uses one `translate3d` update per
`requestAnimationFrame`, based on its high-resolution timestamp. No 40 ms throttle
or application frame-rate cap remains, and no layout property changes each frame.
It follows the renderer/display cadence, including 120 Hz and faster when supported;
this is not a guarantee of 120 displayed frames on every device.
See [`requestAnimationFrame`](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame).
Progress animation stops when reduced motion is requested; MSHTML also reads the native Windows client-area
animation preference through the bridge using read-only
[`SPI_GETCLIENTAREAANIMATION`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow).
Windows contrast styles are included.

The Windows launcher prefers the system WebView2 Runtime for GPU rendering and
high-refresh displays, using the same shared HTML. The build downloads the pinned
Microsoft.Web.WebView2 SDK 1.0.3912.50 and verifies its SHA-256 before extracting;
Inno packages its two managed assemblies, x64 loader and complete SDK license.
It does not install/download a browser on application startup. If the system lacks
WebView2 Runtime, the legacy MSHTML host still works offline, with a lower possible
frame rate. Installation prewarm bypasses both renderers.

The Windows launcher embeds a system-DPI-aware manifest. Its single HTML view
is sized in physical pixels at load. WebView2 handles display density; the legacy
fallback calibrates optical zoom against its CSS viewport. Both render the
800 × 494 layout directly at display density.
The host tests record both dimensions and DPI awareness in `.layout` sidecars.
At the tested 150% system scale, these are 1200 × 741 physical pixels, 800 × 494
CSS pixels, and `devicePixelRatio=1.5`. This does not change Windows display settings.
The native-host test records `.animation` cadence samples separately from layout.
These measure rAF callbacks and actual style updates, not GPU scanout/presentation.
On the local 165 Hz screen, WebView2 sampled approximately 165 updates/s with
6.2 ms p95 intervals; the legacy control sampled around 40–62 updates/s. The
`-MinimumAnimationFps 120` test option checks the modern renderer against that
target on suitable hardware without imposing it on the compatibility fallback.
See Microsoft's [process DPI awareness documentation](https://learn.microsoft.com/en-us/windows/win32/hidpi/setting-the-default-dpi-awareness-for-a-process)
and [embedded WebBrowser DPI guidance](https://learn.microsoft.com/en-us/visualstudio/extensibility/addressing-dpi-issues2?view=visualstudio#enabling-hdpi-support-to-the-weboc).

The installer copies `companyLOGO.png` from the existing UI resources as
`company-logo.png`. The original logo is not regenerated or modified.
Both platform packagers copy `quantum-materials.png` alongside `index.html`.
The artwork is illustrative, rather than output from a particular simulation.

`quantum-materials.png` was generated with the built-in imagegen tool on
2026-10-15. The generated original is retained, and the production copy lives
in this directory. No network access or additional rendering runtime is needed.

Final generation prompt:

> Use case: stylized-concept. Asset type: final production hero artwork for a premium desktop materials-science simulation software splash screen, art only, not a UI mockup. Primary request: a visually exceptional, precise scientific 3D composition with the understated polish of high-end engineering software. Portrait 11:12 composition, full bleed. A single sculptural crystalline slab with an orderly hexagonal atomic lattice receding diagonally from lower left to upper right, fine satin silver bonds and small polished blue-silver atom nodes, intersected by a flowing translucent cobalt-blue electron-density isosurface. One small complementary amber-gold isosurface lobe, no red. The surfaces feel like sophisticated scientific volume visualization, with finely detailed contour mesh visible selectively on edges, smooth translucent glass interiors, realistic physical materials and beautiful depth. Strong coherent central sculptural silhouette, asymmetric composition, visually legible at 440 by 480 pixels. Deep midnight navy background #071b32 fading to desaturated petrol blue near the sculpture, controlled cyan rim light and soft studio illumination, crisp detail, restrained luminous highlights, dark calm margins especially at the top and bottom for separate HTML captions. Refined, credible, cinematic but sober. Illustration inspired by electronic structure and quantum materials, not a specific real simulation dataset. No text, no letters, no digits, no logos, no watermark, no UI, no border. Avoid generic sci-fi, orbit rings, random particles, stars, electric lightning, rainbow coloring, overly neon glow, plastic toy atoms, chaotic wires, dashboards, charts, decorative concentric circles.

MATLAB initialization contains no fine-grained splash progress calls. The entry
point and Toolbox constructor retain their original initialization logic; one
`StartupSplash.tryShow(this)` call at the window-display boundary encapsulates
deployment detection, early window handoff, and completion diagnostics. It
returns false immediately in ordinary MATLAB operation. The host protocol only
needs shell-ready, visible, and failure notifications; displayed substates are
scheduled entirely by the shared HTML.
Ordinary MATLAB operation and installer prewarm do not display this card.

Window handoff uses the existing internal AppContainer/CEF Window interfaces:
`Visible=true` starts the front end offscreen, then `Window.hide()` keeps the
native shell hidden while the host prepares the final two messages. MATLAB
publishes `shell-ready` through `KSSOLV_STARTUP_SIGNAL`; the host writes a
nonce-qualified `.reveal` acknowledgement, MATLAB calls `Window.show()` and
publishes `visible`, and the host closes the card. Remaining panels load in
the busy Toolbox window; a separate `startup-loaded.json` records completion.
Keep constructor initialization before creating the native window, because
AppContainer contexts cannot be added after its children are attached.
The host owns only its launch's process tree and terminates it on cancellation,
failure, or timeout. Successful handoff leaves Toolbox running.

The macOS public bundle is named `KSSOLV Toolbox.app`; Compiler executables and
private helper names retain their generated spelling. The startup card uses
a native cancel button above WebKit with always-active hover tracking, a pointing
hand cursor and red hover/pressed feedback. It calls the same launch-scoped
cancellation path as the HTML button, which remains in use on Windows.
The card is a presentation surface: text selection, clipboard copying, native
image dragging and the browser context menu are disabled. These restrictions do
not consume button clicks or remove the accessibility text.
On macOS the canvas stays at 800×494 logical points. The host fits it uniformly
inside the current screen's visible frame with a 16-point margin, never enlarging
it above its design size. WebKit and the native cancel button share this canvas,
so artwork, text and hit targets scale together. Screen changes refit the card;
Retina backing resolution remains managed by AppKit.

The native macOS product PKG supports three Runtime delivery modes:
`web` downloads missing Runtime components from MathWorks; `installer` carries
those components for offline installation; `none` requires a compatible existing
Runtime. All modes first check the release, minimum build, arm64 architecture and
required component records without executing Runtime. Existing standard system
and user locations, an explicit `KSSOLV_RUNTIME_ROOT`, and the previously recorded
location are checked. New Runtime installations use
`/Applications/MATLAB/MATLAB_Runtime/<release>`. The `web` and `installer` packages
present the Runtime license in the native Installer before installation.

In `none` mode, Installation Type includes an **Existing MATLAB Runtime** choice
with a native location control. Its default startup disk root (`/`) requests
automatic detection. Select the version folder containing `VersionInfo.xml` to
override detection, including a location on another mounted volume. An explicit
selection must pass the release, minimum build, arm64 and component checks even
when another compatible Runtime is installed. A payload-free component validates
and records this choice before support or application installation; it writes
nothing into the selected Runtime. Missing or incompatible Runtime stops the
installation while preserving the old application and Runtime configuration.

For `web` and `installer`, the support component prepares and verifies Runtime before application removal.
The application preinstall hook verifies it again, refusing to uninstall when
Runtime is unavailable. It then finds identified old bundles in `/Applications`,
local users' `Applications` folders and the previously recorded custom location,
including the underscored name. It removes those bundles, their generated runner
and icon, known receipts and the old prewarm task. Shared Runtime, user settings,
projects and unknown files remain. Running Toolbox instances block removal.

On Installation Type, the native `customLocation` control selects the application
folder (default `/Applications`, startup volume only). System support remains
under `/Library`. The selected application and validated Runtime paths are stored
in `/Library/Application Support/KSSOLV Toolbox/{application,runtime}.plist`.
The launcher and background prewarm use these paths. Prewarm runs as the logged-in
user only after the application payload has been installed.

Build with MATLAB `-nojvm -batch "buildInstaller('web');"`, then run
`bash scripts/macos/package_pkg.sh --runtime-delivery web` and
`bash scripts/macos/sign_and_notarize_app.sh --pkg <output.pkg>`.
To package a second delivery mode from the same compiled application without
recompiling, run MATLAB `-nojvm -batch
"addpath('scripts/macos'); prepareRuntimeInstaller('installer');"`, then package
with `--runtime-delivery installer`. `none` needs no Runtime installer payload.
`auto` follows the compiled metadata. Runtime-only installers are generated through
MathWorks `compiler.runtime.customInstaller` and tied to the dependency JSON hash;
stale or mismatched installers are rejected.
For offline packaging, first run `compiler.runtime.download` with `-nojvm`, or
set `MATLAB_RUNTIME_INSTALLER` to the matching official ZIP. The macOS helper
configures the compiler cache location with a temporary settings value; it
restores existing temporary values and removes any setting/group it introduced.
It never writes a personal value. An isolated `MATLAB_PREFDIR` may also be used
for a packaging-only process.
Runtime license text is extracted verbatim from the official PDF for Installer's
text viewer; both are included. `pkg/RuntimeLicense.json` records hashes of the
reviewed PDF and text. A changed vendor agreement stops packaging until those
assets are refreshed and checked. `MATLAB_RUNTIME_LICENSE` can point to the
official PDF when it is not available in an installed Runtime or compiler cache.

`python3 scripts/macos/test_pkg_runtime_modes.py` checks Runtime branches and
failure preservation. `python3 scripts/macos/test_pkg_upgrade.py` exercises old
installation detection and removal against isolated filesystem fixtures.

Windows regression entry points are `scripts/windows/tests/Test-StartupSplash.ps1`
for the native/HTML hosts and `scripts/windows/tests/Test-InstalledStartup.ps1`
for the installed MATLAB payload, Locale, handoff, and full interface loading.
The latter also supports `-Capture` and `-ManualCancel`. Source-mode and Locale
contracts live in `kssolv.ui.test.StartupSplashTest` and `StartupLocaleTest`.
On macOS, run `bash scripts/macos/test_startup_app.sh` to check the Swift host's
handoff, retained Runtime process, and prewarm bypass. This test requires a Mac.
