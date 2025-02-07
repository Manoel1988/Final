import React, { useState, useEffect } from 'react';
import { Search, ShieldAlert, User as UserIcon, Edit2, Save, X, Mail, Calendar, UserPlus, Trash2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { ErrorBoundary } from '../components/ErrorBoundary';
import type { Role } from '../types/role';

const translations = {
  title: "Gerenciamento de Usuários",
  subtitle: "Gerencie permissões e cargos dos usuários",
  totalUsers: "Total de Usuários",
  administrators: "Administradores",
  regularUsers: "Usuários Comuns",
  searchPlaceholder: "Buscar usuários por e-mail...",
  newUser: "Cadastrar novo usuário",
  noUsersFound: "Nenhum usuário encontrado",
  tryAdjusting: "Tente ajustar os critérios de busca",
  loading: "Carregando...",
  youLabel: "Você",
  regularUser: "Usuário Comum",
  administrator: "Administrador",
  email: "E-mail",
  password: "Senha",
  permission: "Permissão",
  role: "Cargo",
  selectRole: "Selecione um cargo",
  cancel: "Cancelar",
  create: "Criar",
  update: "Atualizar",
  delete: "Excluir",
  save: "Salvar",
  passwordMinLength: "Mínimo de 6 caracteres",
  confirmDelete: "Tem certeza que deseja excluir este usuário?",
  errorMessages: {
    invalidEmail: "Formato de e-mail inválido",
    passwordTooShort: "A senha deve ter pelo menos 6 caracteres",
    selectRole: "Por favor, selecione um cargo",
    permissionDenied: "Permissão negada",
    emailInUse: "E-mail já está em uso",
    createFailed: "Falha ao criar usuário",
    updateFailed: "Erro ao atualizar usuário. Por favor, tente novamente.",
    deleteFailed: "Erro ao excluir usuário. Por favor, tente novamente.",
    inviteFailed: "Erro ao convidar usuário. Por favor, tente novamente.",
    loadFailed: "Erro ao carregar usuários. Por favor, tente novamente."
  }
};

interface User {
  id: string;
  email: string;
  created_at: string;
  raw_user_meta_data: {
    permission?: string;
  };
  role_id: string | null;
  role?: Role;
}

interface EditingUser {
  id: string;
  email: string;
  permission: string;
  role_id: string | null;
}

function UsersContent() {
  const [users, setUsers] = useState<User[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [editingUser, setEditingUser] = useState<EditingUser | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [invitePassword, setInvitePassword] = useState('');
  const [invitePermission, setInvitePermission] = useState('user');
  const [inviteRoleId, setInviteRoleId] = useState<string>('');

  const fetchRoles = async () => {
    try {
      const { data, error } = await supabase
        .from('roles')
        .select('*')
        .order('name');

      if (error) throw error;
      setRoles(data || []);
    } catch (err) {
      console.error('Error fetching roles:', err);
    }
  };

  const fetchCurrentUser = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data, error } = await supabase
          .from('users')
          .select('*, role:roles(*)')
          .eq('id', user.id)
          .single();

        if (error) throw error;
        setCurrentUser(data);
      }
    } catch (err) {
      console.error('Error fetching current user:', err);
    }
  };

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*, role:roles(*)')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setUsers(data || []);
      setError('');
    } catch (err) {
      console.error('Error fetching users:', err);
      setError(translations.errorMessages.loadFailed);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCurrentUser();
    fetchUsers();
    fetchRoles();
  }, []);

  const validateEmail = (email: string) => {
    const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
    return emailRegex.test(email);
  };

  const handleUpdateUser = async () => {
    if (!editingUser) return;

    try {
      const isCurrentUserAdmin = currentUser?.raw_user_meta_data?.permission === 'admin';
      const isSelfUpdate = editingUser.id === currentUser?.id;

      if (!isCurrentUserAdmin && !isSelfUpdate) {
        throw new Error(translations.errorMessages.permissionDenied);
      }

      if (!validateEmail(editingUser.email)) {
        throw new Error(translations.errorMessages.invalidEmail);
      }

      const { error: updateError } = await supabase.rpc('update_user_data', {
        target_user_id: editingUser.id,
        new_email: editingUser.email,
        new_role_id: editingUser.role_id,
        new_metadata: { permission: editingUser.permission }
      });

      if (updateError) throw updateError;

      await fetchUsers();
      if (editingUser.id === currentUser?.id) {
        await fetchCurrentUser();
      }

      setEditingUser(null);
      setError('');
    } catch (err: any) {
      console.error('Error updating user:', err);
      setError(err.message || translations.errorMessages.updateFailed);
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm(translations.confirmDelete)) return;
    
    try {
      const { error } = await supabase.rpc('delete_user_safe', {
        target_user_id: userId
      });
      
      if (error) throw error;
      
      await fetchUsers();
      setError('');
    } catch (err: any) {
      console.error('Error deleting user:', err);
      setError(err.message || translations.errorMessages.deleteFailed);
    }
  };

  const handleInviteUser = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      if (!validateEmail(inviteEmail)) {
        throw new Error(translations.errorMessages.invalidEmail);
      }

      if (invitePassword.length < 6) {
        throw new Error(translations.errorMessages.passwordTooShort);
      }

      if (!inviteRoleId) {
        throw new Error(translations.errorMessages.selectRole);
      }

      const { data: { user }, error: signUpError } = await supabase.auth.signUp({
        email: inviteEmail,
        password: invitePassword,
        options: {
          data: {
            permission: invitePermission
          }
        }
      });

      if (signUpError) throw signUpError;

      if (!user) {
        throw new Error(translations.errorMessages.createFailed);
      }

      const { error: updateError } = await supabase.rpc('update_user_data', {
        target_user_id: user.id,
        new_email: inviteEmail,
        new_role_id: inviteRoleId,
        new_metadata: { permission: invitePermission }
      });

      if (updateError) throw updateError;

      setShowInviteModal(false);
      setInviteEmail('');
      setInvitePassword('');
      setInviteRoleId('');
      setInvitePermission('user');
      alert('Usuário cadastrado com sucesso!');
      await fetchUsers();
    } catch (err: any) {
      console.error('Error inviting user:', err);
      setError(err.message || translations.errorMessages.inviteFailed);
    }
  };

  const filteredUsers = users.filter(user =>
    user.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const adminCount = users.filter(user => 
    user.raw_user_meta_data?.permission === 'admin'
  ).length;

  const regularUserCount = users.length - adminCount;

  const isCurrentUserAdmin = currentUser?.raw_user_meta_data?.permission === 'admin';

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">{translations.title}</h1>
        <p className="text-gray-600">{translations.subtitle}</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">{translations.totalUsers}</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">{users.length}</p>
            </div>
            <div className="bg-blue-50 p-3 rounded-lg">
              <UserIcon className="w-6 h-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">{translations.administrators}</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">{adminCount}</p>
            </div>
            <div className="bg-red-50 p-3 rounded-lg">
              <ShieldAlert className="w-6 h-6 text-red-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">{translations.regularUsers}</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">{regularUserCount}</p>
            </div>
            <div className="bg-green-50 p-3 rounded-lg">
              <UserIcon className="w-6 h-6 text-green-600" />
            </div>
          </div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-6">
        <div className="relative w-full md:w-96">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            type="text"
            placeholder={translations.searchPlaceholder}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10 pr-4 py-2 w-full border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
        
        {isCurrentUserAdmin && (
          <button
            onClick={() => setShowInviteModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors w-full md:w-auto justify-center"
          >
            <UserPlus className="w-4 h-4" />
            {translations.newUser}
          </button>
        )}
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg">
          <div className="flex items-center gap-2">
            <ShieldAlert className="w-5 h-5" />
            <span>{error}</span>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {translations.email}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {translations.permission}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {translations.role}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Data
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ações
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={5} className="px-6 py-4">
                    <div className="flex items-center justify-center">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center">
                    <div className="flex flex-col items-center justify-center text-gray-500">
                      <UserIcon className="w-12 h-12 mb-2" />
                      <p className="text-lg font-medium">{translations.noUsersFound}</p>
                      <p className="text-sm">{translations.tryAdjusting}</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filteredUsers.map(user => {
                  const isAdmin = user.raw_user_meta_data?.permission === 'admin';
                  const isEditing = editingUser?.id === user.id;
                  const canEdit = isCurrentUserAdmin || user.id === currentUser?.id;
                  
                  return (
                    <tr key={user.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          <div className="flex-shrink-0 h-10 w-10 bg-gray-100 rounded-full flex items-center justify-center">
                            <Mail className="w-5 h-5 text-gray-500" />
                          </div>
                          <div className="ml-4">
                            {isEditing ? (
                              <input
                                type="email"
                                value={editingUser.email}
                                onChange={(e) => setEditingUser({ ...editingUser, email: e.target.value })}
                                className="text-sm border rounded-lg px-2 py-1 w-64 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                disabled={!isCurrentUserAdmin && user.id !== currentUser?.id}
                              />
                            ) : (
                              <div className="text-sm font-medium text-gray-900">
                                {user.email}
                                {user.id === currentUser?.id && (
                                  <span className="ml-2 text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full">{translations.youLabel}</span>
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {isEditing ? (
                          <select
                            value={editingUser.permission}
                            onChange={(e) => setEditingUser({ ...editingUser, permission: e.target.value })}
                            className="border rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            disabled={!isCurrentUserAdmin}
                          >
                            <option value="user">{translations.regularUser}</option>
                            <option value="admin">{translations.administrator}</option>
                          </select>
                        ) : (
                          <div className="flex items-center gap-2">
                            {isAdmin ? (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                <ShieldAlert className="w-3.5 h-3.5" />
                                {translations.administrator}
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                <UserIcon className="w-3.5 h-3.5" />
                                {translations.regularUser}
                              </span>
                            )}
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {isEditing ? (
                          <select
                            value={editingUser.role_id || ''}
                            onChange={(e) => setEditingUser({ ...editingUser, role_id: e.target.value || null })}
                            className="border rounded-lg px-3 py-1.5 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                          >
                            <option value="">{translations.selectRole}</option>
                            {roles.map(role => (
                              <option key={role.id} value={role.id}>
                                {role.name}
                              </option>
                            ))}
                          </select>
                        ) : (
                          <div className="text-sm text-gray-500">
                            {user.role?.name || '-'}
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center text-sm text-gray-500 gap-1.5">
                          <Calendar className="w-4 h-4" />
                          {new Date(user.created_at).toLocaleDateString()}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        {(isCurrentUserAdmin || user.id === currentUser?.id) && (
                          isEditing ? (
                            <div className="flex justify-end gap-2">
                              <button
                                onClick={handleUpdateUser}
                                className="text-green-600 hover:text-green-900 p-1 rounded-lg hover:bg-green-50"
                                type="button"
                              >
                                <Save className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => setEditingUser(null)}
                                className="text-gray-600 hover:text-gray-900 p-1 rounded-lg hover:bg-gray-50"
                                type="button"
                              >
                                <X className="w-4 h-4" />
                              </button>
                            </div>
                          ) : (
                            <div className="flex justify-end gap-2">
                              <button
                                onClick={() => setEditingUser({
                                  id: user.id,
                                  email: user.email,
                                  permission: user.raw_user_meta_data?.permission || 'user',
                                  role_id: user.role_id
                                })}
                                className="text-blue-600 hover:text-blue-900 p-1 rounded-lg hover:bg-blue-50"
                                type="button"
                              >
                                <Edit2 className="w-4 h-4" />
                              </button>
                              {isCurrentUserAdmin && user.id !== currentUser?.id && (
                                <button
                                  onClick={() => handleDeleteUser(user.id)}
                                  className="text-red-600 hover:text-red-900 p-1 rounded-lg hover:bg-red-50"
                                  type="button"
                                >
                                  <Trash2 className="w-4 h-4" />
                                </button>
                              )}
                            </div>
                          )
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showInviteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl p-6 max-w-md w-full">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">{translations.newUser}</h2>
            <form onSubmit={handleInviteUser}>
              <div className="space-y-4">
                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                    {translations.email}
                  </label>
                  <input
                    type="email"
                    id="email"
                    value={inviteEmail}
                    onChange={(e) => setInviteEmail(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  />
                </div>
                <div>
                  <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
                    {translations.password}
                  </label>
                  <input
                    type="password"
                    id="password"
                    value={invitePassword}
                    onChange={(e) => setInvitePassword(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                    minLength={6}
                  />
                  <p className="mt-1 text-sm text-gray-500">{translations.passwordMinLength}</p>
                </div>
                <div>
                  <label htmlFor="permission" className="block text-sm font-medium text-gray-700 mb-1">
                    {translations.permission}
                  </label>
                  <select
                    id="permission"
                    value={invitePermission}
                    onChange={(e) => setInvitePermission(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    <option value="user">{translations.regularUser}</option>
                    <option value="admin">{translations.administrator}</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="role" className="block text-sm font-medium text-gray-700 mb-1">
                    {translations.role}
                  </label>
                  <select
                    id="role"
                    value={inviteRoleId}
                    onChange={(e) => setInviteRoleId(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    required
                  >
                    <option value="">{translations.selectRole}</option>
                    {roles.map(role => (
                      <option key={role.id} value={role.id}>
                        {role.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  onClick={() => {
                    setShowInviteModal(false);
                    setInviteEmail('');
                    setInvitePassword('');
                    setInviteRoleId('');
                    setInvitePermission('user');
                  }}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  {translations.cancel}
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  {translations.create}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export function Users() {
  return (
    <ErrorBoundary>
      <UsersContent />
    </ErrorBoundary>
  );
}