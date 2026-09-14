/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Decides where a web download is written and how it reaches somewhere the
 * user can find it.
 *
 * Pictures and videos go to the media library, so they show up in Gallery.
 * A normal app cannot write there on its own - ohos.permission.WRITE_IMAGEVIDEO
 * is system_basic - so the file is staged in the sandbox and handed over only
 * after the user taps a SaveButton, which grants a short-lived authorisation.
 * That tap is a platform requirement, not a design choice.
 *
 * Everything else aims at the public Download folder
 * (/storage/Users/currentUser/Download, a sharefs view of the directory the
 * Files app shows). /storage/Users is DEC-constrained, so the kernel allows it
 * only with ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY, which the stock
 * permission manager offers on PC and tablet alone. We probe for write access
 * rather than asking, and fall back to the sandbox when the answer is no.
 */
import { common } from '@kit.AbilityKit';
import { Environment, fileIo, fileUri, ReadOptions, WriteOptions } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

/** What Environment.getUserDownloadDir() resolves to; it throws 801 unless const.filemanager.full_mount.enable is set. */
const PUBLIC_FALLBACK: string = '/storage/Users/currentUser/Download';
const PROBE_NAME: string = '.oniro_browser_probe';
const MAX_COLLISION_TRIES: number = 100;
const COPY_CHUNK: number = 256 * 1024;
/** Staged pictures the user never saved are dropped after this long. */
const STAGE_MAX_AGE_MS: number = 7 * 24 * 60 * 60 * 1000;

const IMAGE_EXTENSIONS: Array<string> = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif', '.avif'];
const VIDEO_EXTENSIONS: Array<string> = ['.mp4', '.mov', '.mkv', '.webm', '.3gp', '.m4v', '.avi', '.ts'];

export enum DownloadKind {
  IMAGE,
  VIDEO,
  OTHER
}

/** Where a finished download ended up, and what the user can still do with it. */
export class DownloadTarget {
  path: string = '';
  name: string = '';
  kind: DownloadKind = DownloadKind.OTHER;
  /** True when the file already sits somewhere the user can browse to. */
  isPublic: boolean = false;
  /** True when the only thing left is the user tapping Save to Gallery. */
  needsGallerySave: boolean = false;

  constructor(path: string, name: string, kind: DownloadKind, isPublic: boolean, needsGallerySave: boolean) {
    this.path = path;
    this.name = name;
    this.kind = kind;
    this.isPublic = isPublic;
    this.needsGallerySave = needsGallerySave;
  }
}

export class Downloads {
  private static publicWritable: boolean | undefined = undefined;

  /** The public Download folder, however this build of the platform names it. */
  static publicDir(): string {
    try {
      const dir: string = Environment.getUserDownloadDir();
      if (dir.length > 0) {
        return dir;
      }
    } catch (err) {
      Logger.info('getUserDownloadDir unavailable, using default path: ' + (err as BusinessError).message);
    }
    return PUBLIC_FALLBACK;
  }

  /** Sandbox folder for downloads that could not reach the public folder. */
  static privateDir(): string {
    return Downloads.sandboxDir('downloads');
  }

  /** Sandbox folder for pictures and videos waiting to be saved to Gallery. */
  static stagingDir(): string {
    return Downloads.sandboxDir('gallery');
  }

  /** Where a download of this kind should be written. */
  static targetDir(kind: DownloadKind): string {
    if (kind !== DownloadKind.OTHER) {
      return Downloads.stagingDir();
    }
    return Downloads.canUsePublicDir() ? Downloads.publicDir() : Downloads.privateDir();
  }

  static isPublicDir(dir: string): boolean {
    return dir.length > 0 && dir === Downloads.publicDir();
  }

  /** True once the kernel actually lets us write to the public folder. */
  static canUsePublicDir(): boolean {
    if (Downloads.publicWritable === undefined) {
      Downloads.publicWritable = Downloads.probeWritable(Downloads.publicDir());
    }
    return Downloads.publicWritable;
  }

  /** Re-runs the write probe rather than trusting the cached answer. */
  static refreshPublicDir(): boolean {
    Downloads.publicWritable = Downloads.probeWritable(Downloads.publicDir());
    return Downloads.publicWritable;
  }

