/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */
import { webview } from '@kit.ArkWeb';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UrlUtils } from '../common/UrlUtils';
import { Logger } from '../common/Logger';

let nextTabId: number = 1;

/**
 * One browser tab. Holds its own WebviewController; the Web component that the
 * controller drives is created by WebTabView while `alive` is true. A discarded
 * tab (`alive === false`) keeps only its URL, title and serialized engine state,
 * and is rebuilt on demand.
 */
@Observed
export class BrowserTab {
  id: number = 0;
  controller: webview.WebviewController = new webview.WebviewController();
  /** URL the Web component is created with; also the restore target. */
  initialUrl: string = 'about:blank';
  url: string = '';
  title: string = 'New tab';
  progress: number = 0;
  loading: boolean = false;
  canBack: boolean = false;
  canForward: boolean = false;
  attached: boolean = false;
  alive: boolean = true;
  /** Renderer released to save memory; the component itself stays put. */
  sleeping: boolean = false;
  isHome: boolean = true;
  secure: boolean = false;
  errorText: string = '';
  pendingUrl: string = '';
  favicon: image.PixelMap | undefined = undefined;
  thumbnail: image.PixelMap | undefined = undefined;
  lastUsed: number = 0;
  matchCount: number = 0;
  matchIndex: number = 0;

  constructor(url: string) {
    this.id = nextTabId++;
    this.lastUsed = new Date().getTime();
    if (!UrlUtils.isHome(url)) {
      this.initialUrl = url;
      this.url = url;
      this.title = UrlUtils.shortHost(url);
      this.isHome = false;
      this.secure = UrlUtils.isSecure(url);
    } else {
      // A brand-new tab shows the native start page; no renderer is spawned
      // until the user actually navigates.
      this.alive = false;
    }
  }

  /** A tab rebuilt from a saved session: known URL, no renderer until used. */
  static restored(url: string, title: string): BrowserTab {
    const tab: BrowserTab = new BrowserTab('');
    tab.url = url;
    tab.initialUrl = url;
    tab.title = title.length > 0 ? title : UrlUtils.shortHost(url);
    tab.isHome = false;
    tab.secure = UrlUtils.isSecure(url);
    tab.alive = false;
    return tab;
  }

  /** Human label for the tab strip and the switcher. */
  label(): string {
    if (this.title.length > 0 && this.title !== 'about:blank') {
      return this.title;
    }
    const host: string = UrlUtils.shortHost(this.url);
    return host.length > 0 ? host : 'New tab';
  }

  /** Load a URL, deferring it when the controller is not attached yet. */
  navigate(url: string): void {
    if (url.length === 0) {
      return;
    }
    this.errorText = '';
    this.isHome = UrlUtils.isHome(url);
    this.url = url;
    this.secure = UrlUtils.isSecure(url);
    if (this.isHome) {
      return;
    }
    if (!this.alive) {
      // Never loaded yet (new or session-restored tab): build the component
      // straight onto this URL.
      this.initialUrl = url;
      this.alive = true;
      return;
    }
    if (!this.attached) {
      this.pendingUrl = url;
      return;
    }
    try {
      this.controller.loadUrl(url);
    } catch (err) {
      Logger.warn('loadUrl deferred: ' + (err as BusinessError).message);
      this.pendingUrl = url;
    }
  }

  reload(): void {
    if (!this.attached || this.isHome) {
      return;
    }
    try {
      this.controller.refresh();
    } catch (err) {
      Logger.warn('refresh failed: ' + (err as BusinessError).message);
    }
  }

  stop(): void {
    if (!this.attached) {
      return;
    }
    try {
      this.controller.stop();
      this.loading = false;
    } catch (err) {
      Logger.warn('stop failed: ' + (err as BusinessError).message);
    }
  }

  back(): boolean {
    if (!this.attached || this.isHome) {
      return false;
    }
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return true;
      }
    } catch (err) {
      Logger.warn('backward failed: ' + (err as BusinessError).message);
    }
    return false;
  }

  forward(): void {
    if (!this.attached) {
      return;
    }
    try {
      if (this.controller.accessForward()) {
        this.controller.forward();
      }
    } catch (err) {
      Logger.warn('forward failed: ' + (err as BusinessError).message);
    }
  }

  /** Refresh the cached back/forward availability after a navigation. */
  syncNavState(): void {
    if (!this.attached) {
      return;
    }
    try {
      this.canBack = this.controller.accessBackward();
      this.canForward = this.controller.accessForward();
    } catch (err) {
      this.canBack = false;
      this.canForward = false;
    }
  }

  /**
   * Release the renderer of a background tab. The Web component is kept:
   * destroying one blocks the UI thread inside the engine long enough for
   * the ability watchdog to kill the app, so tabs sleep by killing their
   * render process instead.
   */
  discard(): void {
    if (!this.alive || this.sleeping || this.isHome || !this.attached) {
      return;
    }
    try {
      this.controller.terminateRenderProcess();
    } catch (err) {
      Logger.warn('terminateRenderProcess failed: ' + (err as BusinessError).message);
      return;
    }
    this.sleeping = true;
    this.loading = false;
    this.progress = 0;
    Logger.info('tab ' + this.id + ' sleeping');
  }

  /** Wake a sleeping tab, or build the component of a never-loaded one. */
  revive(): void {
    if (!this.alive) {
      this.alive = true;
      return;
    }
    if (!this.sleeping) {
      return;
    }
    this.sleeping = false;
    this.errorText = '';
    if (this.url.length > 0) {
      Logger.info('tab ' + this.id + ' waking');
      this.navigate(this.url);
    }
  }

  /** Kill the renderer before the component is torn down on close. */
  prepareForClose(): void {
    if (!this.alive || !this.attached || this.sleeping) {
      return;
    }
    try {
      this.controller.terminateRenderProcess();
    } catch (err) {
      Logger.warn('terminateRenderProcess on close: ' + (err as BusinessError).message);
    }
  }

  goHome(): void {
    this.isHome = true;
    this.url = '';
    this.title = 'New tab';
    this.errorText = '';
    this.progress = 0;
    this.loading = false;
  }
}
