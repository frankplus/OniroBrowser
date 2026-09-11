/*
 * Copyright (c) 2026 Eclipse Oniro Project
 * SPDX-License-Identifier: Apache-2.0
 */

export enum DialogKind {
  MESSAGE = 0,
  CONFIRM = 1,
  PROMPT = 2,
  SSL = 3,
  PERMISSION = 4
}

/**
 * A modal request raised by web content and rendered in-page by the shell,
 * so the browser never depends on system sub-window dialogs.
 */
export class DialogRequest {
  kind: DialogKind = DialogKind.MESSAGE;
  title: string = '';
  message: string = '';
  defaultValue: string = '';
  confirmLabel: string = 'OK';
  cancelLabel: string = 'Cancel';
  confirm: (text: string) => void = () => {};
  cancel: () => void = () => {};

  constructor(kind: DialogKind, title: string, message: string, confirm: (text: string) => void,
              cancel: () => void, defaultValue: string = '', confirmLabel: string = 'OK',
              cancelLabel: string = 'Cancel') {
    this.kind = kind;
    this.title = title;
    this.message = message;
    this.confirm = confirm;
    this.cancel = cancel;
    this.defaultValue = defaultValue;
    this.confirmLabel = confirmLabel;
    this.cancelLabel = cancelLabel;
  }
}
