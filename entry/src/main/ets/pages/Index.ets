/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * The browser shell: tab ownership, omnibox routing, overlays and the
 * memory policy that decides which tabs keep a live renderer.
 */
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { mediaquery } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { BrowserTab } from '../model/BrowserTab';
import { BrowserStore } from '../model/BrowserStore';
import { Settings, SettingsKeys } from '../model/Settings';
import { DialogRequest } from '../model/DialogRequest';
import {
  BookmarkEntry,
  HistoryEntry,
  OverlayKind,
  SessionRecord,
  SessionTabRecord,
  Suggestion,
  SuggestionKind
} from '../common/Types';
import { Theme } from '../common/Theme';
import { DownloadTarget } from '../common/Downloads';
import { UrlUtils } from '../common/UrlUtils';
import { Logger } from '../common/Logger';
import { BottomBar, OMNIBOX_ID, TopBar } from '../components/Chrome';
import { WebTabView } from '../components/WebTabView';
import { HomeView } from '../components/HomeView';
import { TabSwitcher } from '../components/TabSwitcher';
import { BookmarksView, HistoryView } from '../components/ListViews';
import { SettingsView } from '../components/SettingsView';
import { DialogHost, FindBar, LinkMenu, MenuSheet, SaveToGalleryBar, SuggestionList, Toast } from '../components/Overlays';

@Entry
@Component
struct Index {
  @State tabs: BrowserTab[] = [];
  @State activeTabRef: BrowserTab = new BrowserTab('');
  @State activeId: number = 0;
  @State overlayKind: number = OverlayKind.NONE;
  @State editing: boolean = false;
  @State omniText: string = '';
  @State suggestions: Suggestion[] = [];
  @State dialog: DialogRequest | undefined = undefined;
  @State toastMessage: string = '';
  @State pendingGallerySave: DownloadTarget | undefined = undefined;
  @State findVisible: boolean = false;
  @State bookmarked: boolean = false;
  @State linkMenuUrl: string = '';
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @StorageLink('pendingUrl') @Watch('onPendingUrl') pendingUrl: string = '';
  @StorageLink('memoryPressure') @Watch('onMemoryPressure') memoryPressure: number = 0;
  private queryListener: mediaquery.MediaQueryListener | undefined = undefined;
  private sessionTimer: number = -1;
  private toastTimer: number = -1;
  private sessionApplied: boolean = false;

  // ------------------------------------------------------------- lifecycle

  aboutToAppear(): void {
    Settings.refreshDarkFlag();
    this.watchSystemTheme();
    const first: BrowserTab = new BrowserTab('');
    this.tabs.push(first);
    this.setActive(first);
    this.restoreSession();
    if (this.pendingUrl.length > 0) {
      this.onPendingUrl();
    }
  }

  aboutToDisappear(): void {
    this.saveSessionNow();
    if (this.queryListener !== undefined) {
      this.queryListener.off('change');
    }
  }

  private watchSystemTheme(): void {
    try {
      const listener: mediaquery.MediaQueryListener =
        this.getUIContext().getMediaQuery().matchMediaSync('(dark-mode: true)');
      Settings.setSystemDark(listener.matches);
      listener.on('change', (result: mediaquery.MediaQueryResult) => {
        Settings.setSystemDark(result.matches);
      });
      this.queryListener = listener;
    } catch (err) {
      Logger.warn('media query unavailable: ' + (err as BusinessError).message);
    }
  }

  onPendingUrl(): void {
    const url: string = this.pendingUrl;
    if (url.length === 0) {
      return;
    }
    this.pendingUrl = '';
    this.sessionApplied = true;
    this.openInNewTab(url, true);
  }

  onMemoryPressure(): void {
    if (this.memoryPressure === 0) {
      return;
    }
    let freed: number = 0;
    for (const tab of this.tabs) {
      if (tab.id !== this.activeId && tab.alive && !tab.sleeping) {
        tab.discard();
        freed++;
      }
    }
    if (freed > 0) {
      Logger.info('memory pressure: put ' + freed + ' tabs to sleep');
    }
  }

