'use client';

import React, { useState, useEffect } from 'react';
import { Users, Search, AlertOctagon, CheckCircle2 } from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface AccountRow {
  id: string;
  email: string;
  role: 'USER' | 'TUKANG';
  fullName: string;
  phone: string;
  strikes: number;
  suspendType: 'NONE' | 'AUTO_2_DAYS' | 'MANUAL_PERMANENT';
  suspendedUntil?: string;
  suspendReason?: string;
}

const mockAccounts: AccountRow[] = [
  {
    id: 'usr-1',
    email: 'hendra.gunawan@gmail.com',
    role: 'USER',
    fullName: 'Hendra Gunawan',
    phone: '081234567890',
    strikes: 1,
    suspendType: 'NONE',
  },
  {
    id: 'tkg-1',
    email: 'budi.santoso@gmail.com',
    role: 'TUKANG',
    fullName: 'Budi Santoso',
    phone: '081298765432',
    strikes: 2,
    suspendType: 'NONE',
  },
  {
    id: 'tkg-2',
    email: 'rudi.hartono@gmail.com',
    role: 'TUKANG',
    fullName: 'Rudi Hartono',
    phone: '081311223344',
    strikes: 4,
    suspendType: 'AUTO_2_DAYS',
    suspendedUntil: '2026-10-21T14:30:00Z',
    suspendReason: 'Terkena sanksi otomatis 2 hari karena telah melampaui 3x strike dalam bulan ini (BR-42b).',
  },
  {
    id: 'usr-2',
    email: 'farhan.badpay@gmail.com',
    role: 'USER',
    fullName: 'Farhan Maulana',
    phone: '081988776655',
    strikes: 0,
    suspendType: 'MANUAL_PERMANENT',
    suspendReason: 'Vonis bersalah laporan masalah pembayaran (BR-67). Menolak membayar hasil kerja tukang.',
  },
];

