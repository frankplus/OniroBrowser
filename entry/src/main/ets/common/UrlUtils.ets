/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */
import { SearchEngine } from './Types';

const SCHEME_RE: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:');
/** Only these schemes are navigated to; anything else is a search. */
const KNOWN_SCHEMES: string[] = ['http:', 'https:', 'file:', 'data:', 'about:', 'ftp:', 'blob:', 'view-source:'];
const IPV4_RE: RegExp = new RegExp('^\\d{1,3}(\\.\\d{1,3}){3}(:\\d+)?(/.*)?$');
const HOSTNAME_RE: RegExp = new RegExp('^[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)+(:\\d+)?(/.*)?$');
const LOCALHOST_RE: RegExp = new RegExp('^localhost(:\\d+)?(/.*)?$');

export class UrlUtils {
  /** True when the text should be treated as a location rather than a search query. */
  static looksLikeUrl(raw: string): boolean {
    const input: string = raw.trim();
    if (input.length === 0 || input.includes(' ')) {
      return false;
    }
    if (SCHEME_RE.test(input)) {
      return UrlUtils.hasKnownScheme(input);
    }
    if (LOCALHOST_RE.test(input) || IPV4_RE.test(input)) {
      return true;
    }
    return HOSTNAME_RE.test(input);
  }

  private static hasKnownScheme(input: string): boolean {
    const lower: string = input.toLowerCase();
    for (const scheme of KNOWN_SCHEMES) {
      if (lower.startsWith(scheme)) {
        return true;
      }
    }
    return false;
  }

  /** Turn whatever the user typed into something the engine can load. */
  static toNavigationUrl(raw: string, engine: SearchEngine): string {
    const input: string = raw.trim();
    if (input.length === 0) {
      return '';
    }
    if (UrlUtils.looksLikeUrl(input)) {
      if (UrlUtils.hasKnownScheme(input)) {
        return input;
      }
      return 'https://' + input;
    }
    return engine.queryUrl + encodeURIComponent(input);
  }

  /** Host portion of a URL, or '' when there is none. */
  static host(url: string): string {
    let rest: string = url;
    const schemeEnd: number = rest.indexOf('://');
    if (schemeEnd >= 0) {
      rest = rest.substring(schemeEnd + 3);
    } else if (SCHEME_RE.test(rest)) {
      return '';
    }
    let end: number = rest.length;
    const slash: number = rest.indexOf('/');
    if (slash >= 0 && slash < end) {
      end = slash;
    }
    const query: number = rest.indexOf('?');
    if (query >= 0 && query < end) {
      end = query;
    }
    const hash: number = rest.indexOf('#');
    if (hash >= 0 && hash < end) {
      end = hash;
    }
    let host: string = rest.substring(0, end);
    const at: number = host.lastIndexOf('@');
    if (at >= 0) {
      host = host.substring(at + 1);
    }
    const colon: number = host.indexOf(':');
    if (colon >= 0) {
      host = host.substring(0, colon);
    }
    return host;
  }

  /** Host without a leading `www.`, for compact display. */
  static shortHost(url: string): string {
    const host: string = UrlUtils.host(url);
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static isSecure(url: string): boolean {
    return url.startsWith('https://');
  }

  static isHome(url: string): boolean {
    return url.length === 0 || url === 'about:blank' || url === 'about:home';
  }

  /** Drop the scheme and any trailing slash so the omnibox reads cleanly. */
  static pretty(url: string): string {
    let out: string = url;
    if (out.startsWith('https://')) {
      out = out.substring(8);
    } else if (out.startsWith('http://')) {
      out = out.substring(7);
    }
    if (out.startsWith('www.')) {
      out = out.substring(4);
    }
    if (out.endsWith('/') && out.indexOf('/') === out.length - 1) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /** A one-character badge for a site with no favicon yet. */
  static initial(url: string, title: string): string {
    const host: string = UrlUtils.shortHost(url);
    if (host.length > 0) {
      return host.substring(0, 1).toUpperCase();
    }
    if (title.length > 0) {
      return title.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  /** Stable pastel-ish tint derived from the host, used for letter avatars. */
  static tint(url: string): string {
    const host: string = UrlUtils.shortHost(url);
    let hash: number = 0;
    for (let i = 0; i < host.length; i++) {
      hash = (hash * 31 + host.charCodeAt(i)) % 360;
    }
    const palette: string[] =
      ['#2F6FED', '#0A9396', '#BB3E03', '#6A4C93', '#1B7F5E', '#C1121F', '#B08968', '#3A5A40'];
    return palette[hash % palette.length];
  }

  static fileNameOf(url: string, fallback: string): string {
    let path: string = url;
    const q: number = path.indexOf('?');
    if (q >= 0) {
      path = path.substring(0, q);
    }
    const slash: number = path.lastIndexOf('/');
    const name: string = slash >= 0 ? path.substring(slash + 1) : path;
    return name.length > 0 ? name : fallback;
  }
}
