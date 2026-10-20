'use client';

import React, { useState, useEffect, useCallback } from 'react';
import {
  MapPin,
  RefreshCw,
  Navigation,
  CheckCircle2,
  Clock,
  Radio,
  ShieldAlert,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface ActiveTrackingLocation {
  job_id: string;
  status: 'ON_THE_WAY' | 'ARRIVED' | 'WORKING';
  description: string;
  area_label: string;
  job_lat: number;
  job_lng: number;
  tukang_id: string;
  tukang_name: string;
  tukang_phone?: string;
  tukang_lat: number;
  tukang_lng: number;
  location_updated_at?: string;
  user_id: string;
  user_name: string;
  distance_meters?: number;
}

const mockLocations: ActiveTrackingLocation[] = [
  {
    job_id: 'job-mock-1',
    status: 'ON_THE_WAY',
    description: 'Bocor pipa wastafel kamar mandi utama dan rembes ke lantai bawah',
    area_label: 'Kebayoran Baru, Jakarta Selatan',
    job_lat: -6.2415,
    job_lng: 106.7984,
    tukang_id: 'tkg-1',
    tukang_name: 'Budi Santoso',
    tukang_phone: '081298765432',
    tukang_lat: -6.2435,
    tukang_lng: 106.8012,
    location_updated_at: new Date(Date.now() - 45000).toISOString(),
    user_id: 'usr-1',
    user_name: 'Hendra Gunawan',
    distance_meters: 380,
  },
  {
    job_id: 'job-mock-2',
    status: 'ARRIVED',
    description: 'Pasang instalasi saklar ganda dan stop kontak tambahan',
    area_label: 'Tebet Timur, Jakarta Selatan',
    job_lat: -6.2289,
    job_lng: 106.8523,
    tukang_id: 'tkg-2',
    tukang_name: 'Rudi Hartono',
    tukang_phone: '081311223344',
    tukang_lat: -6.2291,
    tukang_lng: 106.8525,
    location_updated_at: new Date(Date.now() - 120000).toISOString(),
    user_id: 'usr-3',
    user_name: 'Siti Aminah',
    distance_meters: 35,
  },
  {
    job_id: 'job-mock-3',
    status: 'WORKING',
    description: 'Servis AC 1 PK tidak dingin dan cuci filter indoor & outdoor',
    area_label: 'Menteng, Jakarta Pusat',
    job_lat: -6.1954,
    job_lng: 106.8326,
    tukang_id: 'tkg-3',
    tukang_name: 'Joko Widodo Putra',
    tukang_phone: '081755443322',
    tukang_lat: -6.1954,
    tukang_lng: 106.8326,
    location_updated_at: new Date(Date.now() - 300000).toISOString(),
    user_id: 'usr-4',
    user_name: 'Ahmad Dahlan',
    distance_meters: 5,
  },
];

export default function LiveMapPage() {
  const [locations, setLocations] = useState<ActiveTrackingLocation[]>(mockLocations);
  const [selectedLocation, setSelectedLocation] = useState<ActiveTrackingLocation | null>(mockLocations[0]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [lastRefreshed, setLastRefreshed] = useState<Date>(new Date());
  const [autoRefresh, setAutoRefresh] = useState<boolean>(true);

  const fetchLiveLocations = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase.rpc('rpc_get_live_tracking_locations');
      if (!error && Array.isArray(data) && data.length > 0) {
        setLocations(data as ActiveTrackingLocation[]);
        setSelectedLocation((prev) => {
          if (!prev || !data.some((d: ActiveTrackingLocation) => d.job_id === prev.job_id)) {
            return data[0] as ActiveTrackingLocation;
          }
          return prev;
        });
      }
    } catch {
      // Fallback to mock locations if RPC fails or mock auth
    } finally {
      setIsLoading(false);
      setLastRefreshed(new Date());
    }
  }, []);

  useEffect(() => {
    fetchLiveLocations();
  }, [fetchLiveLocations]);

  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      fetchLiveLocations();
    }, 15000);
    return () => clearInterval(interval);
  }, [autoRefresh, fetchLiveLocations]);

  const onTheWayCount = locations.filter((l) => l.status === 'ON_THE_WAY').length;
  const arrivedCount = locations.filter((l) => l.status === 'ARRIVED').length;
  const workingCount = locations.filter((l) => l.status === 'WORKING').length;

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold tracking-tight text-white">Live Map GPS Tracking</h1>
            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">
              FR-030
            </span>
          </div>
          <p className="text-slate-400 text-sm mt-1">
            Pantau posisi GPS real-time mitra tukang yang sedang bertugas (ON_THE_WAY, ARRIVED, WORKING).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-xs text-slate-400 cursor-pointer bg-slate-900 border border-slate-800 px-3 py-2 rounded-lg">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="rounded bg-slate-800 border-slate-700 text-blue-600 focus:ring-0"
            />
            Auto-refresh 15s
          </label>
          <button
            onClick={fetchLiveLocations}
            disabled={isLoading}
            className="flex items-center gap-2 px-3.5 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-sm font-medium transition-colors shadow-lg shadow-blue-600/20 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
            Segarkan
          </button>
        </div>
      </div>

      {/* Metric Counters */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="flex items-center justify-between text-slate-400 text-xs mb-1">
            <span>Total Aktif Bertugas</span>
            <Radio className="w-4 h-4 text-emerald-400 animate-pulse" />
          </div>
          <div className="text-2xl font-bold text-white">{locations.length}</div>
          <div className="text-[11px] text-slate-500 mt-1">Live pings dalam 10 menit</div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="flex items-center justify-between text-slate-400 text-xs mb-1">
            <span>On The Way</span>
            <Navigation className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-amber-400">{onTheWayCount}</div>
          <div className="text-[11px] text-slate-500 mt-1">Menuju lokasi pekerjaan</div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="flex items-center justify-between text-slate-400 text-xs mb-1">
            <span>Tiba di Lokasi (Arrived)</span>
            <CheckCircle2 className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-blue-400">{arrivedCount}</div>
          <div className="text-[11px] text-slate-500 mt-1">Radius &le; 50m / 200m</div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="flex items-center justify-between text-slate-400 text-xs mb-1">
            <span>Sedang Bekerja (Working)</span>
            <Clock className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-emerald-400">{workingCount}</div>
          <div className="text-[11px] text-slate-500 mt-1">Dilarang dibatalkan (BR-65)</div>
        </div>
      </div>

      {/* Main Grid: Interactive Map Preview + Active Worker List */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left: Active List */}
        <div className="lg:col-span-5 space-y-3">
          <div className="flex items-center justify-between text-xs text-slate-400 font-medium px-1">
            <span>DAFTAR MITRA BERTUGAS ({locations.length})</span>
            <span>Update: {lastRefreshed.toLocaleTimeString()}</span>
          </div>

          <div className="space-y-2 max-h-[560px] overflow-y-auto pr-1">
            {locations.map((loc) => {
              const isSelected = selectedLocation?.job_id === loc.job_id;
              const statusColor =
                loc.status === 'ON_THE_WAY'
                  ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                  : loc.status === 'ARRIVED'
                  ? 'bg-blue-500/10 text-blue-400 border-blue-500/20'
                  : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';

              return (
                <div
                  key={loc.job_id}
                  onClick={() => setSelectedLocation(loc)}
                  className={`p-4 rounded-xl border transition-all cursor-pointer ${
                    isSelected
                      ? 'bg-slate-800/90 border-blue-500 ring-1 ring-blue-500/50'
                      : 'bg-slate-900 border-slate-800 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <h4 className="font-semibold text-sm text-white">{loc.tukang_name}</h4>
                      <p className="text-xs text-slate-400 mt-0.5">Pelanggan: {loc.user_name}</p>
                    </div>
                    <span className={`px-2 py-0.5 rounded text-[11px] font-semibold border ${statusColor}`}>
                      {loc.status}
                    </span>
                  </div>

                  <p className="text-xs text-slate-300 mt-2 line-clamp-1">{loc.description}</p>

                  <div className="flex items-center justify-between text-[11px] text-slate-400 mt-3 pt-2.5 border-t border-slate-800/80">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3 h-3 text-slate-500" />
                      {loc.area_label}
                    </span>
                    <span className="font-medium text-slate-300">
                      Jarak: {loc.distance_meters != null ? `${loc.distance_meters.toFixed(0)} m` : '-'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right: Map Visualizer & Live Coordinates */}
        <div className="lg:col-span-7 bg-slate-900 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between min-h-[560px]">
          {selectedLocation ? (
            <div className="space-y-6">
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full bg-emerald-500 animate-ping" />
                    <h3 className="font-bold text-lg text-white">{selectedLocation.tukang_name}</h3>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Telp: {selectedLocation.tukang_phone || '-'} | Job ID: {selectedLocation.job_id}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-xs text-slate-400">Jarak ke Titik Job</div>
                  <div className="text-lg font-bold text-blue-400">
                    {selectedLocation.distance_meters != null
                      ? `${selectedLocation.distance_meters.toFixed(0)} meter`
                      : 'N/A'}
                  </div>
                </div>
              </div>

              {/* Simulated Graphical Map View */}
              <div className="relative w-full h-72 bg-slate-950 border border-slate-800 rounded-xl overflow-hidden flex items-center justify-center">
                {/* Background Grid Pattern */}
                <div className="absolute inset-0 bg-[linear-gradient(to_right,#1e293b_1px,transparent_1px),linear-gradient(to_bottom,#1e293b_1px,transparent_1px)] bg-[size:2rem_2rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)] opacity-30" />

                {/* Tukang Marker */}
                <div className="relative z-10 flex flex-col items-center">
                  <div className="w-12 h-12 bg-amber-500/20 border-2 border-amber-400 rounded-full flex items-center justify-center animate-bounce shadow-lg shadow-amber-500/30">
                    <Navigation className="w-6 h-6 text-amber-300" />
                  </div>
                  <span className="mt-1.5 px-2 py-0.5 bg-slate-900/90 border border-slate-700 text-amber-300 rounded text-[11px] font-semibold">
                    Tukang: {selectedLocation.tukang_lat.toFixed(4)}, {selectedLocation.tukang_lng.toFixed(4)}
                  </span>
                </div>

                {/* Job Marker */}
                <div className="absolute right-12 bottom-12 z-10 flex flex-col items-center">
                  <div className="w-10 h-10 bg-blue-500/20 border-2 border-blue-400 rounded-full flex items-center justify-center shadow-lg shadow-blue-500/30">
                    <MapPin className="w-5 h-5 text-blue-300" />
                  </div>
                  <span className="mt-1 px-2 py-0.5 bg-slate-900/90 border border-slate-700 text-blue-300 rounded text-[10px]">
                    Lokasi Job ({selectedLocation.area_label})
                  </span>
                </div>

                {/* Connecting Dotted Vector */}
                <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
                  <div className="w-64 h-0.5 border-t-2 border-dashed border-slate-600 rotate-12" />
                </div>
              </div>

              {/* Status & Rules Callout */}
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-950 border border-slate-800 p-4 rounded-xl">
                  <div className="text-xs text-slate-400">Status Pekerjaan</div>
                  <div className="text-base font-bold text-white mt-1">{selectedLocation.status}</div>
                  <p className="text-[11px] text-slate-500 mt-1">
                    {selectedLocation.status === 'WORKING'
                      ? 'Pekerjaan sedang berlangsung. Sesuai BR-65 dilarang dibatalkan.'
                      : selectedLocation.status === 'ARRIVED'
                      ? 'Tukang sudah berada di lokasi. Menunggu klik Mulai Bekerja (BR-62).'
                      : 'Tukang sedang menuju lokasi. Auto Arrived &le; 50m (BR-60).'}
                  </p>
                </div>

                <div className="bg-slate-950 border border-slate-800 p-4 rounded-xl">
                  <div className="text-xs text-slate-400">Deskripsi Order</div>
                  <div className="text-sm font-semibold text-slate-200 mt-1 line-clamp-2">
                    {selectedLocation.description}
                  </div>
                  <p className="text-[11px] text-slate-500 mt-1">Lokasi: {selectedLocation.area_label}</p>
                </div>
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center flex-1 text-slate-500 text-sm">
              <MapPin className="w-12 h-12 text-slate-700 mb-3" />
              Pilih mitra tukang di sebelah kiri untuk melihat live tracking koordinat.
            </div>
          )}

          {/* Footer Warning */}
          <div className="pt-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-500">
            <span className="flex items-center gap-1.5">
              <ShieldAlert className="w-4 h-4 text-slate-400" />
              Audit Geospasial Beres v1.4.0 (Zero Cost OSM MVP)
            </span>
            <span>Akurasi GPS &le; 30 meter</span>
          </div>
        </div>
      </div>
    </div>
  );
}
