import { pool, generateUUID, formatDate } from './db';

export interface TeamLeader {
  id: string;
  user_id: string;
  name: string;
  status: 'active' | 'inactive';
  squad_name: string;
  bio: string | null;
  phone: string | null;
  start_date: string;
  end_date: string | null;
  created_at: string;
  updated_at: string;
  companies_count?: number;
}

export async function getTeamLeaders(): Promise<TeamLeader[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(`
      SELECT tl.*,
        (SELECT COUNT(DISTINCT c.id)
         FROM companies c
         JOIN company_statuses cs ON c.status_id = cs.id
         WHERE cs.is_active = TRUE
         AND (c.team_leader_a_id = tl.id OR c.team_leader_b_id = tl.id)
        ) as companies_count
      FROM team_leaders tl
      ORDER BY tl.name
    `);
    return rows as TeamLeader[];
  } finally {
    connection.release();
  }
}

export async function createTeamLeader(teamLeader: Omit<TeamLeader, 'id' | 'created_at' | 'updated_at'>): Promise<TeamLeader> {
  const connection = await pool.getConnection();
  try {
    const id = generateUUID();
    await connection.execute(
      `INSERT INTO team_leaders (
        id, user_id, name, status, squad_name, bio, phone, start_date, end_date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        teamLeader.user_id,
        teamLeader.name,
        teamLeader.status,
        teamLeader.squad_name,
        teamLeader.bio,
        teamLeader.phone,
        formatDate(teamLeader.start_date),
        teamLeader.end_date ? formatDate(teamLeader.end_date) : null
      ]
    );

    const [rows] = await connection.execute(
      'SELECT * FROM team_leaders WHERE id = ?',
      [id]
    );

    return (rows as TeamLeader[])[0];
  } finally {
    connection.release();
  }
}

export async function updateTeamLeader(id: string, teamLeader: Partial<TeamLeader>): Promise<TeamLeader> {
  const connection = await pool.getConnection();
  try {
    const updates: string[] = [];
    const values: any[] = [];

    Object.entries(teamLeader).forEach(([key, value]) => {
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
      `UPDATE team_leaders SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [rows] = await connection.execute(
      'SELECT * FROM team_leaders WHERE id = ?',
      [id]
    );

    return (rows as TeamLeader[])[0];
  } finally {
    connection.release();
  }
}

export async function deleteTeamLeader(id: string): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.execute(
      'DELETE FROM team_leaders WHERE id = ?',
      [id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Team leader not found');
    }
  } finally {
    connection.release();
  }
}