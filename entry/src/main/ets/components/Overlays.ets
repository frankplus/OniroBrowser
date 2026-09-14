/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * In-page overlays: the menu, engine dialogs, find-in-page, omnibox
 * suggestions and toasts. Everything is drawn inside the browser window so
 * the shell never depends on system sub-windows.
 */
import { Suggestion, SuggestionKind } from '../common/Types';
import { DialogKind, DialogRequest } from '../model/DialogRequest';
import { SettingsKeys } from '../model/Settings';
import { Metrics, Theme } from '../common/Theme';
import { BrowserTab } from '../model/BrowserTab';
import { DownloadKind, Downloads, DownloadTarget } from '../common/Downloads';

@Component
export struct MenuSheet {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @StorageProp(SettingsKeys.DESKTOP) desktopMode: boolean = false;
  @Prop bookmarked: boolean;
  @Prop canClose: boolean;
  onDismiss: () => void = () => {};
  onNewTab: () => void = () => {};
  onToggleBookmark: () => void = () => {};
  onBookmarks: () => void = () => {};
  onHistory: () => void = () => {};
  onFind: () => void = () => {};
  onToggleDesktop: () => void = () => {};
  onSettings: () => void = () => {};
  onCloseTab: () => void = () => {};

  @Builder
  quickAction(icon: Resource, label: string, tint: string, action: () => void) {
    Column({ space: 6 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(tint)
      Text(label)
        .fontSize(11)
        .fontColor(Theme.of(this.isDark).textDim)
    }
    .layoutWeight(1)
    .onClick(() => {
      action();
    })
  }

  @Builder
  menuRow(icon: Resource, label: string, tint: string, action: () => void) {
    Row({ space: 14 }) {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor(tint)
      Text(label)
        .fontSize(15)
        .fontColor(tint)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 13, bottom: 13 })
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Theme.of(this.isDark).scrim)
        .onClick(() => {
          this.onDismiss();
        })

      Column() {
        Row()
          .width(38)
          .height(4)
          .borderRadius(2)
          .backgroundColor(Theme.of(this.isDark).border)
          .margin({ top: 8, bottom: 10 })

        Row() {
          this.quickAction(this.bookmarked ? $r('app.media.ic_star') : $r('app.media.ic_star_outline'),
            this.bookmarked ? 'Saved' : 'Bookmark',
            this.bookmarked ? '#F5A524' : Theme.of(this.isDark).text, (): void => {
              this.onToggleBookmark();
            })
          this.quickAction($r('app.media.ic_search'), 'Find', Theme.of(this.isDark).text, (): void => {
            this.onFind();
          })
          this.quickAction($r('app.media.ic_desktop'), this.desktopMode ? 'Mobile' : 'Desktop',
            this.desktopMode ? Theme.of(this.isDark).accent : Theme.of(this.isDark).text, (): void => {
              this.onToggleDesktop();
            })
          this.quickAction($r('app.media.ic_add'), 'New tab', Theme.of(this.isDark).text, (): void => {
            this.onNewTab();
          })
        }
        .width('100%')
        .padding({ top: 6, bottom: 14, left: 10, right: 10 })

        Divider()
          .color(Theme.of(this.isDark).border)
          .strokeWidth(0.5)

        this.menuRow($r('app.media.ic_bookmarks'), 'Bookmarks', Theme.of(this.isDark).text, (): void => {
          this.onBookmarks();
        })
        this.menuRow($r('app.media.ic_history'), 'History', Theme.of(this.isDark).text, (): void => {
          this.onHistory();
        })
        this.menuRow($r('app.media.ic_settings'), 'Settings', Theme.of(this.isDark).text, (): void => {
          this.onSettings();
        })
        if (this.canClose) {
          this.menuRow($r('app.media.ic_close'), 'Close tab', Theme.of(this.isDark).danger, (): void => {
            this.onCloseTab();
          })
        }
        Blank().height(12)
      }
      .width('100%')
      .backgroundColor(Theme.of(this.isDark).surface)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct LinkMenu {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @Prop url: string;
  onOpen: () => void = () => {};
  onOpenNewTab: () => void = () => {};
  onCopy: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Theme.of(this.isDark).scrim)
        .onClick(() => {
          this.onDismiss();
        })

