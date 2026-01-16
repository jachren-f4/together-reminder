import { redirect } from 'next/navigation';
import { getAdminSession } from '@/lib/admin/auth';
import AdminNav from './AdminNav';

interface AdminShellProps {
  children: React.ReactNode;
}

export default async function AdminShell({ children }: AdminShellProps) {
  const session = await getAdminSession();

  if (!session) {
    redirect('/admin/login');
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <AdminNav email={session.email} />
      <main className="lg:ml-64 pt-16 lg:pt-0">
        {children}
      </main>
    </div>
  );
}
