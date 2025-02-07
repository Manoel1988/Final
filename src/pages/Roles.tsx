import React, { useState, useEffect } from 'react';
import { Plus, Search, Edit2, Trash2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import type { Role } from '../types/role';
import { AVAILABLE_PAGES } from '../types/role';

interface RoleFormProps {
  role?: Role;
  onSuccess: () => void;
  onCancel: () => void;
}

function RoleForm({ role, onSuccess, onCancel }: RoleFormProps) {
  const [formData, setFormData] = useState({
    name: role?.name || '',
    description: role?.description || '',
    permissions: new Set<string>(),
    status: role?.status || 'active'
  });

  useEffect(() => {
    if (role) {
      fetchRolePermissions();
    }
  }, [role]);

  const fetchRolePermissions = async () => {
    try {
      const { data: permissions } = await supabase
        .from('role_permissions')
        .select('page')
        .eq('role_id', role!.id);

      if (permissions) {
        setFormData(prev => ({
          ...prev,
          permissions: new Set(permissions.map(p => p.page))
        }));
      }
    } catch (error) {
      console.error('Erro ao buscar permissões:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      let roleId = role?.id;

      if (!role) {
        const { data: newRole, error: roleError } = await supabase
          .from('roles')
          .insert([{
            name: formData.name,
            description: formData.description,
            status: formData.status
          }])
          .select()
          .single();

        if (roleError) throw roleError;
        roleId = newRole.id;
      } else {
        const { error: roleError } = await supabase
          .from('roles')
          .update({
            name: formData.name,
            description: formData.description,
            status: formData.status
          })
          .eq('id', role.id);

        if (roleError) throw roleError;
      }

      if (role) {
        await supabase
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId);
      }

      if (formData.permissions.size > 0) {
        const { error: permError } = await supabase
          .from('role_permissions')
          .insert(
            Array.from(formData.permissions).map(page => ({
              role_id: roleId,
              page
            }))
          );

        if (permError) throw permError;
      }

      onSuccess();
    } catch (error) {
      console.error('Erro ao salvar cargo:', error);
      alert('Erro ao salvar cargo. Por favor, tente novamente.');
    }
  };

  const togglePermission = (page: string) => {
    setFormData(prev => {
      const newPermissions = new Set(prev.permissions);
      if (newPermissions.has(page)) {
        newPermissions.delete(page);
      } else {
        newPermissions.add(page);
      }
      return { ...prev, permissions: newPermissions };
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Nome do Cargo</label>
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
          value={formData.description}
          onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          rows={3}
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Permissões de Acesso</label>
        <div className="space-y-2">
          {AVAILABLE_PAGES.map(page => (
            <label key={page.id} className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={formData.permissions.has(page.id)}
                onChange={() => togglePermission(page.id)}
                className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
              <span className="text-sm text-gray-700">{page.name}</span>
            </label>
          ))}
        </div>
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
          {role ? 'Atualizar' : 'Criar'} Cargo
        </button>
      </div>
    </form>
  );
}

export function Roles() {
  const [roles, setRoles] = useState<Role[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchRoles = async () => {
    try {
      const { data, error } = await supabase
        .from('roles')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setRoles(data || []);
      setError(null);
    } catch (error) {
      console.error('Erro ao buscar cargos:', error);
      setError('Erro ao carregar cargos. Por favor, tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchRoles();
  }, []);

  const handleDelete = async (id: string) => {
    if (!confirm('Tem certeza que deseja excluir este cargo?')) return;
    
    try {
      const { error } = await supabase
        .from('roles')
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      await fetchRoles();
    } catch (error) {
      console.error('Erro ao excluir cargo:', error);
      setError('Erro ao excluir cargo. Por favor, tente novamente.');
    }
  };

  const filteredRoles = roles.filter(role =>
    role.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    role.description?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <h1 className="text-2xl font-semibold text-gray-800">Cargos</h1>
        <button
          onClick={() => {
            setSelectedRole(null);
            setShowForm(true);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus className="w-4 h-4" />
          Novo Cargo
        </button>
      </div>

      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder="Buscar cargos..."
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
              {selectedRole ? 'Editar Cargo' : 'Novo Cargo'}
            </h2>
            <RoleForm
              role={selectedRole || undefined}
              onSuccess={() => {
                setShowForm(false);
                fetchRoles();
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
              ) : filteredRoles.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                    Nenhum cargo encontrado
                  </td>
                </tr>
              ) : (
                filteredRoles.map((role) => (
                  <tr key={role.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {role.name}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-500">
                        {role.description || '-'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        role.status === 'active'
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {role.status === 'active' ? 'Ativo' : 'Inativo'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => {
                            setSelectedRole(role);
                            setShowForm(true);
                          }}
                          className="text-blue-600 hover:text-blue-900"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(role.id)}
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

export { Roles }