export interface User {
  id: number;
  phone: string;
  fullname: string;
  user_code: number;
  bin: string;
}

export interface Device {
  id: number;
  account: string;
  user_code: number;
  device_name: string;
  type: number;
  bin: string;
  gruppa: string;
  device_status: boolean;
  server_status: boolean;
  abon_time: string | null;
  summa: number;
  signal_wifi: string;
  status: boolean;
  data_status: string | null;
  data_inkas: string | null;
}

export interface MoneyEntry {
  id: number;
  account: number;
  pay_money: number;
  created_at: string;
}

export interface CoinEntry {
  id: number;
  account: number;
  pay_coin: number;
  created_at: string;
}

export interface PaymentEntry {
  id: number;
  txn_id: string;
  account: string;
  sum: number;
  result: number;
  comment: string;
  created: string | null;
}

export interface LoginResponse {
  message: string;
  user: User;
  devices: Device[];
  money: MoneyEntry[];
  coin: CoinEntry[];
  payments: PaymentEntry[];
}

export interface MoneyResponse {
  money: MoneyEntry[];
  pay_money_total: number;
}

export interface CoinResponse {
  coin: CoinEntry[];
  pay_coin_total: number;
}

export interface PaymentsResponse {
  payments: PaymentEntry[];
  sum_total: number;
}

export interface HealthResponse {
  db: boolean;
}
