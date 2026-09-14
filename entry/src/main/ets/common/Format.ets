/*
 * Copyright (c) 2026 Eclipse Oniro for OpenHarmony contributors.
 * SPDX-License-Identifier: Apache-2.0
 */

const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export class Format {
  private static pad(value: number): string {
    return value < 10 ? '0' + value : value.toString();
  }

  /** Compact, human timestamp for history rows. */
  static timestamp(millis: number): string {
    const then: Date = new Date(millis);
    const now: Date = new Date();
    const clock: string = Format.pad(then.getHours()) + ':' + Format.pad(then.getMinutes());
    const sameDay: boolean = then.getFullYear() === now.getFullYear() && then.getMonth() === now.getMonth() &&
      then.getDate() === now.getDate();
    if (sameDay) {
      return clock;
    }
    const yesterday: Date = new Date(now.getTime() - 86400000);
    const wasYesterday: boolean = then.getFullYear() === yesterday.getFullYear() &&
      then.getMonth() === yesterday.getMonth() && then.getDate() === yesterday.getDate();
    if (wasYesterday) {
      return 'Yesterday ' + clock;
    }
    return then.getDate() + ' ' + MONTHS[then.getMonth()] + ' ' + clock;
  }
}
