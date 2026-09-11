/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * Persistence layer: history and bookmarks live in a relational store,
 * settings and the restorable session live in preferences.
 */
import { relationalStore, preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BookmarkEntry, HistoryEntry, SessionRecord } from '../common/Types';
import { Logger } from '../common/Logger';

const CREATE_HISTORY: string = 'CREATE TABLE IF NOT EXISTS history (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL, title TEXT, ' +
  'visit_time INTEGER NOT NULL, visit_count INTEGER NOT NULL DEFAULT 1)';
const CREATE_HISTORY_INDEX: string = 'CREATE UNIQUE INDEX IF NOT EXISTS idx_history_url ON history(url)';
const CREATE_BOOKMARKS: string = 'CREATE TABLE IF NOT EXISTS bookmarks (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL UNIQUE, title TEXT, created INTEGER NOT NULL)';

const PREF_STORE: string = 'browser_prefs';
const KEY_SESSION: string = 'session';

export class BrowserStore {
  private static rdb: relationalStore.RdbStore | undefined = undefined;
  private static prefs: preferences.Preferences | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (BrowserStore.rdb !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'browser.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await store.executeSql(CREATE_HISTORY);
    await store.executeSql(CREATE_HISTORY_INDEX);
    await store.executeSql(CREATE_BOOKMARKS);
    BrowserStore.rdb = store;
    BrowserStore.prefs = await preferences.getPreferences(context, PREF_STORE);
    Logger.info('store ready');
  }

  static isReady(): boolean {
    return BrowserStore.rdb !== undefined;
  }

  // ---------------------------------------------------------------- history

