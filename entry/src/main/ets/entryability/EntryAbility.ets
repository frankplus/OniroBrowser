/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { BrowserStore } from '../model/BrowserStore';
import { Downloads } from '../common/Downloads';
import { Settings } from '../model/Settings';
import { Logger } from '../common/Logger';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    AppStorage.setOrCreate('abilityContext', this.context);
    AppStorage.setOrCreate('pendingUrl', '');
    AppStorage.setOrCreate('memoryPressure', 0);

    // Warm the engine while the shell is still building its first frame.
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (err) {
      Logger.warn('initializeWebEngine: ' + (err as BusinessError).message);
    }

    BrowserStore.init(this.context)
      .then(() => Settings.load())
      .then(() => {
        Logger.info('browser data ready');
      })
      .catch((err: BusinessError) => {
        Logger.error('data init failed: ' + err.message);
      });

    // Move what an earlier run had to leave behind, and drop stale staged files.
    Downloads.sweepPending().catch((err: BusinessError) => {
      Logger.warn('download sweep failed: ' + err.message);
    });

    this.takeUrlFromWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.takeUrlFromWant(want);
  }

  /** Accept http(s) links handed over by other applications. */
  private takeUrlFromWant(want: Want): void {
    const uri: string | undefined = want.uri;
    if (uri !== undefined && uri.length > 0) {
      AppStorage.setOrCreate('pendingUrl', uri);
      Logger.info('opening external link');
    }
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_MODERATE ||
      level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_LOW ||
      level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL) {
      const current: number = AppStorage.get<number>('memoryPressure') ?? 0;
      AppStorage.setOrCreate('memoryPressure', current + 1);
      Logger.info('memory level ' + level);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error('loadContent failed: ' + JSON.stringify(err));
        return;
      }
      try {
        const mainWindow: window.Window = windowStage.getMainWindowSync();
        mainWindow.setWindowLayoutFullScreen(false);
      } catch (error) {
        Logger.warn('window setup: ' + (error as BusinessError).message);
      }
    });
  }

  onBackground(): void {
    try {
      webview.WebCookieManager.saveCookieSync();
    } catch (err) {
      Logger.warn('saveCookie: ' + (err as BusinessError).message);
    }
  }
}
