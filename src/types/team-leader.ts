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