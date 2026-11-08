# Time on Task

A native SwiftUI macOS timer and stopwatch that counts time only in your chosen apps and websites. Requires macOS 14 or newer.

## Run

Open `TimeOnTask.xcodeproj`, select the **TimeOnTask** scheme and **My Mac**, then Run (⌘R). Debug builds use local ad-hoc signing. Configure your own signing team and Developer ID before distributing; this development build isn't notarized or configured for the Mac App Store.

## Timers

Choose Countdown or Stopwatch. Countdown uses separate selectable **hours, minutes, seconds** controls inspired by Apple's Clock app. Click a segment and type digits to replace its value, or press **↑/↓** to adjust it. Move between segments with **←/→**, **Tab**, or **Shift-Tab**. These controls show a selection highlight with no text caret; there are no cramped text fields or stepper arrows. Each segment uses two digits, and the first digit replaces the previous value. Backspace clears a segment; Enter clears the selection. Any duration from one second to 99:59:59 is supported. Start the session and switch to an allowed app or website. The menu bar retains the system timer/pause symbol and time display.

Only an allowed frontmost application counts. A permitted browser also needs an allowed URL in its active tab. Switching away pauses automatically; returning resumes an armed session. Manual pause stays paused. Countdown completes with a sound. Reset the session to edit its mode or duration.

## Focus modes

Click a **focus-mode card** to switch modes. **New focus mode** opens a dedicated editor; **Manage** opens the same editor for your existing modes. Choose a name, one of 24 icons, and one of eight colors. The editor includes a preview, a list of modes, and Save/Create, Duplicate, and Delete actions. For example, use different icons and colors for Development, Writing, and Design. Icons appear on cards, beside the timer, and in the menu bar mode selector; the selected color accents the timer and controls. Existing modes get a default icon and color while retaining their apps, websites, and progress.

Each focus mode saves its own native apps, websites, browsers, countdown/stopwatch setting, duration, and elapsed session time. Website rules are shared by **all browsers within that mode**. Switching modes pauses the session and preserves progress; start/resume explicitly in the new mode. Duplicating copies the rules and timer settings into a fresh session. Deleting removes only the selected mode; the final mode cannot be deleted.

Existing settings from the original single-session app migrate automatically into **Work**. The bundle identifier and original storage key are retained for migration. The new workspace is saved separately in `TimeOnTask.workspace.v2`.

## Browsers and website rules

1. Under **Browsers**, use **Add browser** to choose an installed supported browser. Selecting a supported browser through **Add application…** also adds it to Browsers rather than counting all of its tabs.
2. Open that browser and click its **Connect** button. Allow the macOS Automation request. Each browser needs its own permission; reconnect after relaunching Time on Task.
3. New focus modes start with no websites. Add a website address such as `youtube.com` or `wikipedia.org`. The `www` version is included automatically, so `youtube.com` also counts `www.youtube.com` and its pages. Other subdomains need separate entries; paths and wildcards are not accepted as rules.

For local development, `localhost`, `127.0.0.1`, and optional ports such as `localhost:3000` still work when added explicitly. They are never added automatically. Existing website lists are preserved. Without a port, all ports count. Local names and IP addresses use exact matching.

Supported integrations: Safari, Google Chrome, Brave, Microsoft Edge, Vivaldi, Opera, Chromium, Arc, and Dia. Only installed browsers appear in the menu. They use their AppleScript tab APIs; no Accessibility, Screen Recording, or JavaScript injection permission is needed. A browser whose scripting interface is unavailable or different from the supported integration pauses tracking and reports an error. Firefox requires a browser extension and is not supported yet. Known unsupported browsers are excluded from the native-app picker. Regular apps remain selectable even when they register HTTP(S) URL handlers, such as ChatGPT. Browser classification uses explicit bundle identifiers rather than URL-handler declarations.

If permission is denied, open **System Settings → Privacy & Security → Automation**, enable the browser under Time on Task, then reconnect. Closing all browser windows pauses tracking. Incognito windows are excluded in the Chromium integrations that expose window mode. Safari, Arc, and Dia do not expose equivalent private-window information through these integrations; their private tabs may be evaluated like normal tabs. No private browsing history is saved.

## Appearance and branding

The **Appearance** menu offers **System**, **Light**, and **Dark**, with a saved local choice that also applies to the menu bar panel. System follows macOS.

The new `TimeOnTask/AppIcon.icon` is a native Icon Composer document with light and dark variants for macOS 26 and later. It contains a simple generated clock/checkmark foreground and native appearance-specific backgrounds and fills. Older macOS versions use the new light icon in the legacy icon catalog. The in-app mark adapts its tint to light/dark mode. The menu bar intentionally uses system symbols instead of the color logo.

`Branding/v2` contains the foreground source, native light/dark PNG exports, and the exact image generation prompt. Version-one artwork remains in `Branding/`.

## Timing, persistence, and privacy

- Browser URLs are sampled roughly every half second. Boundaries are approximate; navigation entirely between samples can be missed. An extension could provide more immediate events in a future version.
- Timing uses system uptime and credits only intervals with eligible samples at both ends, up to two seconds apart. App switches and long timing gaps conservatively discard the intervening interval. Stale browser responses cannot credit another focus mode or app.
- Sleep and inactive user sessions pause tracking. Inactivity detection is not enabled: reading and thinking count while an allowed app remains active.
- The app explicitly uses regular macOS activation so its Dock icon remains available, including when launched by Xcode.
- Closing the main window leaves the menu bar app running. Use **Open Time on Task** there to reopen the single main window, or Quit to exit.
- Settings and focus-mode sessions live locally in UserDefaults. Time is saved about every five seconds and on pause, switching modes, reset, edits, or quit. Relaunch restores progress in a paused state. A crash may lose the last few seconds.
- URLs are read in memory for matching. Page contents, titles, and browsing history are not stored or transmitted. There is no analytics or network service.

## Verification

```sh
xcodebuild -project TimeOnTask.xcodeproj -scheme TimeOnTask -configuration Debug -derivedDataPath build build
swiftc TimeOnTask/FocusRules.swift TimeOnTask/FocusConfiguration.swift Tests/main.swift -o /tmp/timeontask-tests
/tmp/timeontask-tests
```

Regression checks cover hostname/port matching, spoofing, pause/resume intervals, long gaps, arbitrary durations, legacy migration, independent focus modes, duplication, deletion, appearance migration, icon/color persistence, numeric segment entry, and persistence.

Manual integration checks: grant/deny each browser's Automation permission; alternate allowed/disallowed tabs, apps and browser windows; verify sleep/wake and relaunch; check the menu bar; test custom durations and mode switching. Live browser integrations require the user's per-browser permission and are not fully verified by the core regression checks.

## Source map

- `TimeOnTaskApp.swift`: main window, appearance choice, and menu bar.
- `ContentView.swift`: custom duration controls, focus-mode editor, app/browser/website lists.
- `DurationPicker.swift`: caret-free native number segments, keyboard entry, arrows, navigation, and accessibility.
- `FocusModeManager.swift`: mode cards, icon/color palette, preview, and management editor.
- `FocusModel.swift`: session coordination, app monitoring, browser connections, persistence.
- `FocusConfiguration.swift`: duration validation, focus-mode workspace, legacy migration.
- `FocusRules.swift`: exact hostname/port matching and monotonic timing.
- `BrowserReader.swift`: supported browsers and serialized, bounded AppleScript reads.
