import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { pool, generateUUID } from './db';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

export interface User {
  id: string;
  email: string;
  raw_user_meta_data: {
    permission: string;
  };
  role_id: string | null;
  created_at: string;
  updated_at: string;
}

export async function signUp(email: string, password: string): Promise<User> {
  const connection = await pool.getConnection();
  try {
    // Check if user exists
    const [existingUsers] = await connection.execute(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (Array.isArray(existingUsers) && existingUsers.length > 0) {
      throw new Error('User already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = generateUUID();
    const metadata = JSON.stringify({ permission: 'user' });

    // Insert new user
    await connection.execute(
      'INSERT INTO users (id, email, raw_user_meta_data) VALUES (?, ?, ?)',
      [userId, email, metadata]
    );

    // Get the created user
    const [users] = await connection.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    return (users as User[])[0];
  } finally {
    connection.release();
  }
}

export async function signIn(email: string, password: string): Promise<{ user: User; token: string }> {
  const connection = await pool.getConnection();
  try {
    // Get user
    const [users] = await connection.execute(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    const user = (users as any[])[0];
    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Create token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email,
        permission: user.raw_user_meta_data.permission 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    return { user, token };
  } finally {
    connection.release();
  }
}

export async function verifyToken(token: string): Promise<User> {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const connection = await pool.getConnection();
    try {
      const [users] = await connection.execute(
        'SELECT * FROM users WHERE id = ?',
        [decoded.userId]
      );

      const user = (users as User[])[0];
      if (!user) {
        throw new Error('User not found');
      }

      return user;
    } finally {
      connection.release();
    }
  } catch (error) {
    throw new Error('Invalid token');
  }
}

export async function updateUser(
  userId: string,
  data: Partial<{ email: string; role_id: string; raw_user_meta_data: any }>
): Promise<User> {
  const connection = await pool.getConnection();
  try {
    const updates: string[] = [];
    const values: any[] = [];

    if (data.email) {
      updates.push('email = ?');
      values.push(data.email);
    }
    if (data.role_id) {
      updates.push('role_id = ?');
      values.push(data.role_id);
    }
    if (data.raw_user_meta_data) {
      updates.push('raw_user_meta_data = ?');
      values.push(JSON.stringify(data.raw_user_meta_data));
    }

    if (updates.length === 0) {
      throw new Error('No updates provided');
    }

    values.push(userId);

    await connection.execute(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [users] = await connection.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    return (users as User[])[0];
  } finally {
    connection.release();
  }
}