  onBackPress(): boolean {
    if (this.dialog !== undefined) {
      this.dialog.cancel();
      this.dialog = undefined;
      return true;
    }
    if (this.linkMenuUrl.length > 0) {
      this.linkMenuUrl = '';
      return true;
    }
    if (this.overlayKind !== OverlayKind.NONE) {
      this.overlayKind = OverlayKind.NONE;
      return true;
    }
    if (this.editing) {
      this.cancelEditing();
      return true;
    }
    if (this.findVisible) {
      this.closeFind();
      return true;
    }
    const tab: BrowserTab = this.activeTab();
    if (tab.back()) {
      return true;
    }
    if (!tab.isHome) {
      tab.goHome();
      this.syncOmnibox();
      return true;
    }
    if (this.tabs.length > 1) {
      this.closeTab(tab.id);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------ tabs

  private activeTab(): BrowserTab {
    return this.activeTabRef;
  }

  /** Single place that moves the active marker, so @ObjectLink stays bound. */
  private setActive(tab: BrowserTab): void {
    this.activeTabRef = tab;
    this.activeId = tab.id;
  }

  private openInNewTab(url: string, foreground: boolean): void {
    const tab: BrowserTab = new BrowserTab(url);
    this.tabs.push(tab);
    if (foreground) {
      this.selectTab(tab.id);
    }
    this.enforceTabBudget();
    this.scheduleSessionSave();
  }

  private selectTab(id: number): void {
    for (const tab of this.tabs) {
      if (tab.id === id) {
        tab.revive();
        tab.lastUsed = new Date().getTime();
        this.setActive(tab);
        this.editing = false;
        this.findVisible = false;
        this.syncOmnibox();
        this.enforceTabBudget();
        this.refreshBookmarkState();
        this.scheduleSessionSave();
        return;
      }
    }
  }

  private closeTab(id: number): void {
    let index: number = -1;
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === id) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      return;
    }
    // Tearing down a Web component while its renderer is live blocks the UI
    // thread inside the engine, so the renderer goes first.
    this.tabs[index].prepareForClose();
    this.tabs.splice(index, 1);
    if (this.tabs.length === 0) {
      const fresh: BrowserTab = new BrowserTab('');
      this.tabs.push(fresh);
      this.setActive(fresh);
      this.syncOmnibox();
    } else if (this.activeId === id) {
      const next: number = index < this.tabs.length ? index : this.tabs.length - 1;
      this.selectTab(this.tabs[next].id);
    }
    this.scheduleSessionSave();
  }

  private closeAllTabs(): void {
    for (const tab of this.tabs) {
      tab.prepareForClose();
    }
    this.tabs = [];
    const fresh: BrowserTab = new BrowserTab('');
    this.tabs.push(fresh);
    this.setActive(fresh);
    this.overlayKind = OverlayKind.NONE;
    this.syncOmnibox();
    this.scheduleSessionSave();
  }

  /** Keep at most `maxLiveTabs` renderers alive, oldest first to sleep. */
  private enforceTabBudget(): void {
    const budget: number = Settings.number(SettingsKeys.MAX_LIVE_TABS, 6);
    const live: BrowserTab[] = [];
    for (const tab of this.tabs) {
      if (tab.alive && !tab.sleeping && !tab.isHome && tab.id !== this.activeId) {
        live.push(tab);
      }
    }
    if (live.length + 1 <= budget) {
      return;
    }
    live.sort((a: BrowserTab, b: BrowserTab) => a.lastUsed - b.lastUsed);
    const excess: number = live.length + 1 - budget;
    for (let i = 0; i < excess; i++) {
      live[i].discard();
    }
  }

  // ------------------------------------------------------------- omnibox

  private syncOmnibox(): void {
    const tab: BrowserTab = this.activeTab();
    this.omniText = tab.isHome ? '' : UrlUtils.pretty(tab.url);
  }

  private focusOmnibox(): void {
    this.editing = true;
    this.updateSuggestions('');
    try {
      this.getUIContext().getFocusController().requestFocus(OMNIBOX_ID);
    } catch (err) {
      Logger.warn('focus omnibox: ' + (err as BusinessError).message);
    }
  }

