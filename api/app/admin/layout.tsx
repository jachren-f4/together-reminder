import '../globals.css';

export const metadata = {
  title: 'Us 2.0 Analytics - Admin Dashboard',
  description: 'Analytics dashboard for Us 2.0 couples app',
};

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
