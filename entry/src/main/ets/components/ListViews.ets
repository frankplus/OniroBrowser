/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * The history and bookmark overlays.
 */
import { BookmarkEntry, HistoryEntry } from '../common/Types';
import { BrowserStore } from '../model/BrowserStore';
import { SettingsKeys } from '../model/Settings';
import { Theme } from '../common/Theme';
import { Format } from '../common/Format';
import { UrlUtils } from '../common/UrlUtils';
import { OverlayHeader, SiteRow } from './Chrome';

@Component
export struct HistoryView {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @State entries: HistoryEntry[] = [];
  @State query: string = '';
  onOpen: (url: string) => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    if (this.query.length > 0) {
      BrowserStore.searchHistory(this.query, 200).then((rows: HistoryEntry[]) => {
        this.entries = rows;
      });
    } else {
      BrowserStore.recentHistory(200).then((rows: HistoryEntry[]) => {
        this.entries = rows;
      });
    }
  }

  build() {
    Column() {
      OverlayHeader({
        title: 'History',
        actionIcon: $r('app.media.ic_delete'),
        onClose: (): void => {
          this.onClose();
        },
        onAction: (): void => {
          BrowserStore.clearHistory().then(() => {
            this.reload();
          });
        }
      })

      TextInput({ text: this.query, placeholder: 'Search history' })
        .height(38)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor(Theme.of(this.isDark).surfaceAlt)
        .fontColor(Theme.of(this.isDark).text)
        .placeholderColor(Theme.of(this.isDark).textDim)
        .borderRadius(19)
        .onChange((value: string) => {
          this.query = value;
          this.reload();
        })

      if (this.entries.length === 0) {
        Column() {
          Text('Nothing here yet')
            .fontSize(14)
            .fontColor(Theme.of(this.isDark).textDim)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.entries, (entry: HistoryEntry) => {
            ListItem() {
              SiteRow({
                title: entry.title.length > 0 ? entry.title : UrlUtils.shortHost(entry.url),
                subtitle: UrlUtils.shortHost(entry.url) + '  ·  ' + Format.timestamp(entry.visitTime),
                url: entry.url,
                icon: $r('app.media.ic_history'),
                trailingIcon: $r('app.media.ic_close'),
                onTap: (): void => {
                  this.onOpen(entry.url);
                },
                onTrailing: (): void => {
                  BrowserStore.deleteHistory(entry.id).then(() => {
                    this.reload();
                  });
                }
              })
            }
          }, (entry: HistoryEntry) => entry.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.of(this.isDark).bg)
  }
}

@Component
export struct BookmarksView {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @State entries: BookmarkEntry[] = [];
  onOpen: (url: string) => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    BrowserStore.bookmarks().then((rows: BookmarkEntry[]) => {
      this.entries = rows;
    });
  }

  build() {
    Column() {
      OverlayHeader({
        title: 'Bookmarks',
        onClose: (): void => {
          this.onClose();
        }
      })

      if (this.entries.length === 0) {
        Column({ space: 8 }) {
          Image($r('app.media.ic_star_outline'))
            .width(32)
            .height(32)
            .fillColor(Theme.of(this.isDark).border)
          Text('No bookmarks yet')
            .fontSize(14)
            .fontColor(Theme.of(this.isDark).textDim)
          Text('Star a page from the menu to keep it here')
            .fontSize(12)
            .fontColor(Theme.of(this.isDark).textDim)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.entries, (entry: BookmarkEntry) => {
            ListItem() {
              SiteRow({
                title: entry.title,
                subtitle: UrlUtils.pretty(entry.url),
                url: entry.url,
                icon: $r('app.media.ic_bookmarks'),
                trailingIcon: $r('app.media.ic_delete'),
                onTap: (): void => {
                  this.onOpen(entry.url);
                },
                onTrailing: (): void => {
                  BrowserStore.removeBookmark(entry.url).then(() => {
                    this.reload();
                  });
                }
              })
            }
          }, (entry: BookmarkEntry) => entry.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.of(this.isDark).bg)
  }
}
