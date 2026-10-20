'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import {
  Users,
  AlertTriangle,
  CheckCircle,
  TrendingUp,
  DollarSign,
  Star,
  Activity,
  Layers,
  History,
  RefreshCw,
} from 'lucide-react';

interface AnalyticsData {
  total_jobs: number;
  completed_jobs: number;
  completion_rate_percent: number;
  total_volume_idr: number;
  total_users: number;
  total_tukangs: number;
  online_tukangs: number;
  active_disputes: number;
  active_strikes: number;
  avg_rating: number;
  status_distribution: Record<string, number>;
  category_distribution: Array<{ name: string; count: number }>;
  recent_audit_logs: Array<{
    id: number;
    action: string;
    target_type: string;
    target_id?: string;
    metadata?: Record<string, unknown>;
    created_at: string;
    actor_name?: string;
    actor_email?: string;
  }>;
}

const ALL_10_STATUSES = [
  { key: 'OPEN', label: 'Bursa Terbuka', color: 'text-blue-400', bg: 'bg-blue-500/10 border-blue-500/30' },
  { key: 'NEGOTIATING', label: 'Negosiasi Chat', color: 'text-amber-400', bg: 'bg-amber-500/10 border-amber-500/30' },
  { key: 'NOTA_APPROVED', label: 'Nota Disetujui', color: 'text-purple-400', bg: 'bg-purple-500/10 border-purple-500/30' },
  { key: 'ON_THE_WAY', label: 'Tukang Menuju Lokasi', color: 'text-cyan-400', bg: 'bg-cyan-500/10 border-cyan-500/30' },
  { key: 'ARRIVED', label: 'Tukang Tiba di Lokasi', color: 'text-indigo-400', bg: 'bg-indigo-500/10 border-indigo-500/30' },
  { key: 'WORKING', label: 'Pekerjaan Berjalan', color: 'text-orange-400', bg: 'bg-orange-500/10 border-orange-500/30' },
  { key: 'COMPLETED', label: 'Pekerjaan Selesai', color: 'text-emerald-400', bg: 'bg-emerald-500/10 border-emerald-500/30' },
  { key: 'CANCEL_PENDING', label: 'Pengajuan Batal', color: 'text-red-400', bg: 'bg-red-500/10 border-red-500/30' },
  { key: 'CANCELLED', label: 'Dibatalkan', color: 'text-slate-400', bg: 'bg-slate-500/10 border-slate-500/30' },
  { key: 'EXPIRED', label: 'Kedaluwarsa (24 Jam)', color: 'text-zinc-400', bg: 'bg-zinc-500/10 border-zinc-500/30' },
];

