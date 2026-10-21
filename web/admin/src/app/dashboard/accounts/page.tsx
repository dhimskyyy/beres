'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Users, Search, AlertOctagon, CheckCircle2, ShieldAlert, X } from 'lucide-react';
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

interface StrikeRecord {
  id: string;
  user_id: string;
  role: string;
  job_id: string;
  strike_type: string;
  description: string;
  is_excused: boolean;
  created_at: string;
  job_description?: string;
}

export default function AccountsManagementPage() {
  const [accounts, setAccounts] = useState<AccountRow[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedRole, setSelectedRole] = useState<'ALL' | 'USER' | 'TUKANG'>('ALL');
  const [selectedSuspend, setSelectedSuspend] = useState<'ALL' | 'SUSPENDED' | 'ACTIVE'>('ALL');

  // Strike Details Modal
  const [selectedAccountForStrikes, setSelectedAccountForStrikes] = useState<AccountRow | null>(null);
  const [accountStrikes, setAccountStrikes] = useState<StrikeRecord[]>([]);
  const [loadingStrikes, setLoadingStrikes] = useState(false);

  const isUuid = (str: string) =>
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);

  const fetchAccounts = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, email, role, full_name, phone, suspend_type, suspended_until, suspend_reason')
        .order('created_at', { ascending: false });

      if (!error && data) {
        // Ambil jumlah strike aktif dari tabel strikes
        const { data: strikesData } = await supabase
          .from('strikes')
          .select('user_id, is_excused')
          .eq('is_excused', false);

        const strikeCountMap = new Map<string, number>();
        strikesData?.forEach((s: { user_id: string }) => {
          strikeCountMap.set(s.user_id, (strikeCountMap.get(s.user_id) || 0) + 1);
        });

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
            strikes: strikeCountMap.get(p.id) || 0,
            suspendType: p.suspend_type || 'NONE',
            suspendedUntil: p.suspended_until || undefined,
            suspendReason: p.suspend_reason || undefined,
          }));
        setAccounts(mapped);
      }
    } catch {
      setAccounts([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAccounts();
  }, [fetchAccounts]);

  const openStrikeHistory = async (acc: AccountRow) => {
    setSelectedAccountForStrikes(acc);
    setLoadingStrikes(true);

    if (isUuid(acc.id)) {
      try {
        const { data } = await supabase.rpc('rpc_get_account_strikes', {
          p_user_id: acc.id,
        });
        setAccountStrikes(data || []);
      } catch {
        setAccountStrikes([]);
      }
    } else {
      // Mock strikes
      setAccountStrikes([
        {
          id: 'mock-str-1',
          user_id: acc.id,
          role: acc.role,
          job_id: 'job-1',
          strike_type: 'TUKANG_CANCEL_APPROVED',
          description: 'Pembatalan sepihak setelah Nota disetujui (BR-55)',
          is_excused: false,
          created_at: new Date().toISOString(),
          job_description: 'Perbaikan atap bocor',
        },
      ]);
    }
    setLoadingStrikes(false);
  };

  const handleExcuseStrike = async (strikeId: string) => {
    const reason = prompt('Masukkan alasan pemberian pengampunan (Excuse) Strike:');
    if (!reason || !reason.trim()) return;

    try {
      if (isUuid(strikeId)) {
        await supabase.rpc('rpc_admin_excuse_strike', {
          p_strike_id: strikeId,
          p_excuse_reason: reason.trim(),
        });
      }

      setAccountStrikes((prev) =>
        prev.map((s) => (s.id === strikeId ? { ...s, is_excused: true } : s))
      );
      await fetchAccounts();
    } catch (e) {
      alert(`Gagal mengampuni strike: ${e}`);
    }
  };

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
        <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
          <Users className="w-5 h-5 text-blue-400" /> Manajemen Akun & Penegakan Suspend
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Pengawasan satu email satu peran (BR-44), monitoring akumulasi Strike (BR-57/BR-71), dan penegakan sanksi Suspend 2 Hari otomatis vs Suspend Permanen.
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
        <div className="relative flex-1 max-w-sm">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari nama, email, no. telp..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-slate-900 border border-slate-800 text-slate-200 text-xs rounded-lg pl-9 pr-3 py-2 focus:outline-none focus:border-blue-500"
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
                <th className="py-3 px-4">Akumulasi Strike (BR-57/71)</th>
                <th className="py-3 px-4">Status Akun (BR-42)</th>
                <th className="py-3 px-4 text-right">Tindakan Admin</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-500">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <div className="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
                      <span>Memuat data akun real-time...</span>
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-500">
                    Tidak ada akun yang sesuai dengan kriteria pencarian.
                  </td>
                </tr>
              ) : (
                filtered.map((acc) => (
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
                    <button
                      onClick={() => openStrikeHistory(acc)}
                      title="Klik untuk melihat riwayat rincian strike"
                      className={`font-mono font-bold px-2.5 py-1 rounded text-[11px] cursor-pointer transition-all hover:scale-105 ${
                        acc.strikes >= 4
                          ? 'bg-red-500/20 text-red-400 border border-red-500/30'
                          : acc.strikes >= 2
                          ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                          : 'bg-slate-800 text-slate-400 border border-slate-700'
                      }`}
                    >
                      {acc.strikes} / 3 strike
                    </button>
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
                  <td className="py-3.5 px-4 text-right space-x-2">
                    <button
                      onClick={() => openStrikeHistory(acc)}
                      className="px-2 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded text-[11px] font-medium border border-slate-700 transition-colors"
                    >
                      Audit Strike
                    </button>
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
              ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Riwayat & Pengampunan Strike (FR-039) */}
      {selectedAccountForStrikes && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-xl max-w-lg w-full p-5 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 text-amber-400" />
                <h3 className="font-bold text-sm text-white">
                  Riwayat Strike: {selectedAccountForStrikes.fullName}
                </h3>
              </div>
              <button
                onClick={() => setSelectedAccountForStrikes(null)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="text-xs text-slate-400">
              Aturan BR-57 & BR-71: Maksimal 3 Strike per bulan kalender lokal. Strike ke-4 memicu pembekuan akun selama 48 jam penuh secara otomatis.
            </div>

            <div className="space-y-2.5 max-h-72 overflow-y-auto">
              {loadingStrikes ? (
                <div className="text-center py-6 text-slate-400 text-xs">Memuat data strike...</div>
              ) : accountStrikes.length === 0 ? (
                <div className="text-center py-6 text-emerald-400 text-xs">
                  Tidak ada catatan pelanggaran (Strike). Akun bersih.
                </div>
              ) : (
                accountStrikes.map((s) => (
                  <div
                    key={s.id}
                    className={`p-3 rounded-lg border text-xs space-y-1.5 ${
                      s.is_excused
                        ? 'bg-slate-950/50 border-slate-800 opacity-60'
                        : 'bg-slate-950 border-amber-500/30'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-mono font-bold text-amber-400">
                        {s.strike_type}
                      </span>
                      <span className="text-[10px] text-slate-400">
                        {new Date(s.created_at).toLocaleString('id-ID')}
                      </span>
                    </div>
                    <div className="text-slate-200">{s.description}</div>
                    {s.job_description && (
                      <div className="text-[11px] text-slate-400 italic">
                        Job: {s.job_description}
                      </div>
                    )}
                    <div className="flex items-center justify-between pt-1">
                      {s.is_excused ? (
                        <span className="text-[10px] text-emerald-400 font-semibold bg-emerald-500/10 px-2 py-0.5 rounded">
                          Diampuni Admin (Excused)
                        </span>
                      ) : (
                        <>
                          <span className="text-[10px] text-red-400 font-semibold bg-red-500/10 px-2 py-0.5 rounded">
                            Strike Aktif
                          </span>
                          <button
                            onClick={() => handleExcuseStrike(s.id)}
                            className="text-[10px] font-semibold text-amber-300 hover:text-white bg-amber-600/20 hover:bg-amber-600 px-2.5 py-1 rounded border border-amber-500/30 transition-colors"
                          >
                            Ampuni Strike
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>

            <div className="pt-2 border-t border-slate-800 text-right">
              <button
                onClick={() => setSelectedAccountForStrikes(null)}
                className="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-lg transition-colors"
              >
                Tutup
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
