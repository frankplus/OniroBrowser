/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * Renders the Web component of one tab and maps every engine callback onto
 * shell state (title, progress, history, dialogs, downloads, permissions).
 */
import { webview } from '@kit.ArkWeb';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BrowserTab } from '../model/BrowserTab';
import { DialogKind, DialogRequest } from '../model/DialogRequest';
import { SettingsKeys } from '../model/Settings';
import { Theme, Palette } from '../common/Theme';
import { UrlUtils } from '../common/UrlUtils';
import { Logger } from '../common/Logger';

const DESKTOP_UA: string =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';

@Component
export struct WebTabView {
  @ObjectLink tab: BrowserTab;
  @Prop @Watch('onActiveChanged') active: boolean;
  @StorageProp(SettingsKeys.JS) jsEnabled: boolean = true;
  @StorageProp(SettingsKeys.DESKTOP) @Watch('onDesktopChanged') desktopMode: boolean = false;
  @StorageProp(SettingsKeys.TEXT_ZOOM) textZoom: number = 100;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  onVisit: (url: string, title: string) => void = () => {};
  onDialog: (request: DialogRequest) => void = () => {};
  onToast: (message: string) => void = () => {};
  onNewWindow: (targetUrl: string) => webview.WebviewController = () => new webview.WebviewController();
  onWindowExit: (tabId: number) => void = () => {};
  onActivateRequest: (tabId: number) => void = () => {};
  onLinkMenu: (linkUrl: string) => void = () => {};
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();

  aboutToAppear(): void {
    this.setupDownloads();
  }

  onActiveChanged(): void {
    if (!this.tab.attached) {
      return;
    }
    try {
      if (this.active) {
        this.tab.controller.onActive();
      } else {
        this.tab.controller.onInactive();
      }
    } catch (err) {
      Logger.warn('onActive toggle failed: ' + (err as BusinessError).message);
    }
  }

  onDesktopChanged(): void {
    if (!this.tab.attached) {
      return;
    }
    try {
      this.tab.controller.setCustomUserAgent(this.desktopMode ? DESKTOP_UA : webview.WebviewController.getDefaultUserAgent());
      this.tab.reload();
    } catch (err) {
      Logger.warn('user agent switch failed: ' + (err as BusinessError).message);
    }
  }

