'use client';

import { useState, useEffect } from 'react';
import { TimeRangePicker } from './TimeRangePicker';
import { AdminLineChart, AdminDonutChart } from './Chart';

interface SubscriptionMetrics {
  activeSubscribers: number;
  trialUsers: number;
  cancelled: number;
  expired: number;
  none: number;
  totalCouples: number;
}

interface SubscriptionByProduct {
  productId: string;
  productName: string;
  count: number;
  percentage: number;
}

interface SubscriptionTrend {
  date: string;
  newTrials: number;
  conversions: number;
  churned: number;
}

interface RecentCancellation {
  coupleId: string;
  productId: string | null;
  subscribedAt: string | null;
  expiresAt: string | null;
  durationDays: number | null;
  status: string;
}

interface ConversionRate {
  totalTrialsStarted: number;
  converted: number;
  conversionRate: number;
}

interface Revenue {
  mrr: number;
  arr: number;
}

interface SubscriptionData {
  metrics: SubscriptionMetrics;
  byProduct: SubscriptionByProduct[];
  trends: SubscriptionTrend[];
  cancellations: RecentCancellation[];
  conversionRate: ConversionRate;
  revenue: Revenue;
}

export default function SubscriptionsContent() {
  const [range, setRange] = useState(30);
  const [data, setData] = useState<SubscriptionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      setError(null);
      try {
        const response = await fetch(`/api/admin/subscriptions?range=${range}`);
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

  const formatCurrency = (num: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(num);
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getStatusChartData = () => {
    if (!data) return [];
    return [
      { name: 'Active', value: data.metrics.activeSubscribers, color: '#22c55e' },
      { name: 'Trial', value: data.metrics.trialUsers, color: '#3b82f6' },
      { name: 'Cancelled', value: data.metrics.cancelled, color: '#f59e0b' },
      { name: 'Expired', value: data.metrics.expired, color: '#ef4444' },
      { name: 'None', value: data.metrics.none, color: '#9ca3af' },
    ].filter((item) => item.value > 0);
  };

  return (
    <div className="p-4 lg:p-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6 lg:mb-8">
        <div>
          <h2 className="text-xl lg:text-2xl font-bold text-gray-900">Subscription Analytics</h2>
          <p className="text-gray-500 text-sm lg:text-base mt-1">Monitor revenue and subscription health</p>
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
          {/* Revenue Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-4 mb-6">
            <div className="bg-gradient-to-br from-green-500 to-emerald-600 rounded-xl p-4 lg:p-5 text-white">
              <p className="text-xs lg:text-sm font-medium text-green-100">Est. MRR</p>
              <p className="text-2xl lg:text-3xl font-bold mt-2">{formatCurrency(data.revenue.mrr)}</p>
            </div>
            <div className="bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl p-4 lg:p-5 text-white">
              <p className="text-xs lg:text-sm font-medium text-indigo-100">Est. ARR</p>
              <p className="text-2xl lg:text-3xl font-bold mt-2">{formatCurrency(data.revenue.arr)}</p>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Trial Conversion</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{data.conversionRate.conversionRate}%</p>
              <p className="text-xs text-gray-500 mt-1">{data.conversionRate.converted} / {data.conversionRate.totalTrialsStarted}</p>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Total Couples</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{data.metrics.totalCouples}</p>
            </div>
          </div>

          {/* Status Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-3 lg:gap-4 mb-6">
            <div className="bg-white rounded-xl border-l-4 border-l-green-500 border border-gray-200 p-4">
              <p className="text-xs font-medium text-gray-500">Active</p>
              <p className="text-xl font-bold text-gray-900 mt-1">{data.metrics.activeSubscribers}</p>
            </div>
            <div className="bg-white rounded-xl border-l-4 border-l-blue-500 border border-gray-200 p-4">
              <p className="text-xs font-medium text-gray-500">Trial</p>
              <p className="text-xl font-bold text-gray-900 mt-1">{data.metrics.trialUsers}</p>
            </div>
            <div className="bg-white rounded-xl border-l-4 border-l-yellow-500 border border-gray-200 p-4">
              <p className="text-xs font-medium text-gray-500">Cancelled</p>
              <p className="text-xl font-bold text-gray-900 mt-1">{data.metrics.cancelled}</p>
            </div>
            <div className="bg-white rounded-xl border-l-4 border-l-red-500 border border-gray-200 p-4">
              <p className="text-xs font-medium text-gray-500">Expired</p>
              <p className="text-xl font-bold text-gray-900 mt-1">{data.metrics.expired}</p>
            </div>
            <div className="bg-white rounded-xl border-l-4 border-l-gray-400 border border-gray-200 p-4">
              <p className="text-xs font-medium text-gray-500">None</p>
              <p className="text-xl font-bold text-gray-900 mt-1">{data.metrics.none}</p>
            </div>
          </div>

          {/* Charts Row */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 lg:gap-6 mb-6">
            {/* Status Distribution */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Status Distribution</h3>
              {getStatusChartData().length > 0 ? (
                <AdminDonutChart data={getStatusChartData()} height={250} />
              ) : (
                <div className="flex items-center justify-center h-64 text-gray-500">No subscription data</div>
              )}
            </div>

            {/* Subscription Trends */}
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Subscription Trends</h3>
              <AdminLineChart
                data={data.trends}
                lines={[
                  { dataKey: 'newTrials', color: '#3b82f6', name: 'New Trials' },
                  { dataKey: 'conversions', color: '#22c55e', name: 'Conversions' },
                  { dataKey: 'churned', color: '#ef4444', name: 'Churned' },
                ]}
                height={250}
              />
            </div>
          </div>

          {/* By Product */}
          <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-6 mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Subscriptions by Product</h3>
            {data.byProduct.length === 0 ? (
              <p className="text-gray-500 text-center py-4">No subscription products found</p>
            ) : (
              <div className="space-y-3">
                {data.byProduct.map((product) => (
                  <div key={product.productId} className="flex items-center">
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between mb-1">
                        <span className="text-sm font-medium text-gray-900 truncate">{product.productName}</span>
                        <span className="text-sm text-gray-500">{product.count} ({product.percentage}%)</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div
                          className="bg-indigo-600 h-2 rounded-full"
                          style={{ width: `${product.percentage}%` }}
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Recent Cancellations */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="p-4 lg:p-6 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Recent Cancellations</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 lg:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Couple ID
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Product
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Subscribed
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Expires
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Duration
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {data.cancellations.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 lg:px-6 py-8 text-center text-gray-500">
                        No recent cancellations
                      </td>
                    </tr>
                  ) : (
                    data.cancellations.map((cancellation, index) => (
                      <tr key={index} className="hover:bg-gray-50">
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap">
                          <span className="text-sm font-mono text-gray-900">{cancellation.coupleId}</span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap">
                          <span className="text-sm text-gray-900">{cancellation.productId || '—'}</span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap">
                          <span className="text-sm text-gray-500">{formatDate(cancellation.subscribedAt)}</span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap">
                          <span className="text-sm text-gray-500">{formatDate(cancellation.expiresAt)}</span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className="text-sm text-gray-900">
                            {cancellation.durationDays !== null ? `${cancellation.durationDays}d` : '—'}
                          </span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className={`inline-flex px-2 py-1 rounded-full text-xs font-medium ${
                            cancellation.status === 'cancelled' ? 'bg-yellow-100 text-yellow-800' :
                            cancellation.status === 'expired' ? 'bg-red-100 text-red-800' :
                            cancellation.status === 'refunded' ? 'bg-purple-100 text-purple-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {cancellation.status}
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Footer */}
          <div className="mt-8 text-center text-sm text-gray-400">
            <p>Revenue estimates based on: Yearly = $49.99/yr, Monthly = $7.99/mo</p>
          </div>
        </>
      ) : null}
    </div>
  );
}
