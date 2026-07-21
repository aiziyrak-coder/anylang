export type AdminLoginResponse = {
  access_token: string;
  token_type: string;
  expires_in: number;
  admin: {
    id: number;
    email: string;
    full_name: string;
    role: string;
  };
};

export type AdminUser = {
  id: number;
  full_name: string;
  email: string;
  number: string;
  is_active: boolean;
  is_verified: boolean;
  verified_badge: boolean;
  created_at: string;
};

export type AdminUserListResponse = {
  items: AdminUser[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
};

export type AdminStats = {
  users_total: number;
  users_active: number;
  subscriptions_active: number;
  products_published: number;
  products_archived: number;
  chats_total: number;
  messages_total: number;
  number_groups_total: number;
};

export type NumberGroup = {
  id: number;
  name: string;
  patterns: string[];
  price: string;
  currency: string;
  bonus_plan: string | null;
  bonus_duration_months: number | null;
  priority: number;
  is_active: boolean;
};
