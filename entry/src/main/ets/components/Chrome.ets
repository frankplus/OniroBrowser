/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Browser chrome: the omnibox row on top and the navigation bar at the bottom.
 */
import { BrowserTab } from '../model/BrowserTab';
import { SettingsKeys } from '../model/Settings';
import { Metrics, Palette, Theme } from '../common/Theme';
import { UrlUtils } from '../common/UrlUtils';

/** Focus id of the omnibox, so the shell can raise the keyboard on demand. */
export const OMNIBOX_ID: string = 'omniboxInput';

@Component
export struct TopBar {
  @ObjectLink tab: BrowserTab;
  @Link omniText: string;
  @Link @Watch('onEditingChanged') editing: boolean;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  onGo: (text: string) => void = () => {};
  onTextChanged: (text: string) => void = () => {};
  onEditingStart: () => void = () => {};
  onCancelEdit: () => void = () => {};
  onStopOrReload: () => void = () => {};
  private inputController: TextInputController = new TextInputController();

  /** Dropping out of edit mode also dismisses the soft keyboard. */
  onEditingChanged(): void {
    if (!this.editing) {
      this.inputController.stopEditing();
    }
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        Row({ space: 6 }) {
          Image(this.editing ? $r('app.media.ic_search') :
            (this.tab.secure && this.tab.errorText.length === 0 ? $r('app.media.ic_lock') :
              $r('app.media.ic_globe')))
            .width(15)
            .height(15)
            .fillColor(this.tab.secure && this.tab.errorText.length === 0 && !this.editing ? '#1E8E3E' :
              Theme.of(this.isDark).textDim)
            .margin({ left: 12 })

          TextInput({ text: this.omniText, placeholder: 'Search or enter address',
            controller: this.inputController })
            .id(OMNIBOX_ID)
            .layoutWeight(1)
            .height(38)
            .padding({ left: 2, right: 4 })
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).text)
            .placeholderColor(Theme.of(this.isDark).textDim)
            .caretColor(Theme.of(this.isDark).accent)
            .enterKeyType(EnterKeyType.Go)
            .selectAll(true)
            .maxLines(1)
            .onFocus(() => {
              this.editing = true;
              this.onEditingStart();
            })
            .onChange((value: string) => {
              this.omniText = value;
              this.onTextChanged(value);
            })
            .onSubmit(() => {
              this.onGo(this.omniText);
            })

          if (this.editing && this.omniText.length > 0) {
            Image($r('app.media.ic_close'))
              .width(16)
              .height(16)
              .fillColor(Theme.of(this.isDark).textDim)
              .margin({ right: 10 })
              .onClick(() => {
                this.omniText = '';
                this.onTextChanged('');
              })
          }
        }
        .layoutWeight(1)
        .height(38)
        .backgroundColor(Theme.of(this.isDark).surfaceAlt)
        .borderRadius(19)

        if (this.editing) {
          Text('Cancel')
            .fontSize(14)
            .fontColor(Theme.of(this.isDark).accent)
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.onCancelEdit();
            })
        } else {
          Image(this.tab.loading ? $r('app.media.ic_close') : $r('app.media.ic_reload'))
            .width(Metrics.ICON)
            .height(Metrics.ICON)
            .fillColor(Theme.of(this.isDark).text)
            .onClick(() => {
              this.onStopOrReload();
            })
        }
      }
      .width('100%')
      .height(Metrics.CHROME_HEIGHT)
      .padding({ left: 10, right: 14 })
      .alignItems(VerticalAlign.Center)

      // Load progress, drawn as a hairline under the omnibox.
      Row() {
        Row()
          .width(this.tab.progress + '%')
          .height(2)
          .backgroundColor(Theme.of(this.isDark).accent)
      }
      .width('100%')
      .height(2)
      .justifyContent(FlexAlign.Start)
      .visibility(this.tab.loading && this.tab.progress < 100 ? Visibility.Visible : Visibility.Hidden)
    }
    .width('100%')
    .backgroundColor(Theme.of(this.isDark).chrome)
  }
}

