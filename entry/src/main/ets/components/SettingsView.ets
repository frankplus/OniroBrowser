/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { SEARCH_ENGINES, SearchEngine } from '../common/Types';
import { BrowserStore } from '../model/BrowserStore';
import { Settings, SettingsKeys } from '../model/Settings';
import { Theme } from '../common/Theme';
import { Logger } from '../common/Logger';
import { OverlayHeader } from './Chrome';

@Component
export struct SettingsView {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @StorageLink(SettingsKeys.ENGINE) engineIndex: number = 0;
  @StorageLink(SettingsKeys.THEME) themeMode: number = 0;
  @StorageLink(SettingsKeys.JS) jsEnabled: boolean = true;
  @StorageLink(SettingsKeys.DESKTOP) desktopMode: boolean = false;
  @StorageLink(SettingsKeys.RESTORE) restoreSession: boolean = true;
  @StorageLink(SettingsKeys.THIRD_PARTY_COOKIES) thirdPartyCookies: boolean = false;
  @StorageLink(SettingsKeys.TEXT_ZOOM) textZoom: number = 100;
  @StorageLink(SettingsKeys.MAX_LIVE_TABS) maxLiveTabs: number = 6;
  @State userAgent: string = '';
  onClose: () => void = () => {};
  onToast: (message: string) => void = () => {};