  private cancelEditing(): void {
    this.editing = false;
    this.suggestions = [];
    this.syncOmnibox();
  }

  private navigate(text: string): void {
    const target: string = UrlUtils.toNavigationUrl(text, Settings.engine());
    if (target.length === 0) {
      return;
    }
    const tab: BrowserTab = this.activeTab();
    tab.lastUsed = new Date().getTime();
    tab.navigate(target);
    this.editing = false;
    this.suggestions = [];
    this.omniText = UrlUtils.pretty(target);
    this.enforceTabBudget();
    this.refreshBookmarkState();
    this.scheduleSessionSave();
  }

  private updateSuggestions(query: string): void {
    const trimmed: string = query.trim();
    if (trimmed.length === 0) {
      BrowserStore.recentHistory(8).then((rows: HistoryEntry[]) => {
        if (this.editing) {
          this.suggestions = rows.map((entry: HistoryEntry) => new Suggestion(SuggestionKind.HISTORY,
            entry.title.length > 0 ? entry.title : UrlUtils.shortHost(entry.url),
            UrlUtils.pretty(entry.url), entry.url));
        }
      });
      return;
    }
    const head: Suggestion[] = [];
    if (UrlUtils.looksLikeUrl(trimmed)) {
      head.push(new Suggestion(SuggestionKind.DIRECT, trimmed, 'Open this address',
        UrlUtils.toNavigationUrl(trimmed, Settings.engine())));
    }
    head.push(new Suggestion(SuggestionKind.SEARCH, trimmed, 'Search with ' + Settings.engine().name,
      Settings.engine().queryUrl + encodeURIComponent(trimmed)));
    this.suggestions = head;
    BrowserStore.searchHistory(trimmed, 6).then((rows: HistoryEntry[]) => {
      if (!this.editing) {
        return;
      }
      const merged: Suggestion[] = head.slice();
      for (const entry of rows) {
        merged.push(new Suggestion(SuggestionKind.HISTORY,
          entry.title.length > 0 ? entry.title : UrlUtils.shortHost(entry.url),
          UrlUtils.pretty(entry.url), entry.url));
      }
      this.suggestions = merged;
    });
  }

  // ------------------------------------------------------- bookmarks/toast

  private refreshBookmarkState(): void {
    const tab: BrowserTab = this.activeTab();
    if (tab.isHome || tab.url.length === 0) {
      this.bookmarked = false;
      return;
    }
    BrowserStore.isBookmarked(tab.url).then((exists: boolean) => {
      this.bookmarked = exists;
    });
  }

  private toggleBookmark(): void {
    const tab: BrowserTab = this.activeTab();
    if (tab.isHome || tab.url.length === 0) {
      this.showToast('Nothing to bookmark');
      return;
    }
    const url: string = tab.url;
    const title: string = tab.label();
    BrowserStore.isBookmarked(url).then((exists: boolean) => {
      if (exists) {
        BrowserStore.removeBookmark(url).then(() => {
          this.bookmarked = false;
          this.showToast('Bookmark removed');
        });
      } else {
        BrowserStore.addBookmark(url, title).then(() => {
          this.bookmarked = true;
          this.showToast('Bookmarked');
        });
      }
    });
  }

