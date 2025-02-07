import { pool, generateUUID, formatDate } from './db';

export interface Company {
  id: string;
  name: string;
  legal_name: string;
  contract_start: string;
  contract_end: string;
  created_at: string;
  updated_at: string;
  user_id: string;
  status_id: string | null;
  team_leader_a_id: string | null;
  team_leader_b_id: string | null;
}

export async function getCompanies(): Promise<Company[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(
      `SELECT c.*, 
        cs.name as status_name, 
        cs.is_active as status_is_active,
        tla.name as team_leader_a_name,
        tlb.name as team_leader_b_name
      FROM companies c
      LEFT JOIN company_statuses cs ON c.status_id = cs.id
      LEFT JOIN team_leaders tla ON c.team_leader_a_id = tla.id
      LEFT JOIN team_leaders tlb ON c.team_leader_b_id = tlb.id
      ORDER BY c.name`
    );
    return rows as Company[];
  } finally {
    connection.release();
  }
}

export async function createCompany(company: Omit<Company, 'id' | 'created_at' | 'updated_at'>): Promise<Company> {
  const connection = await pool.getConnection();
  try {
    const id = generateUUID();
    await connection.execute(
      `INSERT INTO companies (
        id, name, legal_name, contract_start, contract_end, 
        user_id, status_id, team_leader_a_id, team_leader_b_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        company.name,
        company.legal_name,
        formatDate(company.contract_start),
        formatDate(company.contract_end),
        company.user_id,
        company.status_id,
        company.team_leader_a_id,
        company.team_leader_b_id
      ]
    );

    const [rows] = await connection.execute(
      'SELECT * FROM companies WHERE id = ?',
      [id]
    );

    return (rows as Company[])[0];
  } finally {
    connection.release();
  }
}

export async function updateCompany(id: string, company: Partial<Company>): Promise<Company> {
  const connection = await pool.getConnection();
  try {
    const updates: string[] = [];
    const values: any[] = [];

    Object.entries(company).forEach(([key, value]) => {
      if (value !== undefined && key !== 'id' && key !== 'created_at' && key !== 'updated_at') {
        updates.push(`${key} = ?`);
        values.push(key.includes('date') ? formatDate(value) : value);
      }
    });

    if (updates.length === 0) {
      throw new Error('No updates provided');
    }

    values.push(id);

    await connection.execute(
      `UPDATE companies SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [rows] = await connection.execute(
      'SELECT * FROM companies WHERE id = ?',
      [id]
    );

    return (rows as Company[])[0];
  } finally {
    connection.release();
  }
}

export async function deleteCompany(id: string): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.execute(
      'DELETE FROM companies WHERE id = ?',
      [id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Company not found');
    }
  } finally {
    connection.release();
  }
}