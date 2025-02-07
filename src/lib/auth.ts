import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { pool } from './db';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

export interface User {
  id: string;
  email: string;
  permission: string;
  created_at: string;
}

export async function signUp(email: string, password: string, permission: string = 'user'): Promise<User> {
  const connection = await pool.getConnection();
  try {
    // Check if user exists
    const [existingUsers] = await connection.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (Array.isArray(existingUsers) && existingUsers.length > 0) {
      throw new Error('User already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert new user
    const [result] = await connection.query(
      'INSERT INTO users (email, password, permission) VALUES (?, ?, ?)',
      [email, hashedPassword, permission]
    );

    // Get the created user
    const [users] = await connection.query(
      'SELECT id, email, permission, created_at FROM users WHERE id = ?',
      [(result as any).insertId]
    );

    const user = (users as any[])[0];
    return user;
  } finally {
    connection.release();
  }
}

export async function signIn(email: string, password: string): Promise<{ user: User; token: string }> {
  const connection = await pool.getConnection();
  try {
    // Get user
    const [users] = await connection.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    const user = (users as any[])[0];
    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Check password
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      throw new Error('Invalid credentials');
    }

    // Create token
    const token = jwt.sign(
      { userId: user.id, email: user.email, permission: user.permission },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Return user without password
    const { password: _, ...userWithoutPassword } = user;
    return { user: userWithoutPassword, token };
  } finally {
    connection.release();
  }
}

export async function verifyToken(token: string): Promise<User> {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const connection = await pool.getConnection();
    try {
      const [users] = await connection.query(
        'SELECT id, email, permission, created_at FROM users WHERE id = ?',
        [decoded.userId]
      );

      const user = (users as any[])[0];
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