  /** Pictures and videos are told apart by extension, as the media library does. */
  static kindOf(name: string): DownloadKind {
    const lower: string = name.toLowerCase();
    for (const ext of IMAGE_EXTENSIONS) {
      if (lower.endsWith(ext)) {
        return DownloadKind.IMAGE;
      }
    }
    for (const ext of VIDEO_EXTENSIONS) {
      if (lower.endsWith(ext)) {
        return DownloadKind.VIDEO;
      }
    }
    return DownloadKind.OTHER;
  }

  /** Turns a suggested name or a URL into a safe file name. */
  static safeName(suggested: string, fallback: string): string {
    let name: string = suggested;
    try {
      name = decodeURIComponent(name);
    } catch (err) {
      Logger.info('download name is not percent-encoded: ' + name);
    }
    const slash: number = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    name = name.replace(/[\\:*?"<>|\x00]/g, '_').trim();
    while (name.startsWith('.')) {
      name = name.substring(1);
    }
    if (name.length === 0) {
      return fallback;
    }
    return name.length > 200 ? name.substring(name.length - 200) : name;
  }

  /** dir/name, with "(1)", "(2)"... appended until nothing is overwritten. */
  static uniquePath(dir: string, name: string): string {
    if (!Downloads.exists(dir + '/' + name)) {
      return dir + '/' + name;
    }
    const dot: number = name.lastIndexOf('.');
    const stem: string = dot > 0 ? name.substring(0, dot) : name;
    const ext: string = dot > 0 ? name.substring(dot) : '';
    for (let i = 1; i <= MAX_COLLISION_TRIES; i++) {
      const candidate: string = dir + '/' + stem + '(' + i + ')' + ext;
      if (!Downloads.exists(candidate)) {
        return candidate;
      }
    }
    return dir + '/' + stem + '-' + Date.now() + ext;
  }

  /** Works out what still has to happen to a download that just finished. */
  static settle(path: string): DownloadTarget {
    const name: string = Downloads.safeName(path, 'download.bin');
    const kind: DownloadKind = Downloads.kindOf(name);
    if (path.length === 0) {
      return new DownloadTarget(path, name, kind, false, false);
    }
    if (Downloads.isPublicDir(Downloads.dirOf(path))) {
      return new DownloadTarget(path, name, kind, true, false);
    }
    if (kind !== DownloadKind.OTHER) {
      return new DownloadTarget(path, name, kind, false, true);
    }
    return new DownloadTarget(path, name, kind, false, false);
  }

  /**
   * Hands a staged picture or video to the media library. Only call this from a
   * SaveButton click that reported SUCCESS - the authorisation it grants is
   * short-lived, so there must be no waiting in between.
   */
  static async saveToGallery(path: string): Promise<boolean> {
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) {
      return false;
    }
    const kind: DownloadKind = Downloads.kindOf(path);
    if (kind === DownloadKind.OTHER) {
      Logger.warn('refusing to put a non-media file in the gallery: ' + path);
      return false;
    }
    try {
      const uri: string = fileUri.getUriFromPath(path);
      const request: photoAccessHelper.MediaAssetChangeRequest = kind === DownloadKind.IMAGE
        ? photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, uri)
        : photoAccessHelper.MediaAssetChangeRequest.createVideoAssetRequest(context, uri);
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      await helper.applyChanges(request);
      Downloads.discard(path);
      return true;
    } catch (err) {
      Logger.warn('save to gallery failed: ' + (err as BusinessError).message);
      return false;
    }
  }

  /**
   * Moves anything an earlier run left in the sandbox into the public folder.
   * Only touches non-media downloads; staged pictures belong to the user's
   * pending Save to Gallery and must stay put.
   */
  static async sweepPending(): Promise<number> {
    Downloads.pruneStaged();
    const dir: string = Downloads.privateDir();
    if (dir.length === 0 || !Downloads.refreshPublicDir()) {
      return 0;
    }
    let names: Array<string> = [];
    try {
      names = fileIo.listFileSync(dir);
    } catch (err) {
      Logger.warn('cannot list pending downloads: ' + (err as BusinessError).message);
      return 0;
    }
    let moved: number = 0;
    for (const name of names) {
      if (Downloads.moveToPublic(dir + '/' + name, name)) {
        moved++;
      }
    }
    if (moved > 0) {
      Logger.info('moved ' + moved + ' earlier download(s) to the public folder');
    }
    return moved;
  }

