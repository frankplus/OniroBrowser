/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Settings are mirrored into AppStorage so the UI reacts to them, and
 * written back to preferences so they survive a restart.
 */
import { SEARCH_ENGINES, SearchEngine } from '../common/Types';
import { BrowserStore } from './BrowserStore';

export class SettingsKeys {
  static readonly ENGINE: string = 'engineIndex';
  static readonly DESKTOP: string = 'desktopMode';
  static readonly THEME: string = 'themeMode'; // 0 system, 1 light, 2 dark
  static readonly JS: string = 'jsEnabled';
  static readonly RESTORE: string = 'restoreSession';
  static readonly TEXT_ZOOM: string = 'textZoom';
  static readonly THIRD_PARTY_COOKIES: string = 'thirdPartyCookies';
  static readonly MAX_LIVE_TABS: string = 'maxLiveTabs';
  static readonly SYSTEM_DARK: string = 'systemDark';
  static readonly IS_DARK: string = 'isDark';
}

export class Settings {
  /** Load persisted values into AppStorage. Call once, before the first build. */
  static async load(): Promise<void> {
    AppStorage.setOrCreate(SettingsKeys.ENGINE, await BrowserStore.getNumber(SettingsKeys.ENGINE, 0));
    AppStorage.setOrCreate(SettingsKeys.DESKTOP, await BrowserStore.getBool(SettingsKeys.DESKTOP, false));
    AppStorage.setOrCreate(SettingsKeys.THEME, await BrowserStore.getNumber(SettingsKeys.THEME, 0));
    AppStorage.setOrCreate(SettingsKeys.JS, await BrowserStore.getBool(SettingsKeys.JS, true));
    AppStorage.setOrCreate(SettingsKeys.RESTORE, await BrowserStore.getBool(SettingsKeys.RESTORE, true));
    AppStorage.setOrCreate(SettingsKeys.TEXT_ZOOM, await BrowserStore.getNumber(SettingsKeys.TEXT_ZOOM, 100));
    AppStorage.setOrCreate(SettingsKeys.THIRD_PARTY_COOKIES,
      await BrowserStore.getBool(SettingsKeys.THIRD_PARTY_COOKIES, false));
    AppStorage.setOrCreate(SettingsKeys.MAX_LIVE_TABS, await BrowserStore.getNumber(SettingsKeys.MAX_LIVE_TABS, 6));
    Settings.refreshDarkFlag();
  }

  static engine(): SearchEngine {
    const index: number = AppStorage.get<number>(SettingsKeys.ENGINE) ?? 0;
    if (index < 0 || index >= SEARCH_ENGINES.length) {
      return SEARCH_ENGINES[0];
    }
    return SEARCH_ENGINES[index];
  }

  static setEngineIndex(index: number): void {
    AppStorage.setOrCreate(SettingsKeys.ENGINE, index);
    BrowserStore.putNumber(SettingsKeys.ENGINE, index);
  }

  static bool(key: string, fallback: boolean): boolean {
    return AppStorage.get<boolean>(key) ?? fallback;
  }

  static number(key: string, fallback: number): number {
    return AppStorage.get<number>(key) ?? fallback;
  }

  static setBool(key: string, value: boolean): void {
    AppStorage.setOrCreate(key, value);
    BrowserStore.putBool(key, value);
    if (key === SettingsKeys.THEME) {
      Settings.refreshDarkFlag();
    }
  }

  static setNumber(key: string, value: number): void {
    AppStorage.setOrCreate(key, value);
    BrowserStore.putNumber(key, value);
    if (key === SettingsKeys.THEME) {
      Settings.refreshDarkFlag();
    }
  }

  /** Recompute the effective dark flag from the theme mode and the system setting. */
  static refreshDarkFlag(): void {
    const mode: number = Settings.number(SettingsKeys.THEME, 0);
    const systemDark: boolean = Settings.bool(SettingsKeys.SYSTEM_DARK, false);
    const isDark: boolean = mode === 0 ? systemDark : mode === 2;
    AppStorage.setOrCreate(SettingsKeys.IS_DARK, isDark);
  }

  static setSystemDark(systemDark: boolean): void {
    AppStorage.setOrCreate(SettingsKeys.SYSTEM_DARK, systemDark);
    Settings.refreshDarkFlag();
  }
}
