'use client';

import { useState, useEffect } from 'react';

interface CohortData {
  cohortWeek: string;
  cohortLabel: string;
  size: number;
  d1: number | null;
  d7: number | null;
  d30: number | null;
}

interface RetentionSummary {
  avgD1: number;
  avgD7: number;
  avgD30: number;
  totalCohortSize: number;
}

interface RetentionData {
  cohorts: CohortData[];
  summary: RetentionSummary;
}

export default function RetentionContent() {
  const [weeks, setWeeks] = useState(8);
  const [data, setData] = useState<RetentionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      setError(null);
      try {
        const response = await fetch(`/api/admin/retention?weeks=${weeks}`);
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
  }, [weeks]);

  const getRetentionColor = (value: number | null) => {
    if (value === null) return 'bg-gray-100 text-gray-400';
    if (value >= 60) return 'bg-green-100 text-green-800';
    if (value >= 40) return 'bg-yellow-100 text-yellow-800';
    return 'bg-red-100 text-red-800';
  };

  return (
    <div className="p-4 lg:p-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6 lg:mb-8">
        <div>
          <h2 className="text-xl lg:text-2xl font-bold text-gray-900">Retention Analysis</h2>
          <p className="text-gray-500 text-sm lg:text-base mt-1">Weekly cohort retention metrics</p>
        </div>
        <select
          value={weeks}
          onChange={(e) => setWeeks(parseInt(e.target.value))}
          className="px-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-medium text-gray-700"
        >
          <option value={8}>Last 8 weeks</option>
          <option value={12}>Last 12 weeks</option>
          <option value={16}>Last 16 weeks</option>
        </select>
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
          {/* Summary Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-4 mb-6">
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Total Cohort Size</p>
              <p className="text-2xl lg:text-3xl font-bold text-gray-900 mt-2">{data.summary.totalCohortSize}</p>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Avg D1 Retention</p>
              <p className={`text-2xl lg:text-3xl font-bold mt-2 ${data.summary.avgD1 >= 40 ? 'text-green-600' : 'text-red-600'}`}>
                {data.summary.avgD1}%
              </p>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Avg D7 Retention</p>
              <p className={`text-2xl lg:text-3xl font-bold mt-2 ${data.summary.avgD7 >= 30 ? 'text-green-600' : 'text-red-600'}`}>
                {data.summary.avgD7}%
              </p>
            </div>
            <div className="bg-white rounded-xl border border-gray-200 p-4 lg:p-5">
              <p className="text-xs lg:text-sm font-medium text-gray-500">Avg D30 Retention</p>
              <p className={`text-2xl lg:text-3xl font-bold mt-2 ${data.summary.avgD30 >= 20 ? 'text-green-600' : 'text-red-600'}`}>
                {data.summary.avgD30}%
              </p>
            </div>
          </div>

          {/* Cohort Table */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div className="p-4 lg:p-6 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Weekly Cohorts</h3>
              <p className="text-sm text-gray-500 mt-1">
                Color coding: <span className="inline-block px-2 py-0.5 bg-green-100 text-green-800 rounded text-xs">≥60%</span>{' '}
                <span className="inline-block px-2 py-0.5 bg-yellow-100 text-yellow-800 rounded text-xs">40-60%</span>{' '}
                <span className="inline-block px-2 py-0.5 bg-red-100 text-red-800 rounded text-xs">&lt;40%</span>
              </p>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 lg:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Cohort Week
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Size
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      D1
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      D7
                    </th>
                    <th className="px-4 lg:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                      D30
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {data.cohorts.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-4 lg:px-6 py-8 text-center text-gray-500">
                        No cohort data available
                      </td>
                    </tr>
                  ) : (
                    data.cohorts.map((cohort) => (
                      <tr key={cohort.cohortWeek} className="hover:bg-gray-50">
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap">
                          <div className="text-sm font-medium text-gray-900">{cohort.cohortLabel}</div>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className="text-sm font-semibold text-gray-900">{cohort.size}</span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className={`inline-flex px-3 py-1 rounded-full text-sm font-medium ${getRetentionColor(cohort.d1)}`}>
                            {cohort.d1 !== null ? `${cohort.d1}%` : '—'}
                          </span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className={`inline-flex px-3 py-1 rounded-full text-sm font-medium ${getRetentionColor(cohort.d7)}`}>
                            {cohort.d7 !== null ? `${cohort.d7}%` : '—'}
                          </span>
                        </td>
                        <td className="px-4 lg:px-6 py-4 whitespace-nowrap text-center">
                          <span className={`inline-flex px-3 py-1 rounded-full text-sm font-medium ${getRetentionColor(cohort.d30)}`}>
                            {cohort.d30 !== null ? `${cohort.d30}%` : '—'}
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
            <p>Retention data based on activity in quest completions, quizzes, linked, and word search games</p>
          </div>
        </>
      ) : null}
    </div>
  );
}
