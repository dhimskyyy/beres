'use client';

import { useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';

function RootRedirect() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const code = searchParams.get('code');
      if (code) {
        router.replace(`/auth/reset-password?code=${code}`);
        return;
      }

      const error = searchParams.get('error');
      const errorCode = searchParams.get('error_code');
      const errorDesc = searchParams.get('error_description');
      if (error || errorCode) {
        const query = new URLSearchParams();
        if (error) query.set('error', error);
        if (errorCode) query.set('error_code', errorCode);
        if (errorDesc) query.set('error_description', errorDesc);
        router.replace(`/auth/reset-password?${query.toString()}`);
        return;
      }

      // Cek apakah ada hash token recovery
      if (window.location.hash.includes('access_token=') || window.location.hash.includes('type=recovery')) {
        router.replace(`/auth/reset-password${window.location.hash}`);
        return;
      }

      const isMfa = localStorage.getItem('beres_admin_mfa_verified');
      if (isMfa) {
        router.replace('/dashboard');
      } else {
        router.replace('/auth/login');
      }
    }
  }, [router, searchParams]);

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
      Memuat Beres Admin Console...
    </div>
  );
}

export default function RootPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
          Memuat Beres Admin Console...
        </div>
      }
    >
      <RootRedirect />
    </Suspense>
  );
}
