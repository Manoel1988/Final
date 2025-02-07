export interface Role {
  id: string;
  name: string;
  description: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface RolePermission {
  id: string;
  role_id: string;
  page: string;
  created_at: string;
}

export const AVAILABLE_PAGES = [
  { id: 'home', name: 'Início' },
  { id: 'companies', name: 'Empresas' },
  { id: 'users', name: 'Usuários' },
  { id: 'team-leaders', name: 'Líderes de Equipe' },
  { id: 'settings', name: 'Configurações' },
  { id: 'help', name: 'Ajuda' }
] as const;