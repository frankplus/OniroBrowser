/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0xB0;
const TAG: string = 'OniroBrowser';

export class Logger {
  static info(msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
  }

  static warn(msg: string): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', msg);
  }

  static error(msg: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', msg);
  }
}