      Column() {
        Text(this.url)
          .fontSize(12)
          .fontColor(Theme.of(this.isDark).textDim)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        Divider()
          .color(Theme.of(this.isDark).border)
          .strokeWidth(0.5)

        Row({ space: 14 }) {
          Image($r('app.media.ic_add'))
            .width(20)
            .height(20)
            .fillColor(Theme.of(this.isDark).text)
          Text('Open in new tab')
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).text)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .onClick(() => {
          this.onOpenNewTab();
        })

        Row({ space: 14 }) {
          Image($r('app.media.ic_globe'))
            .width(20)
            .height(20)
            .fillColor(Theme.of(this.isDark).text)
          Text('Open link')
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).text)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .onClick(() => {
          this.onOpen();
        })

        Row({ space: 14 }) {
          Image($r('app.media.ic_bookmarks'))
            .width(20)
            .height(20)
            .fillColor(Theme.of(this.isDark).text)
          Text('Copy link address')
            .fontSize(15)
            .fontColor(Theme.of(this.isDark).text)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .onClick(() => {
          this.onCopy();
        })

        Blank().height(14)
      }
      .width('100%')
      .backgroundColor(Theme.of(this.isDark).surface)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct DialogHost {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  request: DialogRequest = new DialogRequest(DialogKind.MESSAGE, '', '', () => {}, () => {});
  @State promptText: string = '';
  onDone: () => void = () => {};

  aboutToAppear(): void {
    this.promptText = this.request.defaultValue;
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Text(this.request.title.length > 0 ? this.request.title : 'This page says')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.of(this.isDark).text)
          .width('100%')
        Text(this.request.message)
          .fontSize(14)
          .fontColor(Theme.of(this.isDark).textDim)
          .width('100%')
          .maxLines(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.request.kind === DialogKind.PROMPT) {
          TextInput({ text: this.promptText })
            .height(38)
            .backgroundColor(Theme.of(this.isDark).surfaceAlt)
            .fontColor(Theme.of(this.isDark).text)
            .borderRadius(8)
            .onChange((value: string) => {
              this.promptText = value;
            })
        }

        Row({ space: 10 }) {
          if (this.request.kind !== DialogKind.MESSAGE) {
            Text(this.request.cancelLabel)
              .fontSize(15)
              .fontColor(Theme.of(this.isDark).textDim)
              .padding(10)
              .onClick(() => {
                this.request.cancel();
                this.onDone();
              })
          }
          Text(this.request.confirmLabel)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.of(this.isDark).accent)
            .padding(10)
            .onClick(() => {
              this.request.confirm(this.promptText);
              this.onDone();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('86%')
      .padding(20)
      .backgroundColor(Theme.of(this.isDark).surface)
      .borderRadius(18)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.of(this.isDark).scrim)
  }
}

@Component
export struct FindBar {
  @ObjectLink tab: BrowserTab;
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @State query: string = '';
  onSearch: (text: string) => void = () => {};
  onNext: (forward: boolean) => void = () => {};
  onClose: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      TextInput({ text: this.query, placeholder: 'Find in page' })
        .layoutWeight(1)
        .height(36)
        .backgroundColor(Theme.of(this.isDark).surfaceAlt)
        .fontColor(Theme.of(this.isDark).text)
        .placeholderColor(Theme.of(this.isDark).textDim)
        .borderRadius(18)
        .onChange((value: string) => {
          this.query = value;
          this.onSearch(value);
        })

      Text(this.tab.matchCount > 0 ? this.tab.matchIndex + '/' + this.tab.matchCount : '0/0')
        .fontSize(12)
        .fontColor(Theme.of(this.isDark).textDim)

