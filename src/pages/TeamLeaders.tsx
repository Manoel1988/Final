import React, { useState, useEffect } from 'react';
import { Plus, Search, Edit2, Trash2, Users } from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { TeamLeader } from '../types/team-leader';

interface TeamLeaderFormProps {
  teamLeader?: TeamLeader;
  onSuccess: () => void;
  onCancel: () => void;
}

function TeamLeaderForm({ teamLeader, onSuccess, onCancel }: TeamLeaderFormProps) {
  const [formData, setFormData] = useState({
    name: teamLeader?.name || '',
    status: teamLeader?.status || 'active'
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        throw new Error('Usuário não autenticado');
      }

      const dataWithUserId = {
        ...formData,
        user_id: user.id,
        squad_name: 'Equipe Padrão',
        start_date: new Date().toISOString().split('T')[0]
      };
      
      if (teamLeader) {
        const { error } = await supabase
          .from('team_leaders')
          .update(dataWithUserId)
          .eq('id', teamLeader.id);
        
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('team_leaders')
          .insert([dataWithUserId]);
        
        if (error) throw error;
      }
      
      onSuccess();
    } catch (error) {
      console.error('Erro ao salvar líder de equipe:', error);
      alert('Erro ao salvar líder de equipe. Por favor, tente novamente.');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Nome</label>
          <input
            type="text"
            required
            value={formData.name}
            onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700">Status</label>
          <select
            value={formData.status}
            onChange={(e) => setFormData(prev => ({ ...prev, status: e.target.value as 'active' | 'inactive' }))}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="active">Ativo</option>
            <option value="inactive">Inativo</option>
          </select>
        </div>
      </div>

      <div className="flex justify-end gap-3">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
        >
          Cancelar
        </button>
        <button
          type="submit"
          className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
        >
          {teamLeader ? 'Atualizar' : 'Criar'} Team Leader
        </button>
      </div>
    </form>
  );
}

export function TeamLeaders() {
  const [teamLeaders, setTeamLeaders] = useState<TeamLeader[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [selectedTeamLeader, setSelectedTeamLeader] = useState<TeamLeader | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    checkAdminStatus();
    fetchTeamLeaders();
  }, []);

  const checkAdminStatus = async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data } = await supabase
        .from('users')
        .select('raw_user_meta_data')
        .eq('id', user.id)
        .single();
      
      setIsAdmin(data?.raw_user_meta_data?.permission === 'admin');
    }
  };

  const fetchTeamLeaders = async () => {
    try {
      // First, get all active company statuses
      const { data: statuses } = await supabase
        .from('company_statuses')
        .select('id')
        .eq('is_active', true);

      const activeStatusIds = (statuses || []).map(status => status.id);

      // Then fetch team leaders with their companies
      const { data, error } = await supabase
        .from('team_leaders')
        .select(`
          *,
          companies_a:companies!companies_team_leader_a_id_fkey(id, status_id),
          companies_b:companies!companies_team_leader_b_id_fkey(id, status_id)
        `)
        .order('name');

      if (error) throw error;

      // Calculate squad count for each team leader
      const leadersWithSquadCount = data?.map(leader => {
        // Count companies where status_id is in activeStatusIds
        const activeCompaniesA = leader.companies_a?.filter(company => 
          activeStatusIds.includes(company.status_id)
        ).length || 0;

        const activeCompaniesB = leader.companies_b?.filter(company => 
          activeStatusIds.includes(company.status_id)
        ).length || 0;

        return {
          ...leader,
          companies_count: activeCompaniesA + activeCompaniesB
        };
      }) || [];

      setTeamLeaders(leadersWithSquadCount);
      setError(null);
    } catch (error) {
      console.error('Erro ao buscar líderes de equipe:', error);
      setError('Erro ao carregar líderes de equipe. Por favor, tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Tem certeza que deseja excluir este líder de equipe?')) return;
    
    try {
      const { error } = await supabase
        .from('team_leaders')
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      await fetchTeamLeaders();
    } catch (error) {
      console.error('Erro ao excluir líder de equipe:', error);
      setError('Erro ao excluir líder de equipe. Por favor, tente novamente.');
    }
  };

  const filteredTeamLeaders = teamLeaders.filter(leader =>
    leader.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <h1 className="text-2xl font-semibold text-gray-800">Team Leaders</h1>
        {isAdmin && (
          <button
            onClick={() => {
              setSelectedTeamLeader(null);
              setShowForm(true);
            }}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            Novo Team Leader
          </button>
        )}
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder="Buscar team leaders..."
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
              {selectedTeamLeader ? 'Editar Team Leader' : 'Novo Team Leader'}
            </h2>
            <TeamLeaderForm
              teamLeader={selectedTeamLeader || undefined}
              onSuccess={() => {
                setShowForm(false);
                fetchTeamLeaders();
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
                  Nome
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Data de Início
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Squad
                </th>
                {isAdmin && (
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Ações
                  </th>
                )}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={isAdmin ? 5 : 4} className="px-6 py-4 text-center text-gray-500">
                    Carregando...
                  </td>
                </tr>
              ) : filteredTeamLeaders.length === 0 ? (
                <tr>
                  <td colSpan={isAdmin ? 5 : 4} className="px-6 py-4 text-center text-gray-500">
                    Nenhum team leader encontrado
                  </td>
                </tr>
              ) : (
                filteredTeamLeaders.map((leader) => (
                  <tr key={leader.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {leader.name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        leader.status === 'active' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {leader.status === 'active' ? 'Ativo' : 'Inativo'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {new Date(leader.start_date).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="inline-flex items-center px-3 py-1 rounded-full bg-blue-100 text-blue-800">
                        <Users className="w-4 h-4 mr-1" />
                        {leader.companies_count || 0} empresas ativas
                      </div>
                    </td>
                    {isAdmin && (
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <div className="flex gap-2 justify-end">
                          <button
                            onClick={() => {
                              setSelectedTeamLeader(leader);
                              setShowForm(true);
                            }}
                            className="text-blue-600 hover:text-blue-900"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDelete(leader.id)}
                            className="text-red-600 hover:text-red-900"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    )}
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