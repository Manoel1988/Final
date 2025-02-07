import { pool, generateUUID } from './db';

export interface Product {
  id: string;
  name: string;
  description: string | null;
  status: 'active' | 'inactive';
  price: number;
  created_at: string;
  updated_at: string;
}

export async function getProducts(): Promise<Product[]> {
  const connection = await pool.getConnection();
  try {
    const [rows] = await connection.execute(
      'SELECT * FROM products ORDER BY name'
    );
    return rows as Product[];
  } finally {
    connection.release();
  }
}

export async function createProduct(product: Omit<Product, 'id' | 'created_at' | 'updated_at'>): Promise<Product> {
  const connection = await pool.getConnection();
  try {
    const id = generateUUID();
    await connection.execute(
      `INSERT INTO products (
        id, name, description, status, price
      ) VALUES (?, ?, ?, ?, ?)`,
      [
        id,
        product.name,
        product.description,
        product.status,
        product.price
      ]
    );

    const [rows] = await connection.execute(
      'SELECT * FROM products WHERE id = ?',
      [id]
    );

    return (rows as Product[])[0];
  } finally {
    connection.release();
  }
}

export async function updateProduct(id: string, product: Partial<Product>): Promise<Product> {
  const connection = await pool.getConnection();
  try {
    const updates: string[] = [];
    const values: any[] = [];

    Object.entries(product).forEach(([key, value]) => {
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
      `UPDATE products SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [rows] = await connection.execute(
      'SELECT * FROM products WHERE id = ?',
      [id]
    );

    return (rows as Product[])[0];
  } finally {
    connection.release();
  }
}

export async function deleteProduct(id: string): Promise<void> {
  const connection = await pool.getConnection();
  try {
    const [result] = await connection.execute(
      'DELETE FROM products WHERE id = ?',
      [id]
    );

    if ((result as any).affectedRows === 0) {
      throw new Error('Product not found');
    }
  } finally {
    connection.release();
  }
}