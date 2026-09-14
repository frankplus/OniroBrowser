/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * The new-tab surface: speed dial plus the most visited sites.
 */
import { DEFAULT_SPEED_DIAL, HistoryEntry, SpeedDialItem } from '../common/Types';
import { BrowserStore } from '../model/BrowserStore';
import { Settings, SettingsKeys } from '../model/Settings';
import { Theme } from '../common/Theme';
import { UrlUtils } from '../common/UrlUtils';

@Component
export struct HomeView {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @State topSites: HistoryEntry[] = [];
  private dial: SpeedDialItem[] = DEFAULT_SPEED_DIAL;
  onOpen: (url: string) => void = () => {};
  onFocusOmnibox: () => void = () => {};

  aboutToAppear(): void {
    this.refresh();
  }

  refresh(): void {
    BrowserStore.topSites(8).then((rows: HistoryEntry[]) => {
      this.topSites = rows;
    });
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 6 }) {
          Text('Oniro Browser')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.of(this.isDark).text)
          Text('Searching with ' + Settings.engine().name)
            .fontSize(13)
            .fontColor(Theme.of(this.isDark).textDim)
        }
        .margin({ top: 36 })

        Row({ space: 10 }) {
          Image($r('app.media.ic_search'))
            .width(18)
            .height(18)
            .fillColor(Theme.of(this.isDark).textDim)
          Text('Search or enter address')
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).textDim)
            .layoutWeight(1)
        }
        .width('100%')
        .height(46)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Theme.of(this.isDark).surface)
        .borderRadius(23)
        .onClick(() => {
          this.onFocusOmnibox();
        })

        Grid() {
          ForEach(this.dial, (item: SpeedDialItem) => {
            GridItem() {
              Column({ space: 8 }) {
                Stack() {
                  Text(item.glyph)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                }
                .width(52)
                .height(52)
                .borderRadius(16)
                .backgroundColor(item.tint)

                Text(item.label)
                  .fontSize(11)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .onClick(() => {
                this.onOpen(item.url);
              })
            }
          }, (item: SpeedDialItem) => item.url)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .rowsGap(18)
        .columnsGap(8)
        .width('100%')
        .height(this.dial.length > 4 ? 190 : 96)

        if (this.topSites.length > 0) {
          Column({ space: 10 }) {
            Text('Frequently visited')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.of(this.isDark).textDim)
              .width('100%')

            Column() {
              ForEach(this.topSites, (entry: HistoryEntry) => {
                Row({ space: 12 }) {
                  Stack() {
                    Text(UrlUtils.initial(entry.url, entry.title))
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .width(30)
                  .height(30)
                  .borderRadius(9)
                  .backgroundColor(UrlUtils.tint(entry.url))

                  Column({ space: 2 }) {
                    Text(entry.title.length > 0 ? entry.title : UrlUtils.shortHost(entry.url))
                      .fontSize(14)
                      .fontColor(Theme.of(this.isDark).text)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(UrlUtils.shortHost(entry.url))
                      .fontSize(11)
                      .fontColor(Theme.of(this.isDark).textDim)
                      .maxLines(1)
                      .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(10)
                .onClick(() => {
                  this.onOpen(entry.url);
                })
              }, (entry: HistoryEntry) => entry.id.toString())
            }
            .width('100%')
            .backgroundColor(Theme.of(this.isDark).surface)
            .borderRadius(14)
            .padding({ top: 4, bottom: 4 })
          }
        }

        Blank().height(20)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.of(this.isDark).bg)
  }
}
