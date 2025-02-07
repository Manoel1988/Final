import { pool, generateUUID } from './db';

export interface Status {
  id: string;
  name: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CompanyStatus extends Status {}

export async function getCompanyStatuses(): Promise<CompanyStatus[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(
      'SELECT * FROM company_statuses ORDER BY name'
    );
    return rows as CompanyStatus[];
  } finally {
    connection.release();
  }
}

export async function createCompanyStatus(status: Omit<CompanyStatus, 'id' | 'created_at' | 'updated_at'>): Promise<CompanyStatus> {
  const connection = await pool.getConnection();
  try {
    const id = generateUUID();
    await connection.execute(
      'INSERT INTO company_statuses (id, name, description, is_active) VALUES (?, ?, ?, ?)',
      [id, status.name, status.description, status.is_active]
    );

    const [rows] = await connection.execute(
      'SELECT * FROM company_statuses WHERE id = ?',
      [id]
    );

    return (rows as CompanyStatus[])[0];
  } finally {
    connection.release();
  }
}

export async function updateCompanyStatus(id: string, status: Partial<CompanyStatus>): Promise<CompanyStatus> {
  const connection = await pool.getConnection();
  try {
    const updates: string[] = [];
    const values: any[] = [];

    Object.entries(status).forEach(([key, value]) => {
      if (value !== undefined && key !== 'id' && key !== 'created_at' && key !== 'updated_at') {
        updates.push(`${key} = ?`);
        values.push(value);
      }
    });

    if (updates.length === 0) {
      throw new Error('No updates provided');
    }

    values.push(id);

    await connection.execute(
      `UPDATE company_statuses SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [rows] = await connection.execute(
      'SELECT * FROM company_statuses WHERE id = ?',
      [id]
    );

    return (rows as CompanyStatus[])[0];
  } finally {
    connection.release();
  }
}

export async function deleteCompanyStatus(id: string): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.execute(
      'DELETE FROM company_statuses WHERE id = ?',
      [id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Status not found');
    }
  } finally {
    connection.release();
  }
}