  aboutToAppear(): void {
    try {
      this.userAgent = webview.WebviewController.getDefaultUserAgent();
    } catch (err) {
      Logger.warn('user agent unavailable: ' + (err as BusinessError).message);
    }
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.of(this.isDark).textDim)
      .width('100%')
      .padding({ left: 4, top: 18, bottom: 8 })
  }

  @Builder
  actionRow(title: string, tint: string, action: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(tint)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      OverlayHeader({
        title: 'Settings',
        onClose: (): void => {
          this.onClose();
        }
      })

      Scroll() {
        Column() {
          this.sectionTitle('Search engine')
          Column() {
            ForEach(SEARCH_ENGINES, (engine: SearchEngine, index: number) => {
              Row() {
                Text(engine.name)
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .layoutWeight(1)
                Radio({ value: engine.name, group: 'engine' })
                  .checked(this.engineIndex === index)
                  .radioStyle({ checkedBackgroundColor: Theme.of(this.isDark).accent })
                  .onClick(() => {
                    Settings.setEngineIndex(index);
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .onClick(() => {
                Settings.setEngineIndex(index);
              })
            }, (engine: SearchEngine) => engine.name)
          }
          .width('100%')
          .backgroundColor(Theme.of(this.isDark).surface)
          .borderRadius(14)

          this.sectionTitle('Appearance')
          Column() {
            Row() {
              Text('Theme')
                .fontSize(15)
                .fontColor(Theme.of(this.isDark).text)
                .layoutWeight(1)
              Select([{ value: 'System' }, { value: 'Light' }, { value: 'Dark' }])
                .selected(this.themeMode)
                .value(this.themeMode === 0 ? 'System' : (this.themeMode === 1 ? 'Light' : 'Dark'))
                .font({ size: 14 })
                .fontColor(Theme.of(this.isDark).text)
                .backgroundColor(Theme.of(this.isDark).surfaceAlt)
                .optionBgColor(Theme.of(this.isDark).surface)
                .optionFontColor(Theme.of(this.isDark).text)
                .selectedOptionBgColor(Theme.of(this.isDark).accentDim)
                .selectedOptionFontColor(Theme.of(this.isDark).accent)
                .onSelect((index: number) => {
                  Settings.setNumber(SettingsKeys.THEME, index);
                  Settings.refreshDarkFlag();
                })
            }
            .width('100%')
            .padding({ left: 14, right: 6, top: 6, bottom: 6 })

            Row() {
              Column({ space: 2 }) {
                Text('Text size')
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .width('100%')
                Text(this.textZoom + '%')
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .width('100%')
              }
              .width(110)
              .alignItems(HorizontalAlign.Start)

              Slider({ value: this.textZoom, min: 70, max: 200, step: 10, style: SliderStyle.OutSet })
                .layoutWeight(1)
                .selectedColor(Theme.of(this.isDark).accent)
                .onChange((value: number) => {
                  Settings.setNumber(SettingsKeys.TEXT_ZOOM, Math.round(value));
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 6, bottom: 10 })
          }
          .width('100%')
          .backgroundColor(Theme.of(this.isDark).surface)
          .borderRadius(14)

          this.sectionTitle('Browsing')
          Column() {
            // Written out inline: a @Builder taking the value would keep
            // showing the switch position captured at first build.
            Row() {
              Column({ space: 2 }) {
                Text('JavaScript')
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .width('100%')
                Text('Disable to load pages without scripts')
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.jsEnabled })
                .selectedColor(Theme.of(this.isDark).accent)
                .onChange((on: boolean) => {
                  Settings.setBool(SettingsKeys.JS, on);
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })

            Row() {
              Column({ space: 2 }) {
                Text('Desktop site')
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .width('100%')
                Text('Send a desktop user agent')
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.desktopMode })
                .selectedColor(Theme.of(this.isDark).accent)
                .onChange((on: boolean) => {
                  Settings.setBool(SettingsKeys.DESKTOP, on);
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })

            Row() {
              Text('Restore tabs on launch')
                .fontSize(15)
                .fontColor(Theme.of(this.isDark).text)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.restoreSession })
                .selectedColor(Theme.of(this.isDark).accent)
                .onChange((on: boolean) => {
                  Settings.setBool(SettingsKeys.RESTORE, on);
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })

            Row() {
              Column({ space: 2 }) {
                Text('Allow third-party cookies')
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .width('100%')
                Text('Off keeps cross-site trackers out')
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.thirdPartyCookies })
                .selectedColor(Theme.of(this.isDark).accent)
                .onChange((on: boolean) => {
                  Settings.setBool(SettingsKeys.THIRD_PARTY_COOKIES, on);
                  try {
                    webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(on);
                  } catch (err) {
                    Logger.warn('cookie policy: ' + (err as BusinessError).message);
                  }
                })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            Row() {
              Column({ space: 2 }) {
                Text('Tabs kept in memory')
                  .fontSize(15)
                  .fontColor(Theme.of(this.isDark).text)
                  .width('100%')
                Text('Older tabs sleep and reload when reopened')
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Counter() {
                Text(this.maxLiveTabs.toString())
                  .fontSize(14)
                  .fontColor(Theme.of(this.isDark).text)
              }
              .onInc(() => {
                if (this.maxLiveTabs < 12) {
                  Settings.setNumber(SettingsKeys.MAX_LIVE_TABS, this.maxLiveTabs + 1);
                }
              })
              .onDec(() => {
                if (this.maxLiveTabs > 2) {
                  Settings.setNumber(SettingsKeys.MAX_LIVE_TABS, this.maxLiveTabs - 1);
                }
              })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 10, bottom: 12 })
          }
          .width('100%')
          .backgroundColor(Theme.of(this.isDark).surface)
          .borderRadius(14)

          this.sectionTitle('Privacy')
          Column() {
            this.actionRow('Clear browsing history', Theme.of(this.isDark).text, (): void => {
              BrowserStore.clearHistory().then(() => {
                this.onToast('History cleared');
              });
            })
            this.actionRow('Clear cookies', Theme.of(this.isDark).text, (): void => {
              try {
                webview.WebCookieManager.clearAllCookiesSync();
                this.onToast('Cookies cleared');
              } catch (err) {
                Logger.warn('clear cookies: ' + (err as BusinessError).message);
              }
            })
            this.actionRow('Clear cache and site data', Theme.of(this.isDark).danger, (): void => {
              try {
                webview.WebviewController.removeAllCache(true);
                webview.WebStorage.deleteAllData();
                this.onToast('Cache cleared');
              } catch (err) {
                Logger.warn('clear cache: ' + (err as BusinessError).message);
              }
            })
          }
          .width('100%')
          .backgroundColor(Theme.of(this.isDark).surface)
          .borderRadius(14)

          this.sectionTitle('About')
          Column({ space: 6 }) {
            Text('Oniro Browser 1.0')
              .fontSize(14)
              .fontColor(Theme.of(this.isDark).text)
              .width('100%')
            Text('ArkWeb engine')
              .fontSize(12)
              .fontColor(Theme.of(this.isDark).textDim)
              .width('100%')
            Text(this.userAgent)
              .fontSize(11)
              .fontColor(Theme.of(this.isDark).textDim)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.of(this.isDark).surface)
          .borderRadius(14)

          Blank().height(28)
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.of(this.isDark).bg)
  }
}
