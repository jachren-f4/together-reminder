interface MetricCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  trend?: {
    value: number;
    label: string;
  };
  color?: 'blue' | 'green' | 'yellow' | 'red' | 'purple';
}

const colorClasses = {
  blue: 'border-l-blue-500',
  green: 'border-l-green-500',
  yellow: 'border-l-yellow-500',
  red: 'border-l-red-500',
  purple: 'border-l-purple-500',
};

export function MetricCard({ title, value, subtitle, trend, color = 'blue' }: MetricCardProps) {
  return (
    <div className={`bg-white rounded-lg shadow p-6 border-l-4 ${colorClasses[color]}`}>
      <div className="text-sm font-medium text-gray-500 uppercase tracking-wide">{title}</div>
      <div className="mt-2 flex items-baseline">
        <div className="text-3xl font-bold text-gray-900">{value}</div>
        {trend && (
          <span
            className={`ml-2 text-sm font-medium ${
              trend.value >= 0 ? 'text-green-600' : 'text-red-600'
            }`}
          >
            {trend.value >= 0 ? '↑' : '↓'} {Math.abs(trend.value)}% {trend.label}
          </span>
        )}
      </div>
      {subtitle && <div className="mt-1 text-sm text-gray-500">{subtitle}</div>}
    </div>
  );
}
