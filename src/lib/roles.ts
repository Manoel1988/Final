import { pool, generateUUID } from './db';

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

export async function getRoles(): Promise<Role[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(
      'SELECT * FROM roles ORDER BY name'
    );
    return rows as Role[];
  } finally {
    connection.release();
  }
}

export async function getRoleWithPermissions(roleId: string): Promise<Role & { permissions: string[] }> {
  const connection = await pool.getConnection();
  try {
    const [roles] = await connection.execute(
      'SELECT * FROM roles WHERE id = ?',
      [roleId]
    );

    const [permissions] = await connection.execute(
      'SELECT page FROM role_permissions WHERE role_id = ?',
      [roleId]
    );

    const role = (roles as Role[])[0];
    return {
      ...role,
      permissions: (permissions as { page: string }[]).map(p => p.page)
    };
  } finally {
    connection.release();
  }
}

export async function createRole(
  role: Omit<Role, 'id' | 'created_at' | 'updated_at'>,
  permissions: string[]
): Promise<Role> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const id = generateUUID();
    await connection.execute(
      'INSERT INTO roles (id, name, description, status) VALUES (?, ?, ?, ?)',
      [id, role.name, role.description, role.status]
    );

    // Insert permissions
    if (permissions.length > 0) {
      const permissionValues = permissions.map(page => [generateUUID(), id, page]);
      await connection.query(
        'INSERT INTO role_permissions (id, role_id, page) VALUES ?',
        [permissionValues]
      );
    }

    await connection.commit();

    const [rows] = await connection.execute(
      'SELECT * FROM roles WHERE id = ?',
      [id]
    );

    return (rows as Role[])[0];
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

export async function updateRole(
  id: string,
  role: Partial<Role>,
  permissions?: string[]
): Promise<Role> {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const updates: string[] = [];
    const values: any[] = [];

    Object.entries(role).forEach(([key, value]) => {
      if (value !== undefined && key !== 'id' && key !== 'created_at' && key !== 'updated_at') {
        updates.push(`${key} = ?`);
        values.push(value);
      }
    });

    if (updates.length > 0) {
      values.push(id);
      await connection.execute(
        `UPDATE roles SET ${updates.join(', ')} WHERE id = ?`,
        values
      );
    }

    if (permissions) {
      await connection.execute(
        'DELETE FROM role_permissions WHERE role_id = ?',
        [id]
      );

      if (permissions.length > 0) {
        const permissionValues = permissions.map(page => [generateUUID(), id, page]);
        await connection.query(
          'INSERT INTO role_permissions (id, role_id, page) VALUES ?',
          [permissionValues]
        );
      }
    }

    await connection.commit();

    const [rows] = await connection.execute(
      'SELECT * FROM roles WHERE id = ?',
      [id]
    );

    return (rows as Role[])[0];
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

export async function deleteRole(id: string): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.execute(
      'DELETE FROM roles WHERE id = ?',
      [id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Role not found');
    }
  } finally {
    connection.release();
  }
}