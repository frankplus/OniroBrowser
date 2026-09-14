/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 */

/** A row of the `history` table. */
export class HistoryEntry {
  id: number = 0;
  url: string = '';
  title: string = '';
  visitTime: number = 0;
  visitCount: number = 1;

  constructor(id: number, url: string, title: string, visitTime: number, visitCount: number) {
    this.id = id;
    this.url = url;
    this.title = title;
    this.visitTime = visitTime;
    this.visitCount = visitCount;
  }
}

/** A row of the `bookmarks` table. */
export class BookmarkEntry {
  id: number = 0;
  url: string = '';
  title: string = '';
  created: number = 0;

  constructor(id: number, url: string, title: string, created: number) {
    this.id = id;
    this.url = url;
    this.title = title;
    this.created = created;
  }
}

/** One entry of the omnibox drop-down. */
export enum SuggestionKind {
  SEARCH = 0,
  HISTORY = 1,
  BOOKMARK = 2,
  DIRECT = 3
}

export class Suggestion {
  kind: SuggestionKind = SuggestionKind.SEARCH;
  title: string = '';
  subtitle: string = '';
  target: string = '';

  constructor(kind: SuggestionKind, title: string, subtitle: string, target: string) {
    this.kind = kind;
    this.title = title;
    this.subtitle = subtitle;
    this.target = target;
  }
}

/** A search provider the omnibox can hand a free-text query to. */
export class SearchEngine {
  name: string = '';
  queryUrl: string = '';
  host: string = '';

  constructor(name: string, queryUrl: string, host: string) {
    this.name = name;
    this.queryUrl = queryUrl;
    this.host = host;
  }
}

export const SEARCH_ENGINES: SearchEngine[] = [
  new SearchEngine('DuckDuckGo', 'https://duckduckgo.com/?q=', 'duckduckgo.com'),
  new SearchEngine('Google', 'https://www.google.com/search?q=', 'google.com'),
  new SearchEngine('Bing', 'https://www.bing.com/search?q=', 'bing.com'),
  new SearchEngine('Startpage', 'https://www.startpage.com/sp/search?query=', 'startpage.com'),
  new SearchEngine('Wikipedia', 'https://en.wikipedia.org/w/index.php?search=', 'wikipedia.org')
];

/** Persisted shape of one tab in the restored session. */
export interface SessionTabRecord {
  url: string;
  title: string;
}

/** Persisted shape of the whole session. */
export interface SessionRecord {
  tabs: SessionTabRecord[];
  activeIndex: number;
}

/** Which full-screen surface is stacked over the web content. */
export enum OverlayKind {
  NONE = 0,
  TABS = 1,
  BOOKMARKS = 2,
  HISTORY = 3,
  SETTINGS = 4,
  MENU = 5
}

/** A shortcut tile on the new-tab page. */
export class SpeedDialItem {
  label: string = '';
  url: string = '';
  glyph: string = '';
  tint: string = '';

  constructor(label: string, url: string, glyph: string, tint: string) {
    this.label = label;
    this.url = url;
    this.glyph = glyph;
    this.tint = tint;
  }
}

export const DEFAULT_SPEED_DIAL: SpeedDialItem[] = [
  new SpeedDialItem('Oniro', 'https://oniroproject.org', 'O', '#2F6FED'),
  new SpeedDialItem('OpenHarmony', 'https://www.openharmony.cn', 'H', '#0A59F7'),
  new SpeedDialItem('Wikipedia', 'https://en.wikipedia.org', 'W', '#4B5563'),
  new SpeedDialItem('DuckDuckGo', 'https://duckduckgo.com', 'D', '#DE5833'),
  new SpeedDialItem('GitHub', 'https://github.com', 'G', '#24292F'),
  new SpeedDialItem('Hacker News', 'https://news.ycombinator.com', 'Y', '#FF6600'),
  new SpeedDialItem('OpenStreetMap', 'https://www.openstreetmap.org', 'M', '#7EBC6F'),
  new SpeedDialItem('Wikinews', 'https://en.wikinews.org', 'N', '#0B7285')
];
