import React, { useState, useEffect } from 'react';
import { Plus, Search, Edit2, Trash2, ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import type { CompanyStatus } from '../types/status';

interface StatusFormProps {
  status?: CompanyStatus;
  onSuccess: () => void;
  onCancel: () => void;
}

function StatusForm({ status, onSuccess, onCancel }: StatusFormProps) {
  const [formData, setFormData] = useState({
    name: status?.name || '',
    description: status?.description || '',
    is_active: status?.is_active ?? true
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      if (status) {
        const { error } = await supabase
          .from('company_statuses')
          .update(formData)
          .eq('id', status.id);
        
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('company_statuses')
          .insert([formData]);
        
        if (error) throw error;
      }
      
      onSuccess();
    } catch (error) {
      console.error('Erro ao salvar status:', error);
      alert('Erro ao salvar status. Por favor, tente novamente.');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
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
        <label className="block text-sm font-medium text-gray-700">Descrição</label>
        <textarea
          value={formData.description || ''}
          onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          rows={3}
        />
      </div>

      <div>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={formData.is_active}
            onChange={(e) => setFormData(prev => ({ ...prev, is_active: e.target.checked }))}
            className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          <span className="text-sm text-gray-700">Ativo</span>
        </label>
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
          {status ? 'Atualizar' : 'Criar'} Status
        </button>
      </div>
    </form>
  );
}

export function CompanyStatus() {
  const [statuses, setStatuses] = useState<CompanyStatus[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<CompanyStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStatuses = async () => {
    try {
      const { data, error } = await supabase
        .from('company_statuses')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setStatuses(data || []);
      setError(null);
    } catch (error) {
      console.error('Erro ao buscar status:', error);
      setError('Erro ao carregar status. Por favor, tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStatuses();
  }, []);

  const handleDelete = async (id: string) => {
    if (!confirm('Tem certeza que deseja excluir este status?')) return;
    
    try {
      const { error } = await supabase
        .from('company_statuses')
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      await fetchStatuses();
    } catch (error) {
      console.error('Erro ao excluir status:', error);
      setError('Erro ao excluir status. Por favor, tente novamente.');
    }
  };

  const filteredStatuses = statuses.filter(status =>
    status.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    status.description?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <Link 
          to="/settings"
          className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900 mb-4"
        >
          <ArrowLeft className="w-4 h-4 mr-1" />
          Voltar para Configurações
        </Link>
        <div className="flex justify-between items-center">
          <h1 className="text-2xl font-semibold text-gray-800">Status de Empresa</h1>
          <button
            onClick={() => {
              setSelectedStatus(null);
              setShowForm(true);
            }}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <Plus className="w-4 h-4" />
            Novo Status
          </button>
        </div>
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder="Buscar status..."
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
              {selectedStatus ? 'Editar Status' : 'Novo Status'}
            </h2>
            <StatusForm
              status={selectedStatus || undefined}
              onSuccess={() => {
                setShowForm(false);
                fetchStatuses();
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
                  Descrição
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                    Carregando...
                  </td>
                </tr>
              ) : filteredStatuses.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                    Nenhum status encontrado
                  </td>
                </tr>
              ) : (
                filteredStatuses.map((status) => (
                  <tr key={status.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {status.name}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-500">
                        {status.description || '-'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        status.is_active 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {status.is_active ? 'Ativo' : 'Inativo'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => {
                            setSelectedStatus(status);
                            setShowForm(true);
                          }}
                          className="text-blue-600 hover:text-blue-900"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(status.id)}
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