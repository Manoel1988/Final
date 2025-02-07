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
  status?: {
    id: string;
    name: string;
    description: string | null;
    is_active: boolean;
  };
  team_leader_a?: {
    id: string;
    name: string;
    status: string;
  };
  team_leader_b?: {
    id: string;
    name: string;
    status: string;
  };
}