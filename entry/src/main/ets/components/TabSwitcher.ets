/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 */
import { BrowserTab } from '../model/BrowserTab';
import { SettingsKeys } from '../model/Settings';
import { Metrics, Theme } from '../common/Theme';
import { UrlUtils } from '../common/UrlUtils';

@Component
struct TabCard {
  @ObjectLink tab: BrowserTab;
  @Prop active: boolean;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  onSelect: (id: number) => void = () => {};
  onClose: (id: number) => void = () => {};

  build() {
    Column() {
      Row({ space: 8 }) {
        if (this.tab.favicon !== undefined) {
          Image(this.tab.favicon)
            .width(16)
            .height(16)
            .borderRadius(3)
        } else {
          Stack() {
            Text(UrlUtils.initial(this.tab.url, this.tab.title))
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(16)
          .height(16)
          .borderRadius(5)
          .backgroundColor(UrlUtils.tint(this.tab.url))
        }

        Text(this.tab.label())
          .fontSize(12)
          .fontColor(Theme.of(this.isDark).text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Image($r('app.media.ic_close'))
          .width(14)
          .height(14)
          .fillColor(Theme.of(this.isDark).textDim)
          .onClick(() => {
            this.onClose(this.tab.id);
          })
      }
      .width('100%')
      .height(34)
      .padding({ left: 10, right: 10 })

      Stack() {
        if (this.tab.thumbnail !== undefined) {
          Image(this.tab.thumbnail)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .alignSelf(ItemAlign.Start)
          if (this.tab.sleeping) {
            Column() {
              Text('sleeping')
                .fontSize(10)
                .fontColor(Theme.of(this.isDark).textDim)
                .backgroundColor(Theme.of(this.isDark).surface)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Start)
            .padding(8)
          }
        } else {
          Column({ space: 6 }) {
            Stack() {
              Text(UrlUtils.initial(this.tab.url, this.tab.title))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .width(48)
            .height(48)
            .borderRadius(15)
            .backgroundColor(UrlUtils.tint(this.tab.url))

            Text(this.tab.isHome ? 'New tab' : UrlUtils.shortHost(this.tab.url))
              .fontSize(11)
              .fontColor(Theme.of(this.isDark).textDim)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.tab.sleeping) {
              Text('sleeping')
                .fontSize(10)
                .fontColor(Theme.of(this.isDark).textDim)
                .backgroundColor(Theme.of(this.isDark).surfaceAlt)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .borderRadius(6)
            }
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(Theme.of(this.isDark).bg)
      .clip(true)
    }
    .width('100%')
    .height(210)
    .backgroundColor(Theme.of(this.isDark).surface)
    .borderRadius(Metrics.RADIUS)
    .clip(true)
    .border({
      width: this.active ? 2 : 0.5,
      color: this.active ? Theme.of(this.isDark).accent : Theme.of(this.isDark).border
    })
    .onClick(() => {
      this.onSelect(this.tab.id);
    })
  }
}

@Component
export struct TabSwitcher {
  @Link tabs: BrowserTab[];
  @Prop activeId: number;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  onSelect: (id: number) => void = () => {};
  onCloseTab: (id: number) => void = () => {};
  onNewTab: () => void = () => {};
  onCloseAll: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.tabs.length + (this.tabs.length === 1 ? ' tab' : ' tabs'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.of(this.isDark).text)
          .layoutWeight(1)
        Text('Close all')
          .fontSize(14)
          .fontColor(Theme.of(this.isDark).danger)
          .onClick(() => {
            this.onCloseAll();
          })
      }
      .width('100%')
      .height(Metrics.CHROME_HEIGHT)
      .padding({ left: 18, right: 18 })

      Scroll() {
        Grid() {
          ForEach(this.tabs, (tab: BrowserTab) => {
            GridItem() {
              TabCard({
                tab: tab,
                active: tab.id === this.activeId,
                onSelect: (id: number): void => {
                  this.onSelect(id);
                },
                onClose: (id: number): void => {
                  this.onCloseTab(id);
                }
              })
            }
          }, (tab: BrowserTab) => tab.id.toString())
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(12)
        .columnsGap(12)
        .width('100%')
        .height(Math.ceil(this.tabs.length / 2) * 222)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 14, right: 14 })
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Row() {
        Row({ space: 8 }) {
          Image($r('app.media.ic_add'))
            .width(20)
            .height(20)
            .fillColor(Theme.of(this.isDark).accent)
          Text('New tab')
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).accent)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onNewTab();
        })

        Text('Done')
          .fontSize(15)
          .fontColor(Theme.of(this.isDark).text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onDismiss();
          })
      }
      .width('100%')
      .height(Metrics.TOOLBAR_HEIGHT)
      .backgroundColor(Theme.of(this.isDark).chrome)
      .border({ width: { top: 0.5 }, color: Theme.of(this.isDark).border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.of(this.isDark).bg)
  }
}
