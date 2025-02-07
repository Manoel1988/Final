import React, { useState, useEffect } from 'react';
import { Plus, Search, Edit2, Trash2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { CompanyForm } from '../components/CompanyForm';
import type { Company } from '../types/company';
import type { TeamLeader } from '../types/team-leader';

export function Companies() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [teamLeaders, setTeamLeaders] = useState<TeamLeader[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [selectedCompany, setSelectedCompany] = useState<Company | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchTeamLeaders = async () => {
    try {
      const { data, error } = await supabase
        .from('team_leaders')
        .select('*')
        .eq('status', 'active')
        .order('name');
      
      if (error) throw error;
      setTeamLeaders(data || []);
    } catch (error) {
      console.error('Erro ao buscar team leaders:', error);
    }
  };

  const fetchCompanies = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        setError('Usuário não autenticado');
        return;
      }

      const { data, error: fetchError } = await supabase
        .from('companies')
        .select(`
          *,
          status:company_statuses(*),
          team_leader_a:team_leaders!companies_team_leader_a_fkey(*),
          team_leader_b:team_leaders!companies_team_leader_b_fkey(*)
        `)
        .order('name');
      
      if (fetchError) throw fetchError;
      setCompanies(data || []);
      setError(null);
    } catch (error) {
      console.error('Erro ao buscar empresas:', error);
      setError('Erro ao carregar empresas. Por favor, tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTeamLeaders();
    fetchCompanies();
  }, []);

  const handleDelete = async (id: string) => {
    if (!confirm('Tem certeza que deseja excluir esta empresa?')) return;
    
    try {
      const { error } = await supabase
        .from('companies')
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      await fetchCompanies();
    } catch (error) {
      console.error('Erro ao excluir empresa:', error);
      setError('Erro ao excluir empresa. Por favor, tente novamente.');
    }
  };

  const filteredCompanies = companies.filter(company =>
    company.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    company.legal_name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <h1 className="text-2xl font-semibold text-gray-800">Empresas</h1>
        <button
          onClick={() => {
            setSelectedCompany(null);
            setShowForm(true);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus className="w-4 h-4" />
          Adicionar Empresa
        </button>
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder="Buscar empresas..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10 pr-4 py-2 w-full border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-100 border border-red-400 text-red-700 rounded">
          {error}
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h2 className="text-xl font-semibold mb-4">
              {selectedCompany ? 'Editar Empresa' : 'Nova Empresa'}
            </h2>
            <CompanyForm
              company={selectedCompany || undefined}
              teamLeaders={teamLeaders}
              onSuccess={() => {
                setShowForm(false);
                fetchCompanies();
              }}
              onCancel={() => setShowForm(false)}
            />
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg shadow">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Nome da Empresa
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Razão Social
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Período do Contrato
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Team Leader (A)
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Team Leader (B)
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-4 text-center text-gray-500">
                    Carregando...
                  </td>
                </tr>
              ) : filteredCompanies.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-4 text-center text-gray-500">
                    Nenhuma empresa encontrada
                  </td>
                </tr>
              ) : (
                filteredCompanies.map((company) => (
                  <tr key={company.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {company.name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {company.legal_name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {new Date(company.contract_start).toLocaleDateString()} - 
                        {new Date(company.contract_end).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        company.status?.is_active 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {company.status?.name || 'Sem Status'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {company.team_leader_a?.name || '-'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {company.team_leader_b?.name || '-'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => {
                            setSelectedCompany(company);
                            setShowForm(true);
                          }}
                          className="text-blue-600 hover:text-blue-900"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(company.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}