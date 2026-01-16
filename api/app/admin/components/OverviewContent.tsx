'use client';

import { useState, useEffect } from 'react';
import { TimeRangePicker } from './TimeRangePicker';
import { AdminLineChart } from './Chart';

interface OverviewMetrics {
  totalUsers: number;
  totalCouples: number;
  dau: number;
  wau: number;
  mau: number;
  activeSubscriptions: number;
  trialUsers: number;
  totalLP: number;
  newUsersToday: number;
  newCouplesToday: number;
}

interface DailyStats {
  date: string;
  newUsers: number;
  newCouples: number;
  activeUsers: number;
  [key: string]: string | number;  // Index signature for chart compatibility
}

interface PairingStats {
  invitesCreated: number;
  invitesUsed: number;
  conversionRate: number;
}

interface OverviewData {
  metrics: OverviewMetrics;
  dailyStats: DailyStats[];
  pairingStats: PairingStats;
}

export default function OverviewContent() {
  const [range, setRange] = useState(30);
  const [data, setData] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      setError(null);
      try {
        const response = await fetch(`/api/admin/overview?range=${range}`);
        if (!response.ok) {
          throw new Error('Failed to fetch data');
        }
        const json = await response.json();
        setData(json);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [range]);

  const formatNumber = (num: number) => {
    if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
    if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
    return num.toLocaleString();
  };

  return (
    <div className="p-4 lg:p-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6 lg:mb-8">
        <div>
          <h2 className="text-xl lg:text-2xl font-bold text-gray-900">Dashboard Overview</h2>
          <p className="text-gray-500 text-sm lg:text-base mt-1">Monitor your app&apos;s key metrics</p>
        </div>
        <TimeRangePicker value={range} onChange={setRange} />
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
          {error}
        </div>
      ) : data ? (
        <>
          {/* Top Row - 5 metric cards */}
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-3 lg:gap-4 mb-6">
            {/* Total Users */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                  <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                  </svg>
                </div>
              </div>
              <p className="text-xs lg:text-sm font-medium text-gray-500 mt-3">Total Users</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.totalUsers)}</p>
              <p className="text-xs text-green-600 mt-1">+{data.metrics.newUsersToday} today</p>
            </div>

            {/* Total Couples */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-pink-100 rounded-lg flex items-center justify-center">
                  <svg className="w-5 h-5 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                </div>
              </div>
              <p className="text-xs lg:text-sm font-medium text-gray-500 mt-3">Total Couples</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.totalCouples)}</p>
              <p className="text-xs text-green-600 mt-1">+{data.metrics.newCouplesToday} today</p>
            </div>

            {/* DAU */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                  <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                </div>
              </div>
              <p className="text-xs lg:text-sm font-medium text-gray-500 mt-3">DAU</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.dau)}</p>
              <p className="text-xs text-gray-500 mt-1">Active today</p>
            </div>

            {/* WAU */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center">
                  <svg className="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
              </div>
              <p className="text-xs lg:text-sm font-medium text-gray-500 mt-3">WAU</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.wau)}</p>
              <p className="text-xs text-gray-500 mt-1">Last 7 days</p>
            </div>

            {/* MAU */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                  <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
              </div>
              <p className="text-xs lg:text-sm font-medium text-gray-500 mt-3">MAU</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.mau)}</p>
              <p className="text-xs text-gray-500 mt-1">Last 30 days</p>
            </div>
          </div>

          {/* Second Row - 3 cards */}
          <div className="grid grid-cols-3 gap-3 lg:gap-4 mb-6">
            {/* Active Subs */}
            <div className="bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl p-4 lg:p-5 text-white">
              <p className="text-xs lg:text-sm font-medium text-indigo-100">Active Subs</p>
              <p className="text-2xl lg:text-3xl font-bold mt-2">{formatNumber(data.metrics.activeSubscriptions)}</p>
            </div>

            {/* Trial Users */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Trial Users</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.trialUsers)}</p>
            </div>

            {/* Total LP */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Total LP</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{formatNumber(data.metrics.totalLP)}</p>
            </div>
          </div>

          {/* Charts Row */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 lg:gap-6 mb-6">
            {/* New Users & Couples Chart */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">New Users & Couples</h3>
              <AdminLineChart
                data={data.dailyStats}
                lines={[
                  { dataKey: 'newUsers', color: '#3b82f6', name: 'New Users' },
                  { dataKey: 'newCouples', color: '#ec4899', name: 'New Couples' },
                ]}
                height={250}
              />
            </div>

            {/* Active Users Chart */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Daily Active Users</h3>
              <AdminLineChart
                data={data.dailyStats}
                lines={[
                  { dataKey: 'activeUsers', color: '#22c55e', name: 'Active Users' },
                ]}
                height={250}
              />
            </div>
          </div>

          {/* Pairing Stats */}
          <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Pairing Stats</h3>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <p className="text-3xl font-bold text-gray-900">{formatNumber(data.pairingStats.invitesCreated)}</p>
                <p className="text-sm text-gray-500 mt-1">Invites Created</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-gray-900">{formatNumber(data.pairingStats.invitesUsed)}</p>
                <p className="text-sm text-gray-500 mt-1">Invites Used</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-green-600">{data.pairingStats.conversionRate}%</p>
                <p className="text-sm text-gray-500 mt-1">Conversion Rate</p>
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="mt-8 text-center text-sm text-gray-400">
            <p>Dashboard v0.2 - Last updated: {new Date().toLocaleString()}</p>
          </div>
        </>
      ) : null}
    </div>
  );
}