  static async addVisit(url: string, title: string): Promise<void> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined || url.length === 0 || url.startsWith('about:')) {
      return;
    }
    try {
      const now: number = new Date().getTime();
      const existing: relationalStore.ResultSet =
        await store.querySql('SELECT id, visit_count FROM history WHERE url = ?', [url]);
      if (existing.goToFirstRow()) {
        const id: number = existing.getLong(existing.getColumnIndex('id'));
        const count: number = existing.getLong(existing.getColumnIndex('visit_count'));
        existing.close();
        await store.executeSql('UPDATE history SET visit_time = ?, visit_count = ?, title = ? WHERE id = ?',
          [now, count + 1, title, id]);
      } else {
        existing.close();
        const row: relationalStore.ValuesBucket = {
          'url': url,
          'title': title,
          'visit_time': now,
          'visit_count': 1
        };
        await store.insert('history', row);
      }
    } catch (err) {
      Logger.error('addVisit failed: ' + (err as BusinessError).message);
    }
  }

  private static async readHistory(sql: string, args: Array<relationalStore.ValueType>): Promise<HistoryEntry[]> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    const out: HistoryEntry[] = [];
    if (store === undefined) {
      return out;
    }
    try {
      const rs: relationalStore.ResultSet = await store.querySql(sql, args);
      const iId: number = rs.getColumnIndex('id');
      const iUrl: number = rs.getColumnIndex('url');
      const iTitle: number = rs.getColumnIndex('title');
      const iTime: number = rs.getColumnIndex('visit_time');
      const iCount: number = rs.getColumnIndex('visit_count');
      while (rs.goToNextRow()) {
        out.push(new HistoryEntry(rs.getLong(iId), rs.getString(iUrl), rs.getString(iTitle),
          rs.getLong(iTime), rs.getLong(iCount)));
      }
      rs.close();
    } catch (err) {
      Logger.error('history query failed: ' + (err as BusinessError).message);
    }
    return out;
  }

  static async recentHistory(limit: number): Promise<HistoryEntry[]> {
    return BrowserStore.readHistory('SELECT * FROM history ORDER BY visit_time DESC LIMIT ?', [limit]);
  }

  static async searchHistory(query: string, limit: number): Promise<HistoryEntry[]> {
    const like: string = '%' + query + '%';
    return BrowserStore.readHistory(
      'SELECT * FROM history WHERE url LIKE ? OR title LIKE ? ORDER BY visit_count DESC, visit_time DESC LIMIT ?',
      [like, like, limit]);
  }

  static async topSites(limit: number): Promise<HistoryEntry[]> {
    return BrowserStore.readHistory('SELECT * FROM history ORDER BY visit_count DESC, visit_time DESC LIMIT ?',
      [limit]);
  }

  static async deleteHistory(id: number): Promise<void> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined) {
      return;
    }
    await store.executeSql('DELETE FROM history WHERE id = ?', [id]);
  }

  static async clearHistory(): Promise<void> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined) {
      return;
    }
    await store.executeSql('DELETE FROM history');
  }

  // -------------------------------------------------------------- bookmarks

  static async bookmarks(): Promise<BookmarkEntry[]> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    const out: BookmarkEntry[] = [];
    if (store === undefined) {
      return out;
    }
    try {
      const rs: relationalStore.ResultSet = await store.querySql('SELECT * FROM bookmarks ORDER BY created DESC', []);
      const iId: number = rs.getColumnIndex('id');
      const iUrl: number = rs.getColumnIndex('url');
      const iTitle: number = rs.getColumnIndex('title');
      const iCreated: number = rs.getColumnIndex('created');
      while (rs.goToNextRow()) {
        out.push(new BookmarkEntry(rs.getLong(iId), rs.getString(iUrl), rs.getString(iTitle), rs.getLong(iCreated)));
      }
      rs.close();
    } catch (err) {
      Logger.error('bookmarks query failed: ' + (err as BusinessError).message);
    }
    return out;
  }

  static async isBookmarked(url: string): Promise<boolean> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined || url.length === 0) {
      return false;
    }
    const rs: relationalStore.ResultSet = await store.querySql('SELECT id FROM bookmarks WHERE url = ?', [url]);
    const found: boolean = rs.goToFirstRow();
    rs.close();
    return found;
  }

  static async addBookmark(url: string, title: string): Promise<void> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined || url.length === 0) {
      return;
    }
    const row: relationalStore.ValuesBucket = {
      'url': url,
      'title': title.length > 0 ? title : url,
      'created': new Date().getTime()
    };
    try {
      await store.insert('bookmarks', row);
    } catch (err) {
      Logger.error('addBookmark failed: ' + (err as BusinessError).message);
    }
  }

  static async removeBookmark(url: string): Promise<void> {
    const store: relationalStore.RdbStore | undefined = BrowserStore.rdb;
    if (store === undefined) {
      return;
    }
    await store.executeSql('DELETE FROM bookmarks WHERE url = ?', [url]);
  }

  // ------------------------------------------------------- settings/session

  static async putString(key: string, value: string): Promise<void> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return;
    }
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getString(key: string, fallback: string): Promise<string> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return fallback;
    }
    const value: preferences.ValueType = await prefs.get(key, fallback);
    return value as string;
  }

  static async putNumber(key: string, value: number): Promise<void> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return;
    }
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getNumber(key: string, fallback: number): Promise<number> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return fallback;
    }
    const value: preferences.ValueType = await prefs.get(key, fallback);
    return value as number;
  }

  static async putBool(key: string, value: boolean): Promise<void> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return;
    }
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getBool(key: string, fallback: boolean): Promise<boolean> {
    const prefs: preferences.Preferences | undefined = BrowserStore.prefs;
    if (prefs === undefined) {
      return fallback;
    }
    const value: preferences.ValueType = await prefs.get(key, fallback);
    return value as boolean;
  }

  static async saveSession(record: SessionRecord): Promise<void> {
    await BrowserStore.putString(KEY_SESSION, JSON.stringify(record));
  }

  static async loadSession(): Promise<SessionRecord | undefined> {
    const raw: string = await BrowserStore.getString(KEY_SESSION, '');
    if (raw.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(raw) as SessionRecord;
    } catch (err) {
      Logger.warn('session parse failed');
      return undefined;
    }
  }
}