  /** Drops staged pictures the user never got round to saving. */
  static pruneStaged(): number {
    const dir: string = Downloads.stagingDir();
    if (dir.length === 0) {
      return 0;
    }
    const cutoff: number = Date.now() - STAGE_MAX_AGE_MS;
    let dropped: number = 0;
    try {
      for (const name of fileIo.listFileSync(dir)) {
        const path: string = dir + '/' + name;
        const stat: fileIo.Stat = fileIo.statSync(path);
        if (stat.mtime * 1000 < cutoff) {
          Downloads.discard(path);
          dropped++;
        }
      }
    } catch (err) {
      Logger.info('could not prune staged downloads: ' + (err as BusinessError).message);
    }
    if (dropped > 0) {
      Logger.info('dropped ' + dropped + ' stale staged download(s)');
    }
    return dropped;
  }

  private static moveToPublic(path: string, name: string): boolean {
    const target: string = Downloads.uniquePath(Downloads.publicDir(), Downloads.safeName(name, 'download.bin'));
    if (!Downloads.copyStream(path, target)) {
      return false;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (err) {
      Logger.warn('copied but could not remove the sandbox file: ' + (err as BusinessError).message);
    }
    return true;
  }

  private static sandboxDir(leaf: string): string {
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) {
      return '';
    }
    const dir: string = context.filesDir + '/' + leaf;
    return Downloads.ensureDir(dir) ? dir : '';
  }

  /**
   * Buffered copy. fileIo.copyFile() goes through sendfile(), which the sharefs
   * mount behind the public folder rejects with EINVAL after creating an empty
   * destination, so plain read/write is the only thing that works here.
   */
  private static copyStream(src: string, dest: string): boolean {
    let from: fileIo.File | undefined = undefined;
    let to: fileIo.File | undefined = undefined;
    try {
      from = fileIo.openSync(src, fileIo.OpenMode.READ_ONLY);
      to = fileIo.openSync(dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      const buffer: ArrayBuffer = new ArrayBuffer(COPY_CHUNK);
      let offset: number = 0;
      while (true) {
        const readOptions: ReadOptions = { offset: offset, length: COPY_CHUNK };
        const read: number = fileIo.readSync(from.fd, buffer, readOptions);
        if (read <= 0) {
          break;
        }
        const writeOptions: WriteOptions = { offset: offset, length: read };
        fileIo.writeSync(to.fd, buffer, writeOptions);
        offset += read;
      }
      return true;
    } catch (err) {
      Logger.warn('could not move download to public folder: ' + (err as BusinessError).message);
      Downloads.discard(dest);
      return false;
    } finally {
      Downloads.closeQuietly(from);
      Downloads.closeQuietly(to);
    }
  }

  private static closeQuietly(file: fileIo.File | undefined): void {
    if (file === undefined) {
      return;
    }
    try {
      fileIo.closeSync(file);
    } catch (err) {
      Logger.info('close failed: ' + (err as BusinessError).message);
    }
  }

  /** Removes a file so a half-written one never masquerades as a download. */
  private static discard(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (err) {
      Logger.info('nothing to discard at ' + path);
    }
  }

  private static dirOf(path: string): string {
    const slash: number = path.lastIndexOf('/');
    return slash > 0 ? path.substring(0, slash) : '';
  }

  private static exists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (err) {
      return false;
    }
  }

  private static ensureDir(dir: string): boolean {
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
      return true;
    } catch (err) {
      Logger.warn('cannot create ' + dir + ': ' + (err as BusinessError).message);
      return false;
    }
  }

  /** accessSync() answers DAC, not DEC - only a real open tells us the truth. */
  private static probeWritable(dir: string): boolean {
    const probe: string = dir + '/' + PROBE_NAME;
    try {
      const file: fileIo.File = fileIo.openSync(probe, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.closeSync(file);
      fileIo.unlinkSync(probe);
      return true;
    } catch (err) {
      Logger.info('public download folder not writable: ' + (err as BusinessError).message);
      return false;
    }
  }
}
