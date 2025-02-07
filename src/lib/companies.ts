import { pool } from './db';

export interface Company {
  id: number;
  name: string;
  legal_name: string;
  contract_start: string;
  contract_end: string;
  created_at: string;
  updated_at: string;
  user_id: number;
}

export async function getCompanies(): Promise<Company[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.query(
      'SELECT * FROM companies ORDER BY name'
    );
    return rows as Company[];
  } finally {
    connection.release();
  }
}

export async function createCompany(company: Omit<Company, 'id' | 'created_at' | 'updated_at'>): Promise<Company> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.query(
      'INSERT INTO companies (name, legal_name, contract_start, contract_end, user_id) VALUES (?, ?, ?, ?, ?)',
      [company.name, company.legal_name, company.contract_start, company.contract_end, company.user_id]
    );

    const [rows] = await connection.query(
      'SELECT * FROM companies WHERE id = ?',
      [(result as any).insertId]
    );

    return (rows as Company[])[0];
  } finally {
    connection.release();
  }
}

export async function updateCompany(id: number, company: Partial<Company>): Promise<Company> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.query(
      'UPDATE companies SET ? WHERE id = ?',
      [company, id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Company not found');
    }

    const [rows] = await connection.query(
      'SELECT * FROM companies WHERE id = ?',
      [id]
    );

    return (rows as Company[])[0];
  } finally {
    connection.release();
  }
}

export async function deleteCompany(id: number): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.query(
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