  private downloadDir(): string {
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) {
      return '';
    }
    const dir: string = context.filesDir + '/downloads';
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
    } catch (err) {
      Logger.warn('download dir: ' + (err as BusinessError).message);
    }
    return dir;
  }

  private setupDownloads(): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      const dir: string = this.downloadDir();
      if (dir.length === 0) {
        item.cancel();
        return;
      }
      const name: string = UrlUtils.fileNameOf(item.getSuggestedFileName(), 'download.bin');
      const target: string = dir + '/' + name;
      item.start(target);
      this.onToast('Downloading ' + name);
    });
    this.downloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      this.onToast('Saved ' + UrlUtils.fileNameOf(item.getSuggestedFileName(), 'file') + ' to app files/downloads');
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.onToast('Download failed (' + item.getLastErrorCode() + ')');
    });
  }

  private applyControllerSettings(): void {
    const tab: BrowserTab = this.tab;
    tab.attached = true;
    try {
      if (this.desktopMode) {
        tab.controller.setCustomUserAgent(DESKTOP_UA);
      }
      tab.controller.setDownloadDelegate(this.downloadDelegate);
    } catch (err) {
      Logger.warn('controller setup: ' + (err as BusinessError).message);
    }
    if (tab.pendingUrl.length > 0) {
      const pending: string = tab.pendingUrl;
      tab.pendingUrl = '';
      tab.navigate(pending);
    }
  }

  private requestSystemPermissions(resources: Array<string>, granted: () => void, denied: () => void): void {
    const needed: Permissions[] = [];
    for (const resource of resources) {
      if (resource === 'TYPE_VIDEO_CAPTURE') {
        needed.push('ohos.permission.CAMERA');
      } else if (resource === 'TYPE_AUDIO_CAPTURE') {
        needed.push('ohos.permission.MICROPHONE');
      }
    }
    if (needed.length === 0) {
      granted();
      return;
    }
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) {
      denied();
      return;
    }
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(context, needed).then((result: PermissionRequestResult) => {
      const codes: Array<number> = result.authResults;
      for (const code of codes) {
        if (code !== 0) {
          denied();
          return;
        }
      }
      granted();
    }).catch((err: BusinessError) => {
      Logger.warn('permission request failed: ' + err.message);
      denied();
    });
  }

  build() {
    Stack() {
      if (this.tab.alive) {
        Web({ src: this.tab.initialUrl, controller: this.tab.controller })
          .width('100%')
          .height('100%')
          .javaScriptAccess(this.jsEnabled)
          .domStorageAccess(true)
          .databaseAccess(true)
          .fileAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .geolocationAccess(true)
          .zoomAccess(true)
          .metaViewport(true)
          .mediaPlayGestureAccess(true)
          .multiWindowAccess(true)
          .allowWindowOpenMethod(true)
          .horizontalScrollBarAccess(false)
          .verticalScrollBarAccess(true)
          .mixedMode(MixedMode.Compatible)
          .cacheMode(CacheMode.Default)
          .textZoomRatio(this.textZoom)
          .darkMode(this.isDark ? WebDarkMode.On : WebDarkMode.Off)
          .forceDarkAccess(this.isDark)
          .onControllerAttached(() => {
            this.applyControllerSettings();
          })
          .onPageBegin((event) => {
            this.tab.loading = true;
            this.tab.errorText = '';
            if (UrlUtils.isHome(event.url)) {
              return;
            }
            this.tab.url = event.url;
            this.tab.secure = UrlUtils.isSecure(event.url);
            this.tab.isHome = false;
          })
          .onProgressChange((event) => {
            this.tab.progress = event.newProgress;
          })
          .onPageEnd((event) => {
            this.tab.loading = false;
            this.tab.progress = 100;
            if (UrlUtils.isHome(event.url)) {
              return;
            }
            this.tab.url = event.url;
            this.tab.secure = UrlUtils.isSecure(event.url);
            this.tab.syncNavState();
            try {
              const title: string = this.tab.controller.getTitle();
              if (title.length > 0) {
                this.tab.title = title;
              }
            } catch (err) {
              Logger.warn('getTitle: ' + (err as BusinessError).message);
            }
            if (!UrlUtils.isHome(event.url) && this.tab.errorText.length === 0) {
              this.onVisit(event.url, this.tab.title);
            }
          })
          .onTitleReceive((event) => {
            if (event.title.length > 0) {
              this.tab.title = event.title;
            }
          })
          .onFaviconReceived((event) => {
            this.tab.favicon = event.favicon;
          })
          .onNavigationEntryCommitted(() => {
            this.tab.syncNavState();
          })
          .onRefreshAccessedHistory((event) => {
            this.tab.url = event.url;
          })
          .onErrorReceive((event) => {
            if (event.request.isMainFrame()) {
              this.tab.errorText = event.error.getErrorInfo() + ' (' + event.error.getErrorCode() + ')';
              this.tab.loading = false;
            }
          })
          .onRenderExited(() => {
            this.tab.loading = false;
            if (this.tab.sleeping) {
              // Expected: the shell released this background tab's renderer.
              return;
            }
            this.tab.errorText = 'The page stopped responding and was closed.';
          })
          .onAlert((event) => {
            this.onDialog(new DialogRequest(DialogKind.MESSAGE, UrlUtils.shortHost(event.url), event.message,
              () => event.result.handleConfirm(), () => event.result.handleConfirm()));
            return true;
          })
          .onConfirm((event) => {
            this.onDialog(new DialogRequest(DialogKind.CONFIRM, UrlUtils.shortHost(event.url), event.message,
              () => event.result.handleConfirm(), () => event.result.handleCancel()));
            return true;
          })
          .onPrompt((event) => {
            this.onDialog(new DialogRequest(DialogKind.PROMPT, UrlUtils.shortHost(event.url), event.message,
              (text: string) => event.result.handlePromptConfirm(text), () => event.result.handleCancel(),
              event.value));
            return true;
          })
          .onBeforeUnload((event) => {
            this.onDialog(new DialogRequest(DialogKind.CONFIRM, 'Leave this page?', event.message,
              () => event.result.handleConfirm(), () => event.result.handleCancel(), '', 'Leave', 'Stay'));
            return true;
          })
          .onSslErrorEventReceive((event) => {
            this.onDialog(new DialogRequest(DialogKind.SSL, 'Connection is not private',
              'This site presented an invalid certificate (error ' + event.error + '). Continue anyway?',
              () => event.handler.handleConfirm(), () => event.handler.handleCancel(), '', 'Continue', 'Go back'));
          })
          .onPermissionRequest((event) => {
            const origin: string = event.request.getOrigin();
            const resources: Array<string> = event.request.getAccessibleResource();
            this.onDialog(new DialogRequest(DialogKind.PERMISSION, UrlUtils.shortHost(origin),
              'Allow access to ' + WebTabView.describeResources(resources) + '?',
              () => {
                this.requestSystemPermissions(resources, () => event.request.grant(resources),
                  () => event.request.deny());
              },
              () => event.request.deny(), '', 'Allow', 'Block'));
          })
          .onGeolocationShow((event) => {
            this.onDialog(new DialogRequest(DialogKind.PERMISSION, UrlUtils.shortHost(event.origin),
              'Share your location with this site?',
              () => event.geolocation.invoke(event.origin, true, false),
              () => event.geolocation.invoke(event.origin, false, false), '', 'Allow', 'Block'));
          })
          .onDownloadStart((event) => {
            Logger.info('legacy download start: ' + event.url);
          })
          .onSearchResultReceive((event) => {
            // The engine reports a 0-based ordinal only for the initial
            // search, so the shell keeps the visible position itself.
            this.tab.matchCount = event.numberOfMatches;
            if (event.numberOfMatches === 0) {
              this.tab.matchIndex = 0;
            } else if (this.tab.matchIndex === 0 || this.tab.matchIndex > event.numberOfMatches) {
              this.tab.matchIndex = 1;
            }
          })
          .onContextMenuShow((event) => {
            const link: string = event.param.getLinkUrl();
            if (link.length === 0) {
              // Text selection and image menus stay with the engine.
              return false;
            }
            this.onLinkMenu(link);
            event.result.closeContextMenu();
            return true;
          })
          .onWindowNew((event) => {
            const controller: webview.WebviewController = this.onNewWindow(event.targetUrl);
            event.handler.setWebController(controller);
          })
          .onWindowExit(() => {
            this.onWindowExit(this.tab.id);
          })
          .onActivateContent(() => {
            this.onActivateRequest(this.tab.id);
          })
      }

      if (this.tab.errorText.length > 0) {
        this.errorCard(Theme.of(this.isDark))
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  errorCard(palette: Palette) {
    Column({ space: 14 }) {
      Text('⚠')
        .fontSize(40)
        .fontColor(palette.textDim)
      Text('This page could not be loaded')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(palette.text)
      Text(UrlUtils.pretty(this.tab.url))
        .fontSize(13)
        .fontColor(palette.textDim)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.tab.errorText)
        .fontSize(12)
        .fontColor(palette.textDim)
        .maxLines(3)
        .textAlign(TextAlign.Center)
      Button('Try again')
        .backgroundColor(palette.accent)
        .fontColor('#FFFFFF')
        .height(38)
        .onClick(() => {
          this.tab.errorText = '';
          this.tab.reload();
        })
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(palette.bg)
  }

  static describeResources(resources: Array<string>): string {
    const names: string[] = [];
    for (const resource of resources) {
      if (resource === 'TYPE_VIDEO_CAPTURE') {
        names.push('the camera');
      } else if (resource === 'TYPE_AUDIO_CAPTURE') {
        names.push('the microphone');
      } else if (resource === 'TYPE_SENSOR') {
        names.push('motion sensors');
      } else if (resource === 'TYPE_MIDI_SYSEX') {
        names.push('MIDI devices');
      }
    }
    return names.length > 0 ? names.join(' and ') : 'a device capability';
  }
}
