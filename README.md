# Oniro Browser

A multi-tab web browser for OpenHarmony 6.1 (API 23), written in ArkTS on top of
the system ArkWeb engine. Built for and verified on the **Volla Phone Plinius**
(`ansuz`) running native OHOS through the hybris_generic port.

## Architecture

This follows "Architecture A" of the ArkWeb browser blueprint: an ArkTS/ArkUI
shell over the platform web engine, rather than a private Chromium build. The
engine work the blueprint describes as phases 1–3 (toolchain, Ozone backend,
AppSpawn renderer hosting) is already delivered by the platform — the device
ships `com.ohos.arkwebcore` with `libarkweb_engine.so`, and renderers are spawned
by `nwebspawn`. What this project implements is phase 4: the browser itself.

```
entry/src/main/ets/
├── entryability/EntryAbility.ets   engine warm-up, data init, external links, memory level
├── pages/Index.ets                 the shell: tabs, omnibox routing, overlays, memory policy
├── model/
│   ├── BrowserTab.ets              one tab: controller, navigation state, sleep/wake
│   ├── BrowserStore.ets            relational store (history, bookmarks) + preferences
│   ├── Settings.ets                settings mirrored into AppStorage, persisted to preferences
│   └── DialogRequest.ets           engine-raised modal, rendered in-page
├── components/
│   ├── WebTabView.ets              the Web component and every engine callback
│   ├── Chrome.ets                  omnibox row, bottom navigation bar, shared rows
│   ├── HomeView.ets                new-tab page: speed dial + most visited
│   ├── TabSwitcher.ets             tab grid with live previews
│   ├── ListViews.ets               history and bookmarks
│   ├── SettingsView.ets            settings surface
│   └── Overlays.ets                menu, dialogs, find bar, suggestions, toast, link menu
└── common/                         types, theme, URL handling, user agent, formatting, logging
```

## Features

* Multiple tabs with a preview grid, new/close/close-all, and target=`_blank`
  windows routed into real tabs (`onWindowNew`).
* Omnibox that tells URLs from queries, with suggestions drawn from history,
  and five selectable search engines.
* Back/forward/reload/stop, progress, per-site security indicator, error pages.
* New-tab page with speed dial and most-visited sites.
* History and bookmarks in a relational store; session restored on launch.
* Find in page, desktop-site switch, text zoom, dark theme (chrome and content).
* Downloads through `WebDownloadDelegate`, into the app's `files/downloads`.
* Long-press a link for open / open-in-new-tab / copy.
* JavaScript dialogs, TLS-error prompts, camera/microphone and geolocation
  requests, all drawn in-page and mapped onto system permissions.
* Opens `http`/`https` links sent by other apps (`ohos.want.action.viewData`).
* Background tabs sleep when they exceed the live-tab budget or when the system
  reports memory pressure, and reload on return.

## Three platform notes

* **Never destroy a live `Web` component.** Tearing one down blocks the UI
  thread inside `libarkweb_engine.so` (`web_delegate.cpp NotifyDestory`) long
  enough for the ability watchdog to kill the app with `THREAD_BLOCK_6S`. Tabs
  therefore sleep by calling `terminateRenderProcess()` and keeping the
  component, and a tab being closed has its renderer terminated first.
* **ArkWeb's stock user agent is unrecognisable to sites.** It reads
  `Mozilla/5.0 (Phone; OpenHarmony 6.1) … Safari/537.36 ArkWeb/6.1.0.32
  Mobile`: no `Linux` platform token, and the mobile marker after the engine
  token instead of `Chrome/<v> Mobile Safari/537.36`. Sniffers then serve their
  oldest fallback — google.com answers with its WAP-era "tier 3" page.
  `common/UserAgent.ets` reshapes the engine's own string into the
  Chrome-on-mobile order, keeping the real OS and engine versions.
* **`about:blank` is not a home page.** Page callbacks fire for it during
  engine setup, so the shell ignores those events instead of switching to the
  start page.

## Build and run

```bash
oniro-app build                 # assembleHap (API 23, OpenHarmony runtime)
oniro-app sign                  # once, generates signingConfigs
oniro-app app apply             # install on the connected device
oniro-app app launch
```

Logs: `hdc shell "hilog -x -T OniroBrowser"`.
