import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useNavigate } from 'react-router-dom';
import { Menu, X, Home, UsersIcon, Building2, Settings, HelpCircle, Users } from 'lucide-react';
import { Companies } from './pages/Companies';
import { Users as UsersPage } from './pages/Users';
import { TeamLeaders } from './pages/TeamLeaders';
import { Settings as SettingsPage } from './pages/Settings';
import { Products } from './pages/Products';
import { CompanyStatus } from './pages/CompanyStatus';
import { Roles } from './pages/Roles';
import { supabase } from './lib/supabase';

function AppContent() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [currentPage, setCurrentPage] = useState('home');
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const menuItems = [
    { icon: Home, text: 'Início', href: '/', id: 'home' },
    { icon: Building2, text: 'Empresas', href: '/companies', id: 'companies' },
    { icon: UsersIcon, text: 'Usuários', href: '/users', id: 'users' },
    { icon: Users, text: 'Team Leaders', href: '/team-leaders', id: 'team-leaders' },
    { icon: Settings, text: 'Configurações', href: '/settings', id: 'settings' },
    { icon: HelpCircle, text: 'Ajuda', href: '/help', id: 'help' },
  ];

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="text-gray-600">Loading...</div>
      </div>
    );
  }

  if (!session) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="bg-white p-8 rounded-lg shadow-md max-w-md w-full">
          {/* Auth form content */}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 flex">
      <aside
        className={`${
          isSidebarOpen ? 'translate-x-0' : '-translate-x-full'
        } fixed lg:relative lg:translate-x-0 z-50 w-64 h-screen transition-transform duration-300 ease-in-out`}
      >
        <div className="h-full bg-white border-r shadow-lg">
          <div className="flex items-center justify-between p-4 border-b">
            <h1 className="text-xl font-semibold text-gray-800">Dashboard</h1>
            <button
              onClick={() => setIsSidebarOpen(false)}
              className="p-1 rounded-lg hover:bg-gray-100 lg:hidden"
            >
              <X className="w-6 h-6 text-gray-600" />
            </button>
          </div>

          <nav className="p-4 space-y-2">
            {menuItems.map((item, index) => {
              const Icon = item.icon;
              return (
                <Link
                  key={index}
                  to={item.href}
                  className={`w-full flex items-center gap-3 px-4 py-3 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors ${
                    currentPage === item.id ? 'bg-gray-100' : ''
                  }`}
                  onClick={() => setCurrentPage(item.id)}
                >
                  <Icon className="w-5 h-5" />
                  <span>{item.text}</span>
                </Link>
              );
            })}
          </nav>
        </div>
      </aside>

      <div className="flex-1">
        <header className="bg-white border-b shadow-sm">
          <div className="flex items-center justify-between p-4">
            <button
              onClick={() => setIsSidebarOpen(true)}
              className="p-1 rounded-lg hover:bg-gray-100 lg:hidden"
            >
              <Menu className="w-6 h-6 text-gray-600" />
            </button>
            <div className="flex items-center gap-4">
              <div className="text-sm text-gray-600">
                {session.user.email}
              </div>
              <button
                onClick={() => supabase.auth.signOut()}
                className="text-sm text-red-600 hover:text-red-700"
              >
                Sair
              </button>
            </div>
          </div>
        </header>

        <main className="p-6">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/companies" element={<Companies />} />
            <Route path="/users" element={<UsersPage />} />
            <Route path="/team-leaders" element={<TeamLeaders />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/settings/products" element={<Products />} />
            <Route path="/settings/company-status" element={<CompanyStatus />} />
            <Route path="/settings/roles" element={<Roles />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function Dashboard() {
  const [dashboardStats, setDashboardStats] = useState({
    totalCompanies: 0,
    activeContracts: 0,
    totalUsers: 0,
    recentUsers: 0
  });

  useEffect(() => {
    fetchDashboardStats();
  }, []);

  const fetchDashboardStats = async () => {
    try {
      const { data: companies } = await supabase
        .from('companies')
        .select('*');
      
      const totalCompanies = companies?.length || 0;
      const now = new Date();
      const activeContracts = companies?.filter(company => 
        new Date(company.contract_end) >= now
      ).length || 0;

      const { data: users } = await supabase
        .from('users')
        .select('created_at');

      const totalUsers = users?.length || 0;
      
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      const recentUsers = users?.filter(user => 
        new Date(user.created_at) >= thirtyDaysAgo
      ).length || 0;

      setDashboardStats({
        totalCompanies,
        activeContracts,
        totalUsers,
        recentUsers
      });
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <h2 className="text-2xl font-semibold text-gray-800 mb-6">Dashboard</h2>
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-2">
        <div className="space-y-6">
          <h3 className="text-lg font-medium text-gray-800">Empresas</h3>
          <div className="grid gap-4">
            <div className="bg-white p-6 rounded-lg shadow-sm">
              <h4 className="text-sm font-medium text-gray-600 mb-2">Total de Empresas</h4>
              <div className="text-3xl font-bold text-blue-600 mb-2">
                {dashboardStats.totalCompanies}
              </div>
              <p className="text-sm text-gray-500">Empresas cadastradas</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow-sm">
              <h4 className="text-sm font-medium text-gray-600 mb-2">Contratos Ativos</h4>
              <div className="text-3xl font-bold text-green-600 mb-2">
                {dashboardStats.activeContracts}
              </div>
              <p className="text-sm text-gray-500">Empresas com contratos vigentes</p>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <h3 className="text-lg font-medium text-gray-800">Usuários</h3>
          <div className="grid gap-4">
            <div className="bg-white p-6 rounded-lg shadow-sm">
              <h4 className="text-sm font-medium text-gray-600 mb-2">Total de Usuários</h4>
              <div className="text-3xl font-bold text-purple-600 mb-2">
                {dashboardStats.totalUsers}
              </div>
              <p className="text-sm text-gray-500">Usuários cadastrados</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow-sm">
              <h4 className="text-sm font-medium text-gray-600 mb-2">Novos Usuários</h4>
              <div className="text-3xl font-bold text-indigo-600 mb-2">
                {dashboardStats.recentUsers}
              </div>
              <p className="text-sm text-gray-500">Cadastrados nos últimos 30 dias</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;