export default function DashboardOverviewPage() {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  const loadAnalytics = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('rpc_admin_get_analytics_summary');
      if (error) throw error;
      setAnalytics(data as AnalyticsData);
    } catch (err) {
      console.error('Gagal mengambil ringkasan analitik:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAnalytics();
  }, [loadAnalytics]);

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="bg-gradient-to-r from-blue-900/60 via-slate-900 to-slate-900 border border-blue-500/30 rounded-2xl p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Activity className="w-5 h-5 text-blue-400" /> Dashboard Operasional & Analitik Beres
          </h1>
          <p className="text-slate-300 text-xs mt-1 max-w-2xl">
            Sistem pengawasan terpusat: siklus 10 status pekerjaan, analitik volume transaksi jasa langsung, mitigasi sengketa pembayaran (BR-67), dan audit kepatuhan (FR-031, FR-036).
          </p>
        </div>
        <button
          onClick={loadAnalytics}
          className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-lg border border-slate-700 flex items-center gap-1.5 transition-colors"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          Segarkan Metrik
        </button>
      </div>

      {/* 4 Kartu KPI Utama */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Total Selesai & Volume */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 font-medium">Pekerjaan Selesai</span>
            <div className="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <CheckCircle className="w-4 h-4 text-emerald-400" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-2xl font-bold text-white font-mono">
              {loading ? '...' : analytics?.completed_jobs ?? 0}
            </span>
            <span className="text-xs text-slate-400">
              dari {loading ? '...' : analytics?.total_jobs ?? 0} total ({analytics?.completion_rate_percent ?? 0}%)
            </span>
          </div>
          <div className="text-[11px] text-emerald-400/90 flex items-center gap-1 font-mono pt-1 border-t border-slate-800">
            <DollarSign className="w-3.5 h-3.5" />
            Vol: Rp {loading ? '...' : (analytics?.total_volume_idr ?? 0).toLocaleString('id-ID')}
          </div>
        </div>

        {/* Card 2: Mitra Online & Total Mitra */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 font-medium">Mitra Tukang Online</span>
            <div className="w-8 h-8 rounded-lg bg-blue-500/10 flex items-center justify-center">
              <Users className="w-4 h-4 text-blue-400" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-2xl font-bold text-emerald-400 font-mono">
              {loading ? '...' : analytics?.online_tukangs ?? 0}
            </span>
            <span className="text-xs text-slate-400">
              dari {loading ? '...' : analytics?.total_tukangs ?? 0} tukang terdaftar
            </span>
          </div>
          <div className="text-[11px] text-slate-400 flex items-center gap-1 pt-1 border-t border-slate-800">
            Pelanggan (User): <span className="font-bold text-white">{analytics?.total_users ?? 0} akun</span>
          </div>
        </div>

        {/* Card 3: Sengketa Pembayaran & Strike Aktif */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 font-medium">Sengketa & Pelanggaran</span>
            <div className="w-8 h-8 rounded-lg bg-red-500/10 flex items-center justify-center">
              <AlertTriangle className="w-4 h-4 text-red-400" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-2xl font-bold text-red-400 font-mono">
              {loading ? '...' : analytics?.active_disputes ?? 0}
            </span>
            <span className="text-xs text-slate-400">Kasus Masalah Bayar (BR-67)</span>
          </div>
          <div className="text-[11px] text-amber-400 flex items-center gap-1 pt-1 border-t border-slate-800 font-mono">
            Strike Aktif: {analytics?.active_strikes ?? 0} poin tercatat
          </div>
        </div>

        {/* Card 4: Kepuasan Pelanggan */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-400 font-medium">Rating Kepuasan Mitra</span>
            <div className="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center">
              <Star className="w-4 h-4 text-amber-400 fill-amber-400" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-2xl font-bold text-white font-mono">
              {loading ? '...' : analytics?.avg_rating ? `${analytics.avg_rating} / 5` : '5.0 / 5'}
            </span>
            <span className="text-xs text-slate-400">Ulasan Mitra</span>
          </div>
          <div className="text-[11px] text-slate-400 flex items-center gap-1 pt-1 border-t border-slate-800">
            Penilaian Transparan FR-021
          </div>
        </div>
      </div>

      {/* SEKSI 1: BREAKDOWN 10 STATUS PEKERJAAN (FR-036) */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-blue-400" />
            <h2 className="text-sm font-bold text-white">Sebaran Siklus 10 Status Pekerjaan</h2>
          </div>
          <span className="text-xs text-slate-400">Total: {analytics?.total_jobs ?? 0} Order</span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
          {ALL_10_STATUSES.map((st) => {
            const count = analytics?.status_distribution?.[st.key] ?? 0;
            return (
              <div
                key={st.key}
                className={`p-3 rounded-lg border ${st.bg} space-y-1 transition-all hover:scale-[1.02]`}
              >
                <div className="text-[10px] text-slate-400 uppercase tracking-wider font-semibold truncate">
                  {st.label}
                </div>
                <div className="flex items-baseline justify-between">
                  <span className={`text-lg font-bold font-mono ${st.color}`}>
                    {loading ? '...' : count}
                  </span>
                  <span className="text-[10px] text-slate-500 font-mono">
                    {st.key}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* SEKSI 2: KATEGORI TERPOPULER & LOG AUDIT SISTEM */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Kategori Terpopuler */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
          <div className="flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-blue-400" />
            <h2 className="text-sm font-bold text-white">Kategori Layanan Terpopuler</h2>
          </div>

          <div className="space-y-2.5">
            {loading ? (
              <div className="text-center py-8 text-slate-500 text-xs">Memuat kategori...</div>
            ) : (analytics?.category_distribution?.length ?? 0) === 0 ? (
              <div className="text-center py-8 text-slate-500 text-xs">Belum ada order per kategori.</div>
            ) : (
              analytics!.category_distribution.map((cat, idx) => {
                const total = analytics?.total_jobs || 1;
                const percent = Math.round((cat.count / total) * 100);
                return (
                  <div key={idx} className="space-y-1">
                    <div className="flex justify-between text-xs text-slate-300">
                      <span className="font-medium">{cat.name}</span>
                      <span className="font-mono text-slate-400">{cat.count} order ({percent}%)</span>
                    </div>
                    <div className="w-full bg-slate-950 rounded-full h-2 overflow-hidden border border-slate-800">
                      <div
                        className="bg-blue-500 h-full rounded-full transition-all"
                        style={{ width: `${Math.max(percent, cat.count > 0 ? 5 : 0)}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Log Audit Aktivitas Sistem (FR-031) */}
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
          <div className="flex items-center gap-2">
            <History className="w-4 h-4 text-emerald-400" />
            <h2 className="text-sm font-bold text-white">Audit Log Operasional Terkini</h2>
          </div>

          <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
            {loading ? (
              <div className="text-center py-8 text-slate-500 text-xs">Memuat log...</div>
            ) : (analytics?.recent_audit_logs?.length ?? 0) === 0 ? (
              <div className="text-center py-8 text-slate-500 text-xs">
                Belum ada aktivitas administratif tercatat di audit log.
              </div>
            ) : (
              analytics!.recent_audit_logs.map((log) => (
                <div
                  key={log.id}
                  className="p-2.5 bg-slate-950 rounded-lg border border-slate-800/80 text-xs space-y-1"
                >
                  <div className="flex items-center justify-between text-[11px]">
                    <span className="font-mono font-bold text-emerald-400">{log.action}</span>
                    <span className="text-[10px] text-slate-500">
                      {new Date(log.created_at).toLocaleString('id-ID')}
                    </span>
                  </div>
                  <div className="text-slate-300 text-[11px]">
                    Oleh: <span className="font-semibold text-white">{log.actor_name || 'Admin'}</span> ({log.actor_email || '-'})
                  </div>
                  {log.metadata && (
                    <div className="text-[10px] font-mono text-slate-500 truncate">
                      {JSON.stringify(log.metadata)}
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
