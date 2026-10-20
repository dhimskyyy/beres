'use client';

import { useEffect } from 'react';

/**
 * ExtensionErrorSuppressor:
 * Menangkap dan memblokir uncaught error yang berasal dari browser extension (Chrome/Firefox/Safari extension)
 * agar tidak memicu Next.js Error Overlay / pop-up merah saat development di localhost.
 */
export function ExtensionErrorSuppressor() {
  useEffect(() => {
    if (typeof window === 'undefined') return;

    const isExtensionError = (error: unknown, filename?: string): boolean => {
      const errObj = typeof error === 'object' && error !== null ? (error as Record<string, unknown>) : null;
      const file = filename || (typeof errObj?.filename === 'string' ? errObj.filename : '');
      const stack = typeof errObj?.stack === 'string' ? errObj.stack : '';
      const message =
        typeof errObj?.message === 'string'
          ? errObj.message
          : typeof error === 'string'
            ? error
            : '';

      return (
        file.includes('chrome-extension://') ||
        file.includes('moz-extension://') ||
        file.includes('safari-extension://') ||
        stack.includes('chrome-extension://') ||
        stack.includes('moz-extension://') ||
        message.includes('M_ID') ||
        message.includes("reading 'M_ID'")
      );
    };

    const handleError = (event: ErrorEvent) => {
      if (isExtensionError(event.error, event.filename)) {
        event.preventDefault();
        event.stopImmediatePropagation();
        return true;
      }
    };

    const handleUnhandledRejection = (event: PromiseRejectionEvent) => {
      if (isExtensionError(event.reason)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    };

    window.addEventListener('error', handleError, true);
    window.addEventListener('unhandledrejection', handleUnhandledRejection, true);

    return () => {
      window.removeEventListener('error', handleError, true);
      window.removeEventListener('unhandledrejection', handleUnhandledRejection, true);
    };
  }, []);

  return null;
}