      Image($r('app.media.ic_up'))
        .width(20)
        .height(20)
        .fillColor(Theme.of(this.isDark).text)
        .onClick(() => {
          this.onNext(false);
        })
      Image($r('app.media.ic_down'))
        .width(20)
        .height(20)
        .fillColor(Theme.of(this.isDark).text)
        .onClick(() => {
          this.onNext(true);
        })
      Image($r('app.media.ic_close'))
        .width(18)
        .height(18)
        .fillColor(Theme.of(this.isDark).textDim)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Theme.of(this.isDark).chrome)
    .border({ width: { bottom: 0.5 }, color: Theme.of(this.isDark).border })
  }
}

@Component
export struct SuggestionList {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @Prop suggestions: Suggestion[];
  onPick: (suggestion: Suggestion) => void = () => {};

  private iconFor(kind: SuggestionKind): Resource {
    if (kind === SuggestionKind.HISTORY) {
      return $r('app.media.ic_history');
    }
    if (kind === SuggestionKind.BOOKMARK) {
      return $r('app.media.ic_bookmarks');
    }
    if (kind === SuggestionKind.DIRECT) {
      return $r('app.media.ic_globe');
    }
    return $r('app.media.ic_search');
  }

  build() {
    List() {
      ForEach(this.suggestions, (item: Suggestion) => {
        ListItem() {
          Row({ space: 12 }) {
            Image(this.iconFor(item.kind))
              .width(18)
              .height(18)
              .fillColor(Theme.of(this.isDark).textDim)
            Column({ space: 2 }) {
              Text(item.title)
                .fontSize(15)
                .fontColor(Theme.of(this.isDark).text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              if (item.subtitle.length > 0) {
                Text(item.subtitle)
                  .fontSize(12)
                  .fontColor(Theme.of(this.isDark).textDim)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 11, bottom: 11 })
          .onClick(() => {
            this.onPick(item);
          })
        }
      }, (item: Suggestion, index: number) => item.kind.toString() + '-' + item.target + '-' + index)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.of(this.isDark).bg)
    .scrollBar(BarState.Off)
  }
}

@Component
export struct Toast {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @Prop message: string;

  build() {
    Column() {
      Text(this.message)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#CC1F2329')
        .borderRadius(Metrics.RADIUS)
        .maxLines(2)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * Offers a freshly downloaded picture or video to the gallery. The SaveButton
 * is a security component: the system draws it and only a real tap on it grants
 * the app the short-lived permission that lets the media library accept the
 * file, so this cannot be replaced with an ordinary Button.
 */
@Component
export struct SaveToGalleryBar {
  @StorageProp(SettingsKeys.IS_DARK) isDark: boolean = false;
  @Prop target: DownloadTarget;
  @State private busy: boolean = false;
  onDone: (message: string) => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.target.kind === DownloadKind.VIDEO ? 'Video downloaded' : 'Picture downloaded')
          .fontSize(13)
          .fontColor(Theme.of(this.isDark).text)
        Text(this.target.name)
          .fontSize(11)
          .fontColor(Theme.of(this.isDark).textDim)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SaveButton({ icon: SaveIconStyle.FULL_FILLED, text: SaveDescription.SAVE_TO_GALLERY,
        buttonType: ButtonType.Capsule })
        .enabled(!this.busy)
        .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (this.busy) {
            return;
          }
          if (result !== SaveButtonOnClickResult.SUCCESS) {
            this.onDone('Could not get permission to save');
            return;
          }
          this.busy = true;
          Downloads.saveToGallery(this.target.path).then((saved: boolean) => {
            this.busy = false;
            this.onDone(saved ? 'Saved to Gallery' : 'Could not save to Gallery');
          }).catch(() => {
            this.busy = false;
            this.onDone('Could not save to Gallery');
          });
        })

      Text('✕')
        .fontSize(16)
        .fontColor(Theme.of(this.isDark).textDim)
        .padding(6)
        .onClick(() => this.onDismiss())
    }
    .width('100%')
    .padding({ left: 14, right: 10, top: 10, bottom: 10 })
    .backgroundColor(Theme.of(this.isDark).surface)
    .borderRadius(Metrics.RADIUS)
    .shadow({ radius: 12, color: '#33000000', offsetY: 2 })
  }
}
