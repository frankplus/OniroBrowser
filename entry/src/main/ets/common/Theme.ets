/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */

/** Flat colour palette; one instance for light, one for dark. */
export class Palette {
  bg: string = '';
  surface: string = '';
  surfaceAlt: string = '';
  chrome: string = '';
  text: string = '';
  textDim: string = '';
  border: string = '';
  accent: string = '';
  accentDim: string = '';
  danger: string = '';
  scrim: string = '';

  constructor(bg: string, surface: string, surfaceAlt: string, chrome: string, text: string, textDim: string,
              border: string, accent: string, accentDim: string, danger: string, scrim: string) {
    this.bg = bg;
    this.surface = surface;
    this.surfaceAlt = surfaceAlt;
    this.chrome = chrome;
    this.text = text;
    this.textDim = textDim;
    this.border = border;
    this.accent = accent;
    this.accentDim = accentDim;
    this.danger = danger;
    this.scrim = scrim;
  }
}

const LIGHT: Palette = new Palette(
  '#F1F3F5', // bg
  '#FFFFFF', // surface
  '#E9ECF1', // surfaceAlt
  '#FFFFFF', // chrome
  '#17191C', // text
  '#6B7280', // textDim
  '#DDE1E6', // border
  '#2F6FED', // accent
  '#E4EDFD', // accentDim
  '#D93025', // danger
  '#66000000' // scrim
);

const DARK: Palette = new Palette(
  '#101215',
  '#191C21',
  '#22262C',
  '#15181C',
  '#E8EAED',
  '#9AA0A6',
  '#2A2F36',
  '#7FA9FF',
  '#1D2A44',
  '#F28B82',
  '#99000000'
);

export class Theme {
  static of(isDark: boolean): Palette {
    return isDark ? DARK : LIGHT;
  }
}

/** Layout constants, in vp. */
export class Metrics {
  static readonly CHROME_HEIGHT: number = 52;
  static readonly TOOLBAR_HEIGHT: number = 54;
  static readonly RADIUS: number = 12;
  static readonly ICON: number = 22;
}
