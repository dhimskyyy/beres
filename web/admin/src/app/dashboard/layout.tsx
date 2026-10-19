'use client';

import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import {
  Shield,
  LayoutDashboard,
  MapPin,
  Briefcase,
  AlertTriangle,
  FileCheck,
  Users,
  Settings,
  LogOut,
  Lock,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface NavItem {
  label: string;
  href: string;
  icon: React.ElementType;
  badge?: string;
}

const navItems: NavItem[] = [
  { label: 'Ringkasan', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Live Map GPS', href: '/dashboard/live-map', icon: MapPin },
  { label: '10 Status Pekerjaan', href: '/dashboard/jobs', icon: Briefcase },
  {
    label: 'Masalah Pembayaran',
    href: '/dashboard/payment-reports',
    icon: AlertTriangle,
    badge: 'BR-67',
  },
  { label: 'Verifikasi KYC', href: '/dashboard/kyc', icon: FileCheck },
  { label: 'Manajemen Akun & Suspend', href: '/dashboard/accounts', icon: Users },
  { label: 'Kategori & Parameter', href: '/dashboard/categories', icon: Settings },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [adminEmail, setAdminEmail] = useState<string>('admin@beres.id');
  const [isAuthorized, setIsAuthorized] = useState<boolean>(false);

  useEffect(() => {
    // Cek otorisasi MFA admin di localStorage
    if (typeof window !== 'undefined') {
      const isMfa = localStorage.getItem('beres_admin_mfa_verified');
      const email = localStorage.getItem('beres_admin_email');
      if (!isMfa) {
        router.push('/auth/login');
      } else {
        setIsAuthorized(true);
        if (email) setAdminEmail(email);
      }
    }
  }, [router]);

  const handleLogout = async () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('beres_admin_mfa_verified');
      localStorage.removeItem('beres_admin_email');
    }
    await supabase.auth.signOut();
    router.push('/auth/login');
  };

  if (!isAuthorized) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
        Memverifikasi otorisasi Admin MFA...
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 border-r border-slate-800 flex flex-col shrink-0">
        <div className="p-5 border-b border-slate-800 flex items-center gap-3">
          <div className="w-9 h-9 bg-blue-600/20 border border-blue-500/30 rounded-xl flex items-center justify-center">
            <Shield className="w-5 h-5 text-blue-400" />
          </div>
          <div>
            <h2 className="font-bold text-sm tracking-tight text-white">Beres Admin</h2>
            <div className="flex items-center gap-1 text-[11px] text-emerald-400 font-medium">
              <Lock className="w-3 h-3" /> MFA Active (v1.4.0)
            </div>
          </div>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <a
                key={item.href}
                href={item.href}
                className={`flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-colors ${
                  isActive
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`}
              >
                <div className="flex items-center gap-3">
                  <Icon className="w-4 h-4 shrink-0" />
                  <span>{item.label}</span>
                </div>
                {item.badge && (
                  <span
                    className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                      isActive ? 'bg-white/20 text-white' : 'bg-red-500/20 text-red-400'
                    }`}
                  >
                    {item.badge}
                  </span>
                )}
              </a>
            );
          })}
        </nav>

        {/* User Info & Logout */}
        <div className="p-4 border-t border-slate-800 bg-slate-900/60">
          <div className="mb-3">
            <div className="text-xs font-medium text-slate-400">Login Administrator:</div>
            <div className="text-xs font-semibold text-white truncate">{adminEmail}</div>
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-3 py-2 bg-slate-800 hover:bg-red-500/20 hover:text-red-300 text-slate-300 text-xs font-semibold rounded-lg transition-colors border border-slate-700 hover:border-red-500/30"
          >
            <LogOut className="w-3.5 h-3.5" /> Keluar Sesi
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col min-w-0 overflow-y-auto">
        <header className="h-14 border-b border-slate-800 bg-slate-900/50 backdrop-blur px-6 flex items-center justify-between shrink-0">
          <div className="text-xs font-medium text-slate-400">
            Ekosistem Beres — Standar Spesifikasi Mutlak PRD v1.4.0
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-emerald-400 font-medium">PostGIS & Realtime Ready</span>
          </div>
        </header>
        <div className="p-6">{children}</div>
      </main>
    </div>
  );
}
