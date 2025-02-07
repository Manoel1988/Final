import mysql from 'mysql2/promise';

// Create connection pool
export const pool = mysql.createPool({
  host: process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DATABASE || 'company_management',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true // Return dates as strings to avoid timezone issues
});

// Helper function to check database connection
export async function checkConnection() {
  try {
    const connection = await pool.getConnection();
    connection.release();
    return true;
  } catch (error) {
    console.error('Database connection error:', error);
    return false;
  }
}

// Helper function to generate UUID
export function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Helper function to format date for MySQL
export function formatDate(date: Date | string): string {
  const d = new Date(date);
  return d.toISOString().split('T')[0];
}

// Helper function to execute a query with error handling
export async function executeQuery<T>(
  query: string,
  params?: any[]
): Promise<T> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(query, params);
    return rows as T;
  } finally {
    connection.release();
  }
}

// Helper function to begin a transaction
export async function beginTransaction() {
  const connection = await pool.getConnection();
  await connection.beginTransaction();
  return connection;
}

// Helper function to commit a transaction
export async function commitTransaction(connection: mysql.PoolConnection) {
  try {
    await connection.commit();
  } finally {
    connection.release();
  }
}

// Helper function to rollback a transaction
export async function rollbackTransaction(connection: mysql.PoolConnection) {
  try {
    await connection.rollback();
  } finally {
    connection.release();
  }
}

// Helper function to check if a user is admin
export async function isAdmin(userId: string): Promise<boolean> {
  const [rows] = await pool.execute(
    `SELECT JSON_UNQUOTE(JSON_EXTRACT(raw_user_meta_data, '$.permission')) = 'admin' as is_admin
     FROM users WHERE id = ?`,
    [userId]
  );
  return (rows as any[])[0]?.is_admin || false;
}