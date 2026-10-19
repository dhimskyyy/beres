'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const isMfa = localStorage.getItem('beres_admin_mfa_verified');
      if (isMfa) {
        router.replace('/dashboard');
      } else {
        router.replace('/auth/login');
      }
    }
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
      Memuat Beres Admin Console...
    </div>
  );
}