@Component
export struct BottomBar {
  @ObjectLink tab: BrowserTab;
  @Prop tabCount: number;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  onBack: () => void = () => {};
  onForward: () => void = () => {};
  onHome: () => void = () => {};
  onTabs: () => void = () => {};
  onMenu: () => void = () => {};

  build() {
    // Every button is written out inline: a @Builder with value parameters
    // would not be re-evaluated when the observed tab state changes.
    Row() {
      Row() {
        Image($r('app.media.ic_back'))
          .width(Metrics.ICON)
          .height(Metrics.ICON)
          .fillColor(this.tab.canBack || !this.tab.isHome ? Theme.of(this.isDark).text :
            Theme.of(this.isDark).border)
      }
      .layoutWeight(1)
      .height(Metrics.TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.tab.canBack || !this.tab.isHome) {
          this.onBack();
        }
      })

      Row() {
        Image($r('app.media.ic_forward'))
          .width(Metrics.ICON)
          .height(Metrics.ICON)
          .fillColor(this.tab.canForward ? Theme.of(this.isDark).text : Theme.of(this.isDark).border)
      }
      .layoutWeight(1)
      .height(Metrics.TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.tab.canForward) {
          this.onForward();
        }
      })

      Row() {
        Image($r('app.media.ic_home'))
          .width(Metrics.ICON)
          .height(Metrics.ICON)
          .fillColor(this.tab.isHome ? Theme.of(this.isDark).accent : Theme.of(this.isDark).text)
      }
      .layoutWeight(1)
      .height(Metrics.TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onHome();
      })

      Row() {
        Stack() {
          Text(this.tabCount > 99 ? '99' : this.tabCount.toString())
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.of(this.isDark).text)
        }
        .width(23)
        .height(23)
        .borderRadius(7)
        .border({ width: 2, color: Theme.of(this.isDark).text })
      }
      .layoutWeight(1)
      .height(Metrics.TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onTabs();
      })

      Row() {
        Image($r('app.media.ic_menu'))
          .width(Metrics.ICON)
          .height(Metrics.ICON)
          .fillColor(Theme.of(this.isDark).text)
      }
      .layoutWeight(1)
      .height(Metrics.TOOLBAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onMenu();
      })
    }
    .width('100%')
    .height(Metrics.TOOLBAR_HEIGHT)
    .backgroundColor(Theme.of(this.isDark).chrome)
    .border({ width: { top: 0.5 }, color: Theme.of(this.isDark).border })
  }
}

/** Shared list-row look for history, bookmarks and suggestions. */
@Component
export struct SiteRow {
  @Prop title: string;
  @Prop subtitle: string;
  @Prop url: string;
  @Prop icon: Resource;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  trailingIcon: Resource | undefined = undefined;
  onTap: () => void = () => {};
  onTrailing: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Stack() {
        Text(UrlUtils.initial(this.url, this.title))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(34)
      .height(34)
      .borderRadius(10)
      .backgroundColor(UrlUtils.tint(this.url))

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(15)
          .fontColor(Theme.of(this.isDark).text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitle)
          .fontSize(12)
          .fontColor(Theme.of(this.isDark).textDim)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.trailingIcon !== undefined) {
        Image(this.trailingIcon)
          .width(18)
          .height(18)
          .fillColor(Theme.of(this.isDark).textDim)
          .onClick(() => {
            this.onTrailing();
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.onTap();
    })
  }
}

/** Title bar used by the full-screen overlay surfaces. */
@Component
export struct OverlayHeader {
  @Prop title: string;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  actionIcon: Resource | undefined = undefined;
  onClose: () => void = () => {};
  onAction: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_close'))
        .width(20)
        .height(20)
        .fillColor(Theme.of(this.isDark).text)
        .onClick(() => {
          this.onClose();
        })
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.of(this.isDark).text)
        .layoutWeight(1)
        .margin({ left: 14 })
      if (this.actionIcon !== undefined) {
        Image(this.actionIcon)
          .width(20)
          .height(20)
          .fillColor(Theme.of(this.isDark).textDim)
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .height(Metrics.CHROME_HEIGHT)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Theme.of(this.isDark).chrome)
  }
}

export class ChromeStyles {
  static palette(isDark: boolean): Palette {
    return Theme.of(isDark);
  }
}