export default function AccountsManagementPage() {
  const [accounts, setAccounts] = useState<AccountRow[]>(mockAccounts);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedRole, setSelectedRole] = useState<'ALL' | 'USER' | 'TUKANG'>('ALL');
  const [selectedSuspend, setSelectedSuspend] = useState<'ALL' | 'SUSPENDED' | 'ACTIVE'>('ALL');

  const isUuid = (str: string) =>
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);

  useEffect(() => {
    async function fetchAccounts() {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('id, email, role, full_name, phone, suspend_type, suspended_until, suspend_reason')
          .order('created_at', { ascending: false });

        if (!error && data && data.length > 0) {
          const mapped: AccountRow[] = data
            .filter((p: { role: string }) => p.role === 'USER' || p.role === 'TUKANG')
            .map((p: {
              id: string;
              email: string;
              role: 'USER' | 'TUKANG';
              full_name: string | null;
              phone: string | null;
              suspend_type: 'NONE' | 'AUTO_2_DAYS' | 'MANUAL_PERMANENT' | null;
              suspended_until: string | null;
              suspend_reason: string | null;
            }) => ({
              id: p.id,
              email: p.email,
              role: p.role,
              fullName: p.full_name || 'Tanpa Nama',
              phone: p.phone || '-',
              strikes: 0,
              suspendType: p.suspend_type || 'NONE',
              suspendedUntil: p.suspended_until || undefined,
              suspendReason: p.suspend_reason || undefined,
            }));
          setAccounts(mapped);
        }
      } catch {
        // Fallback ke mock
      }
    }
    fetchAccounts();
  }, []);

  const filtered = accounts.filter((acc) => {
    const matchSearch =
      acc.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      acc.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      acc.phone.includes(searchTerm);
    const matchRole = selectedRole === 'ALL' || acc.role === selectedRole;
    const matchSuspend =
      selectedSuspend === 'ALL' ||
      (selectedSuspend === 'SUSPENDED' && acc.suspendType !== 'NONE') ||
      (selectedSuspend === 'ACTIVE' && acc.suspendType === 'NONE');
    return matchSearch && matchRole && matchSuspend;
  });

  const handleRevokeSuspend = async (id: string) => {
    setAccounts((prev) =>
      prev.map((acc) =>
        acc.id === id
          ? { ...acc, suspendType: 'NONE', suspendedUntil: undefined, suspendReason: undefined }
          : acc
      )
    );

    try {
      if (isUuid(id)) {
        await supabase
          .from('profiles')
          .update({
            suspend_type: 'NONE',
            suspended_until: null,
            suspend_reason: null,
            updated_at: new Date().toISOString(),
          })
          .eq('id', id);
      }
    } catch {}
  };

  const handleApplyPermanentSuspend = async (id: string) => {
    const reason = prompt('Masukkan alasan wajib suspend permanen Admin:');
    if (!reason || !reason.trim()) return;

    setAccounts((prev) =>
      prev.map((acc) =>
        acc.id === id
          ? {
              ...acc,
              suspendType: 'MANUAL_PERMANENT',
              suspendReason: reason.trim(),
            }
          : acc
      )
    );

    try {
      if (isUuid(id)) {
        await supabase
          .from('profiles')
          .update({
            suspend_type: 'MANUAL_PERMANENT',
            suspend_reason: reason.trim(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', id);
      }
    } catch {}
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Users className="w-6 h-6 text-blue-400" />
          Manajemen Akun, Strike, & Sanksi Suspend
        </h1>
        <p className="text-slate-400 text-xs mt-1">
          Penegakan aturan 1 Email = 1 Peran (BR-44), pantauan Strike tukang/user (BR-57/BR-71), dan kontrol suspend 2 hari / permanen (BR-42).
        </p>
      </div>

      {/* Filter Bar */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 flex flex-wrap items-center justify-between gap-4">
        <div className="relative flex-1 min-w-[240px]">
          <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Cari email, nama, atau no. telepon..."
            className="w-full bg-slate-950 border border-slate-800 rounded-lg pl-10 pr-4 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div className="flex items-center gap-3">
          <select
            value={selectedRole}
            onChange={(e) => setSelectedRole(e.target.value as 'ALL' | 'USER' | 'TUKANG')}
            className="bg-slate-950 border border-slate-800 text-slate-300 text-xs rounded-lg px-3 py-2 focus:outline-none focus:border-blue-500"
          >
            <option value="ALL">Semua Peran</option>
            <option value="USER">Pelanggan (USER)</option>
            <option value="TUKANG">Mitra Tukang (TUKANG)</option>
          </select>

          <select
            value={selectedSuspend}
            onChange={(e) => setSelectedSuspend(e.target.value as 'ALL' | 'SUSPENDED' | 'ACTIVE')}
            className="bg-slate-950 border border-slate-800 text-slate-300 text-xs rounded-lg px-3 py-2 focus:outline-none focus:border-blue-500"
          >
            <option value="ALL">Semua Status</option>
            <option value="ACTIVE">Aktif Normal</option>
            <option value="SUSPENDED">Terkena Suspend</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Pengguna</th>
                <th className="py-3 px-4">Peran (BR-44)</th>
                <th className="py-3 px-4">Kontak</th>
                <th className="py-3 px-4">Akumulasi Strike</th>
                <th className="py-3 px-4">Status Akun (BR-42)</th>
                <th className="py-3 px-4 text-right">Tindakan Admin</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {filtered.map((acc) => (
                <tr key={acc.id} className="hover:bg-slate-800/40 transition-colors">
                  <td className="py-3.5 px-4">
                    <div className="font-semibold text-white">{acc.fullName}</div>
                    <div className="text-[11px] text-slate-400 font-mono">{acc.email}</div>
                  </td>
                  <td className="py-3.5 px-4">
                    <span
                      className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        acc.role === 'USER'
                          ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                          : 'bg-orange-500/20 text-orange-400 border border-orange-500/30'
                      }`}
                    >
                      {acc.role}
                    </span>
                  </td>
                  <td className="py-3.5 px-4 font-mono text-[11px] text-slate-400">
                    {acc.phone}
                  </td>
                  <td className="py-3.5 px-4">
                    <span
                      className={`font-mono font-bold px-2 py-0.5 rounded text-[11px] ${
                        acc.strikes >= 4
                          ? 'bg-red-500/20 text-red-400'
                          : acc.strikes >= 2
                          ? 'bg-amber-500/20 text-amber-400'
                          : 'bg-slate-800 text-slate-400'
                      }`}
                    >
                      {acc.strikes} / 3 strike
                    </span>
                  </td>
                  <td className="py-3.5 px-4">
                    {acc.suspendType === 'NONE' && (
                      <span className="inline-flex items-center gap-1 text-emerald-400 font-medium">
                        <CheckCircle2 className="w-3.5 h-3.5" /> Aktif
                      </span>
                    )}
                    {acc.suspendType === 'AUTO_2_DAYS' && (
                      <div>
                        <span className="inline-flex items-center gap-1 text-amber-400 font-bold">
                          <AlertOctagon className="w-3.5 h-3.5" /> Suspend 2 Hari (Auto)
                        </span>
                        <div className="text-[10px] text-slate-400 mt-0.5 truncate max-w-xs">
                          {acc.suspendReason}
                        </div>
                      </div>
                    )}
                    {acc.suspendType === 'MANUAL_PERMANENT' && (
                      <div>
                        <span className="inline-flex items-center gap-1 text-red-400 font-bold">
                          <AlertOctagon className="w-3.5 h-3.5" /> Suspend Permanen
                        </span>
                        <div className="text-[10px] text-red-300 mt-0.5 truncate max-w-xs">
                          {acc.suspendReason}
                        </div>
                      </div>
                    )}
                  </td>
                  <td className="py-3.5 px-4 text-right">
                    {acc.suspendType !== 'NONE' ? (
                      <button
                        onClick={() => handleRevokeSuspend(acc.id)}
                        className="px-2.5 py-1 bg-emerald-600/20 hover:bg-emerald-600 text-emerald-300 hover:text-white rounded text-[11px] font-semibold border border-emerald-500/30 transition-colors"
                      >
                        Cabut Suspend
                      </button>
                    ) : (
                      <button
                        onClick={() => handleApplyPermanentSuspend(acc.id)}
                        className="px-2.5 py-1 bg-red-600/20 hover:bg-red-600 text-red-300 hover:text-white rounded text-[11px] font-semibold border border-red-500/30 transition-colors"
                      >
                        Suspend Permanen
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
