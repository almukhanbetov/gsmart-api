import type {
  CoinResponse,
  HealthResponse,
  LoginResponse,
  MoneyResponse,
  PaymentsResponse,
} from "./types";

async function parseOrThrow<T>(res: Response): Promise<T> {
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error ?? "Ошибка запроса");
  }
  return data as T;
}

export async function login(phone: string, password: string) {
  const res = await fetch("/api/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ phone, password }),
  });
  return parseOrThrow<LoginResponse>(res);
}

export async function getMoney(account: string) {
  const res = await fetch(`/api/money/${account}`);
  return parseOrThrow<MoneyResponse>(res);
}

export async function getCoin(account: string) {
  const res = await fetch(`/api/coin/${account}`);
  return parseOrThrow<CoinResponse>(res);
}

export async function getPayments(account: string) {
  const res = await fetch(`/api/payments/${account}`);
  return parseOrThrow<PaymentsResponse>(res);
}

export async function getHealth(): Promise<HealthResponse> {
  try {
    const res = await fetch("/api/health", { cache: "no-store" });
    return (await res.json()) as HealthResponse;
  } catch {
    return { db: false };
  }
}