  private showToast(message: string): void {
    this.toastMessage = message;
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toastMessage = '';
      this.toastTimer = -1;
    }, 2200);
  }

  // ----------------------------------------------------------- find in page

  private runFind(text: string): void {
    const tab: BrowserTab = this.activeTab();
    if (!tab.attached) {
      return;
    }
    try {
      if (text.length === 0) {
        tab.controller.clearMatches();
        tab.matchCount = 0;
        tab.matchIndex = 0;
      } else {
        tab.matchIndex = 0;
        tab.controller.searchAllAsync(text);
      }
    } catch (err) {
      Logger.warn('find: ' + (err as BusinessError).message);
    }
  }

  private findNext(forward: boolean): void {
    const tab: BrowserTab = this.activeTab();
    if (!tab.attached) {
      return;
    }
    try {
      tab.controller.searchNext(forward);
      if (tab.matchCount > 0) {
        if (forward) {
          tab.matchIndex = tab.matchIndex >= tab.matchCount ? 1 : tab.matchIndex + 1;
        } else {
          tab.matchIndex = tab.matchIndex <= 1 ? tab.matchCount : tab.matchIndex - 1;
        }
      }
    } catch (err) {
      Logger.warn('find next: ' + (err as BusinessError).message);
    }
  }

  private closeFind(): void {
    const tab: BrowserTab = this.activeTab();
    this.findVisible = false;
    if (tab.attached) {
      try {
        tab.controller.clearMatches();
      } catch (err) {
        Logger.warn('clear matches: ' + (err as BusinessError).message);
      }
    }
    tab.matchCount = 0;
    tab.matchIndex = 0;
  }

  // --------------------------------------------------------------- session

  private restoreSession(): void {
    if (!Settings.bool(SettingsKeys.RESTORE, true)) {
      return;
    }
    BrowserStore.loadSession().then((record: SessionRecord | undefined) => {
      if (record === undefined || this.sessionApplied) {
        return;
      }
      const restored: BrowserTab[] = [];
      for (const item of record.tabs) {
        if (item.url.length > 0) {
          restored.push(BrowserTab.restored(item.url, item.title));
        }
      }
      if (restored.length === 0) {
        return;
      }
      this.sessionApplied = true;
      this.tabs = restored;
      let index: number = record.activeIndex;
      if (index < 0 || index >= restored.length) {
        index = 0;
      }
      this.selectTab(restored[index].id);
      Logger.info('restored ' + restored.length + ' tabs');
    });
  }

  private scheduleSessionSave(): void {
    if (this.sessionTimer >= 0) {
      clearTimeout(this.sessionTimer);
    }
    this.sessionTimer = setTimeout(() => {
      this.sessionTimer = -1;
      this.saveSessionNow();
    }, 1200);
  }

  private saveSessionNow(): void {
    const items: SessionTabRecord[] = [];
    let activeIndex: number = 0;
    for (const tab of this.tabs) {
      if (tab.isHome || tab.url.length === 0) {
        continue;
      }
      if (tab.id === this.activeId) {
        activeIndex = items.length;
      }
      items.push({ url: tab.url, title: tab.label() });
    }
    const record: SessionRecord = { tabs: items, activeIndex: activeIndex };
    BrowserStore.saveSession(record);
  }

  // ------------------------------------------------------------------ view

  build() {
    Stack() {
      Column() {
        TopBar({
          tab: this.activeTab(),
          omniText: this.omniText,
          editing: this.editing,
          onGo: (text: string): void => {
            this.navigate(text);
          },
          onTextChanged: (text: string): void => {
            this.updateSuggestions(text);
          },
          onEditingStart: (): void => {
            // Editing works on the real URL, not the shortened display form.
            const tab: BrowserTab = this.activeTab();
            if (!tab.isHome && tab.url.length > 0) {
              this.omniText = tab.url;
            }
            this.updateSuggestions(this.omniText);
          },
          onCancelEdit: (): void => {
            this.cancelEditing();
          },
          onStopOrReload: (): void => {
            const tab: BrowserTab = this.activeTab();
            if (tab.loading) {
              tab.stop();
            } else if (tab.isHome) {
              this.focusOmnibox();
            } else {
              tab.reload();
            }
          }
        })

        if (this.findVisible) {
          FindBar({
            tab: this.activeTab(),
            onSearch: (text: string): void => {
              this.runFind(text);
            },
            onNext: (forward: boolean): void => {
              this.findNext(forward);
            },
            onClose: (): void => {
              this.closeFind();
            }
          })
        }

        Stack() {
          ForEach(this.tabs, (tab: BrowserTab) => {
            Column() {
              WebTabView({
                tab: tab,
                active: tab.id === this.activeId,
                onVisit: (url: string, title: string): void => {
                  BrowserStore.addVisit(url, title);
                  if (tab.id === this.activeId && !this.editing) {
                    this.omniText = UrlUtils.pretty(url);
                    this.refreshBookmarkState();
                  }
                  this.scheduleSessionSave();
                },
                onDialog: (request: DialogRequest): void => {
                  if (tab.id === this.activeId) {
                    this.dialog = request;
                  } else {
                    request.cancel();
                  }
                },
                onToast: (message: string): void => {
                  this.showToast(message);
                },
                onOfferGallerySave: (target: DownloadTarget): void => {
                  this.pendingGallerySave = target;
                },
                onNewWindow: (targetUrl: string): webview.WebviewController => {
                  const popup: BrowserTab = new BrowserTab('');
                  popup.isHome = false;
                  popup.alive = true;
                  popup.initialUrl = 'about:blank';
                  popup.url = targetUrl;
                  popup.title = UrlUtils.shortHost(targetUrl);
                  this.tabs.push(popup);
                  this.setActive(popup);
                  this.omniText = UrlUtils.pretty(targetUrl);
                  this.enforceTabBudget();
                  return popup.controller;
                },
                onWindowExit: (tabId: number): void => {
                  this.closeTab(tabId);
                },
                onActivateRequest: (tabId: number): void => {
                  this.selectTab(tabId);
                },
                onLinkMenu: (linkUrl: string): void => {
                  if (tab.id === this.activeId) {
                    this.linkMenuUrl = linkUrl;
                  }
                }
              })
            }
            .width('100%')
            .height('100%')
            .visibility(tab.id === this.activeId ? Visibility.Visible : Visibility.Hidden)
          }, (tab: BrowserTab) => tab.id.toString())

          if (this.activeTab().isHome) {
            HomeView({
              onOpen: (url: string): void => {
                this.navigate(url);
              },
              onFocusOmnibox: (): void => {
                this.focusOmnibox();
              }
            })
          }

          if (this.editing) {
            SuggestionList({
              suggestions: this.suggestions,
              onPick: (suggestion: Suggestion): void => {
                this.navigate(suggestion.target);
              }
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignContent(Alignment.TopStart)

        BottomBar({
          tab: this.activeTab(),
          tabCount: this.tabs.length,
          onBack: (): void => {
            const tab: BrowserTab = this.activeTab();
            if (!tab.back() && !tab.isHome) {
              tab.goHome();
              this.syncOmnibox();
            }
          },
          onForward: (): void => {
            this.activeTab().forward();
          },
          onHome: (): void => {
            this.activeTab().goHome();
            this.syncOmnibox();
          },
          onTabs: (): void => {
            this.captureThumbnail();
            this.overlayKind = OverlayKind.TABS;
          },
          onMenu: (): void => {
            this.refreshBookmarkState();
            this.overlayKind = OverlayKind.MENU;
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.of(this.isDark).bg)

      if (this.overlayKind === OverlayKind.TABS) {
        TabSwitcher({
          tabs: this.tabs,
          activeId: this.activeId,
          onSelect: (id: number): void => {
            this.selectTab(id);
            this.overlayKind = OverlayKind.NONE;
          },
          onCloseTab: (id: number): void => {
            this.closeTab(id);
          },
          onNewTab: (): void => {
            this.openInNewTab('', true);
            this.overlayKind = OverlayKind.NONE;
            this.focusOmnibox();
          },
          onCloseAll: (): void => {
            this.closeAllTabs();
          },
          onDismiss: (): void => {
            this.overlayKind = OverlayKind.NONE;
          }
        })
      }

      if (this.overlayKind === OverlayKind.BOOKMARKS) {
        BookmarksView({
          onOpen: (url: string): void => {
            this.overlayKind = OverlayKind.NONE;
            this.navigate(url);
          },
          onClose: (): void => {
            this.overlayKind = OverlayKind.NONE;
          }
        })
      }

      if (this.overlayKind === OverlayKind.HISTORY) {
        HistoryView({
          onOpen: (url: string): void => {
            this.overlayKind = OverlayKind.NONE;
            this.navigate(url);
          },
          onClose: (): void => {
            this.overlayKind = OverlayKind.NONE;
          }
        })
      }

      if (this.overlayKind === OverlayKind.SETTINGS) {
        SettingsView({
          onClose: (): void => {
            this.overlayKind = OverlayKind.NONE;
          },
          onToast: (message: string): void => {
            this.showToast(message);
          }
        })
      }

      if (this.overlayKind === OverlayKind.MENU) {
        MenuSheet({
          bookmarked: this.bookmarked,
          canClose: this.tabs.length > 1,
          onDismiss: (): void => {
            this.overlayKind = OverlayKind.NONE;
          },
          onNewTab: (): void => {
            this.overlayKind = OverlayKind.NONE;
            this.openInNewTab('', true);
            this.focusOmnibox();
          },
          onToggleBookmark: (): void => {
            this.overlayKind = OverlayKind.NONE;
            this.toggleBookmark();
          },
          onBookmarks: (): void => {
            this.overlayKind = OverlayKind.BOOKMARKS;
          },
          onHistory: (): void => {
            this.overlayKind = OverlayKind.HISTORY;
          },
          onFind: (): void => {
            this.overlayKind = OverlayKind.NONE;
            this.findVisible = true;
          },
          onToggleDesktop: (): void => {
            this.overlayKind = OverlayKind.NONE;
            const next: boolean = !Settings.bool(SettingsKeys.DESKTOP, false);
            Settings.setBool(SettingsKeys.DESKTOP, next);
            this.showToast(next ? 'Desktop site' : 'Mobile site');
          },
          onSettings: (): void => {
            this.overlayKind = OverlayKind.SETTINGS;
          },
          onCloseTab: (): void => {
            this.overlayKind = OverlayKind.NONE;
            this.closeTab(this.activeId);
          }
        })
      }

      if (this.linkMenuUrl.length > 0) {
        LinkMenu({
          url: this.linkMenuUrl,
          onOpen: (): void => {
            const target: string = this.linkMenuUrl;
            this.linkMenuUrl = '';
            this.navigate(target);
          },
          onOpenNewTab: (): void => {
            const target: string = this.linkMenuUrl;
            this.linkMenuUrl = '';
            this.openInNewTab(target, false);
            this.showToast('Opened in a new tab');
          },
          onCopy: (): void => {
            const target: string = this.linkMenuUrl;
            this.linkMenuUrl = '';
            this.copyToClipboard(target);
          },
          onDismiss: (): void => {
            this.linkMenuUrl = '';
          }
        })
      }

      if (this.dialog !== undefined) {
        DialogHost({
          request: this.dialog,
          onDone: (): void => {
            this.dialog = undefined;
          }
        })
      }

      // Held back while a sheet, dialog or the omnibox is up, so it never sits on top of one.
      if (this.pendingGallerySave !== undefined && this.overlayKind === OverlayKind.NONE &&
        this.dialog === undefined && !this.editing) {
        Column() {
          SaveToGalleryBar({
            target: this.pendingGallerySave,
            onDone: (message: string): void => {
              this.pendingGallerySave = undefined;
              this.showToast(message);
            },
            onDismiss: (): void => {
              this.pendingGallerySave = undefined;
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .padding({ left: 12, right: 12, bottom: 78 })
        // Only the bar itself should take taps; the page stays usable behind it.
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.toastMessage.length > 0) {
        Column() {
          Toast({ message: this.toastMessage })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .padding({ bottom: 90 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
  }

  private copyToClipboard(text: string): void {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.showToast('Link copied');
      }).catch((err: BusinessError) => {
        Logger.warn('clipboard: ' + err.message);
      });
    } catch (err) {
      Logger.warn('clipboard: ' + (err as BusinessError).message);
    }
  }

  /** Grab a preview of the active tab so the switcher has something to show. */
  private captureThumbnail(): void {
    const tab: BrowserTab = this.activeTab();
    if (!tab.alive || !tab.attached || tab.isHome || tab.sleeping) {
      return;
    }
    try {
      tab.controller.webPageSnapshot({ id: 'tab' + tab.id, size: { width: 320, height: 420 } },
        (error: BusinessError, result: webview.SnapshotResult) => {
          if (error !== undefined && error !== null) {
            return;
          }
          if (result !== undefined && result.imagePixelMap !== undefined) {
            tab.thumbnail = result.imagePixelMap;
          }
        });
    } catch (err) {
      Logger.warn('snapshot: ' + (err as BusinessError).message);
    }
  }
}
