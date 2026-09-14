/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * ArkWeb's stock user agent is shaped unlike any mainstream browser:
 *
 *   Mozilla/5.0 (Phone; OpenHarmony 6.1) AppleWebKit/537.36 (KHTML, like
 *   Gecko) Chrome/132.0.0.0 Safari/537.36 ArkWeb/6.1.0.32 Mobile
 *
 * The platform token carries no `Linux`, and the mobile marker trails the
 * whole string instead of reading `Chrome/<v> Mobile Safari/537.36`. Sites
 * that branch on the user agent therefore fail to recognise a modern mobile
 * browser and fall back to their oldest layout — google.com answers with its
 * WAP-era "tier 3" page, duckduckgo.com stalls. Reshaping the token order
 * into the Chrome-on-mobile form fixes both, and keeps the real engine and
 * OS versions rather than pretending to be Android.
 */
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

/** Form-factor words ArkWeb may put in the platform token; they move to the end. */
const FORM_FACTORS: string[] = ['Phone', 'Tablet', 'TV', 'Wearable', 'Car', 'PC', '2in1'];
/** Used when the engine refuses to hand over its own user agent. */
const MOBILE_FALLBACK: string =
  'Mozilla/5.0 (Linux; OpenHarmony; Phone) AppleWebKit/537.36 (KHTML, like Gecko) ' +
  'Chrome/132.0.0.0 Mobile Safari/537.36';

export class UserAgent {
  /** Sent while "Desktop site" is on. */
  static readonly DESKTOP: string =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';

  private static mobileCache: string = '';

  /** The engine's user agent, reshaped so sniffers see a mobile Chrome. */
  static mobile(): string {
    if (UserAgent.mobileCache.length > 0) {
      return UserAgent.mobileCache;
    }
    let stock: string = '';
    try {
      stock = webview.WebviewController.getDefaultUserAgent();
    } catch (err) {
      Logger.warn('default user agent unavailable: ' + (err as BusinessError).message);
    }
    UserAgent.mobileCache = stock.length === 0 ? MOBILE_FALLBACK : UserAgent.reshape(stock);
    return UserAgent.mobileCache;
  }

  /** `(Phone; OpenHarmony 6.1) … Safari/537.36 … Mobile` → `(Linux; OpenHarmony 6.1; Phone) … Mobile Safari/537.36 …`. */
  static reshape(stock: string): string {
    let out: string = UserAgent.withLinuxPlatform(stock);
    if (out.endsWith(' Mobile')) {
      out = out.substring(0, out.length - ' Mobile'.length);
    }
    if (!out.includes('Mobile Safari/')) {
      const safari: number = out.indexOf('Safari/');
      if (safari >= 0) {
        out = out.substring(0, safari) + 'Mobile ' + out.substring(safari);
      } else {
        out = out + ' Mobile Safari/537.36';
      }
    }
    return out;
  }

  /** Rewrite the parenthesised platform token so it starts with `Linux`. */
  private static withLinuxPlatform(stock: string): string {
    const open: number = stock.indexOf('(');
    const close: number = stock.indexOf(')');
    if (open < 0 || close <= open) {
      return stock;
    }
    const kept: string[] = ['Linux'];
    let formFactor: string = '';
    for (const raw of stock.substring(open + 1, close).split(';')) {
      const token: string = raw.trim();
      if (token.length === 0 || token === 'Linux') {
        continue;
      }
      if (FORM_FACTORS.includes(token)) {
        formFactor = token;
        continue;
      }
      kept.push(token);
    }
    if (formFactor.length > 0) {
      kept.push(formFactor);
    }
    return stock.substring(0, open + 1) + kept.join('; ') + stock.substring(close);
  }
}
