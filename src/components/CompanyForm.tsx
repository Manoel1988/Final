import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { Company } from '../types/company';
import type { CompanyStatus } from '../types/status';
import type { TeamLeader } from '../types/team-leader';

interface CompanyFormProps {
  company?: Company;
  teamLeaders: TeamLeader[];
  onSuccess: () => void;
  onCancel: () => void;
}

export function CompanyForm({ company, teamLeaders, onSuccess, onCancel }: CompanyFormProps) {
  const [formData, setFormData] = useState({
    name: company?.name || '',
    legal_name: company?.legal_name || '',
    contract_start: company?.contract_start?.split('T')[0] || '',
    contract_end: company?.contract_end?.split('T')[0] || '',
    status_id: company?.status_id || '',
    team_leader_a_id: company?.team_leader_a_id || '',
    team_leader_b_id: company?.team_leader_b_id || ''
  });
  const [statuses, setStatuses] = useState<CompanyStatus[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStatuses();
  }, []);

  const fetchStatuses = async () => {
    try {
      const { data, error } = await supabase
        .from('company_statuses')
        .select('*')
        .order('name');

      if (error) throw error;
      setStatuses(data || []);
    } catch (error) {
      console.error('Erro ao buscar status:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        throw new Error('Usuário não autenticado');
      }

      const dataWithUserId = {
        ...formData,
        user_id: user.id
      };
      
      if (company) {
        const { error } = await supabase
          .from('companies')
          .update(dataWithUserId)
          .eq('id', company.id);
        
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('companies')
          .insert([dataWithUserId]);
        
        if (error) throw error;
      }
      
      onSuccess();
    } catch (error) {
      console.error('Erro ao salvar empresa:', error);
      alert('Erro ao salvar empresa. Por favor, tente novamente.');
    }
  };

  if (loading) {
    return <div className="p-4 text-center text-gray-500">Carregando...</div>;
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Nome da Empresa</label>
        <input
          type="text"
          required
          value={formData.name}
          onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Razão Social</label>
        <input
          type="text"
          required
          value={formData.legal_name}
          onChange={(e) => setFormData(prev => ({ ...prev, legal_name: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Data de Início do Contrato</label>
        <input
          type="date"
          required
          value={formData.contract_start}
          onChange={(e) => setFormData(prev => ({ ...prev, contract_start: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Data de Término do Contrato</label>
        <input
          type="date"
          required
          value={formData.contract_end}
          onChange={(e) => setFormData(prev => ({ ...prev, contract_end: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Status</label>
        <select
          value={formData.status_id}
          onChange={(e) => setFormData(prev => ({ ...prev, status_id: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          required
        >
          <option value="">Selecione um status</option>
          {statuses.map(status => (
            <option key={status.id} value={status.id}>
              {status.name}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Team Leader (A)</label>
        <select
          value={formData.team_leader_a_id}
          onChange={(e) => setFormData(prev => ({ ...prev, team_leader_a_id: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value="">Selecione um team leader</option>
          {teamLeaders.map(leader => (
            <option key={leader.id} value={leader.id}>
              {leader.name}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Team Leader (B)</label>
        <select
          value={formData.team_leader_b_id}
          onChange={(e) => setFormData(prev => ({ ...prev, team_leader_b_id: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value="">Selecione um team leader</option>
          {teamLeaders.map(leader => (
            <option key={leader.id} value={leader.id}>
              {leader.name}
            </option>
          ))}
        </select>
      </div>
      
      <div className="flex justify-end space-x-3">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        >
          Cancelar
        </button>
        <button
          type="submit"
          className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700"
        >
          {company ? 'Atualizar' : 'Criar'} Empresa
        </button>
      </div>
    </form>
  );
}