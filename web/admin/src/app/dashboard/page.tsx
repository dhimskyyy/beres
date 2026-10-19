'use client';

import React from 'react';
import { Users, Briefcase, AlertTriangle, ShieldCheck, Clock, CheckCircle } from 'lucide-react';

export default function DashboardOverviewPage() {
  const stats = [
    { label: 'Pekerjaan Aktif (Bursa & Berjalan)', value: '18', icon: Briefcase, color: 'text-blue-400', bg: 'bg-blue-500/10' },
    { label: 'Mitra Tukang Online', value: '42', icon: Users, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    { label: 'Antrean Laporan Pembayaran (BR-67)', value: '1', icon: AlertTriangle, color: 'text-red-400', bg: 'bg-red-500/10' },
    { label: 'Verifikasi KYC Pending', value: '7', icon: ShieldCheck, color: 'text-amber-400', bg: 'bg-amber-500/10' },
  ];

  const recentIncidents = [
    {
      id: 'JOB-9021',
      title: 'Laporan Pembayaran Masalah (BR-67)',
      actor: 'Tukang: Budi Santoso',
      against: 'User: Hendra Gunawan',
      time: '12 menit lalu',
      severity: 'PRIORITAS TINGGI',
    },
    {
      id: 'ACC-4102',
      title: 'Suspend Otomatis 2 Hari (> 3x Strike)',
      actor: 'Mitra: Rudi Hartono',
      against: 'Strike ke-4 (Depart Timeout 30m)',
      time: '1 jam lalu',
      severity: 'AUTO SUSPEND',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="bg-gradient-to-r from-blue-900/50 to-slate-900 border border-blue-500/30 rounded-2xl p-6">
        <h1 className="text-xl font-bold text-white">Dashboard Operasional Beres</h1>
        <p className="text-slate-300 text-sm mt-1 max-w-2xl">
          Pengawasan 10 status pekerjaan, antrean prioritas sanksi pembayaran (BR-67), penegakan 1 Email = 1 Peran (BR-44), dan audit log kepatuhan.
        </p>
      </div>

      {/* Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((s, idx) => {
          const Icon = s.icon;
          return (
            <div key={idx} className="bg-slate-900 border border-slate-800 rounded-xl p-5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-medium text-slate-400">{s.label}</span>
                <div className={`w-9 h-9 ${s.bg} rounded-lg flex items-center justify-center`}>
                  <Icon className={`w-5 h-5 ${s.color}`} />
                </div>
              </div>
              <div className="text-2xl font-bold text-white font-mono">{s.value}</div>
            </div>
          );
        })}
      </div>

      {/* Incidents & Operational Audits */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-400" />
              Insiden Operasional & Sanksi Aktif
            </h3>
            <span className="text-xs text-slate-400">Real-time</span>
          </div>
          <div className="space-y-3">
            {recentIncidents.map((inc, i) => (
              <div key={i} className="p-3.5 bg-slate-800/60 border border-slate-700/60 rounded-xl text-xs space-y-1">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-white">{inc.id} — {inc.title}</span>
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-red-500/20 text-red-400">
                    {inc.severity}
                  </span>
                </div>
                <div className="text-slate-300">{inc.actor} ↔ {inc.against}</div>
                <div className="text-slate-500 text-[11px] flex items-center gap-1">
                  <Clock className="w-3 h-3" /> {inc.time}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <CheckCircle className="w-4 h-4 text-emerald-400" />
              Integritas Sistem & Aturan Mutlak v1.4.0
            </h3>
            <span className="text-xs text-emerald-400 font-semibold">Active Enforced</span>
          </div>
          <ul className="space-y-2 text-xs text-slate-300">
            <li className="flex items-start gap-2 p-2 bg-slate-800/40 rounded-lg">
              <span className="text-emerald-400 font-bold shrink-0">BR-44:</span>
              <span>1 Email = 1 Peran ditegakkan via PostgreSQL constraint & RPC check.</span>
            </li>
            <li className="flex items-start gap-2 p-2 bg-slate-800/40 rounded-lg">
              <span className="text-emerald-400 font-bold shrink-0">BR-45:</span>
              <span>Hapus Akun dilindungi validasi job aktif & sengketa berjalan sesuai UU PDP.</span>
            </li>
            <li className="flex items-start gap-2 p-2 bg-slate-800/40 rounded-lg">
              <span className="text-emerald-400 font-bold shrink-0">BR-42:</span>
              <span>Suspend Otomatis 2 Hari (&gt; 3x Strike) &amp; Suspend Permanen Admin aktif.</span>
            </li>
            <li className="flex items-start gap-2 p-2 bg-slate-800/40 rounded-lg">
              <span className="text-emerald-400 font-bold shrink-0">FR-037:</span>
              <span>Akses dashboard Web Admin terkunci MFA (Email + Password + OTP 2 Langkah).</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
