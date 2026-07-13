"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getCoin, getMoney, getPayments } from "@/lib/api";
import type {
  CoinEntry,
  Device,
  LoginResponse,
  MoneyEntry,
  PaymentEntry,
} from "@/lib/types";

function formatDate(value: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("ru-RU");
}

function formatMoney(value: number) {
  return new Intl.NumberFormat("ru-RU").format(value);
}

function toDateInputValue(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function isWithinRange(value: string | null, from: string, to: string) {
  if (!value) return false;

  const time = new Date(value).getTime();
  if (Number.isNaN(time)) return false;

  if (from) {
    const fromTime = new Date(`${from}T00:00:00`).getTime();
    if (time < fromTime) return false;
  }

  if (to) {
    const toTime = new Date(`${to}T23:59:59.999`).getTime();
    if (time > toTime) return false;
  }

  return true;
}

interface DeviceData {
  money: MoneyEntry[];
  payMoneyTotal: number;
  coin: CoinEntry[];
  payCoinTotal: number;
  payments: PaymentEntry[];
  sumTotal: number;
  loading: boolean;
  error: string | null;
}

export default function DeviceHistoryPage() {
  const router = useRouter();
  const params = useParams<{ account: string }>();
  const account = decodeURIComponent(params.account);

  const [device, setDevice] = useState<Device | null>(null);
  const [data, setData] = useState<DeviceData>({
    money: [],
    payMoneyTotal: 0,
    coin: [],
    payCoinTotal: 0,
    payments: [],
    sumTotal: 0,
    loading: true,
    error: null,
  });

  const [dateFrom, setDateFrom] = useState(() => {
    const now = new Date();
    return toDateInputValue(new Date(now.getFullYear(), now.getMonth(), 1));
  });
  const [dateTo, setDateTo] = useState(() => toDateInputValue(new Date()));

  useEffect(() => {
    const raw = sessionStorage.getItem("session");
    if (!raw) {
      router.replace("/");
      return;
    }

    const session = JSON.parse(raw) as LoginResponse;
    const found = session.devices.find((d) => d.account === account);
    if (!found) {
      router.replace("/dashboard");
      return;
    }

    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncing from sessionStorage on mount
    setDevice(found);
  }, [router, account]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- kicking off a fetch triggered by account change
    setData((prev) => ({ ...prev, loading: true, error: null }));

    Promise.all([getMoney(account), getCoin(account), getPayments(account)])
      .then(([moneyRes, coinRes, paymentsRes]) => {
        setData({
          money: moneyRes.money,
          payMoneyTotal: moneyRes.pay_money_total,
          coin: coinRes.coin,
          payCoinTotal: coinRes.pay_coin_total,
          payments: paymentsRes.payments,
          sumTotal: paymentsRes.sum_total,
          loading: false,
          error: null,
        });
      })
      .catch((err) => {
        setData((prev) => ({
          ...prev,
          loading: false,
          error: err instanceof Error ? err.message : "Ошибка загрузки данных",
        }));
      });
  }, [account]);

  if (!device) return null;

  const filteredMoney = data.money.filter((m) =>
    isWithinRange(m.created_at, dateFrom, dateTo),
  );
  const filteredCoin = data.coin.filter((c) =>
    isWithinRange(c.created_at, dateFrom, dateTo),
  );
  const filteredPayments = data.payments.filter((p) =>
    isWithinRange(p.created, dateFrom, dateTo),
  );

  const payMoneyTotal = filteredMoney.reduce((sum, m) => sum + m.pay_money, 0);
  const payCoinTotal = filteredCoin.reduce((sum, c) => sum + c.pay_coin, 0);
  const sumTotal = filteredPayments.reduce((sum, p) => sum + p.sum, 0);
  const total = payMoneyTotal + payCoinTotal + sumTotal;

  return (
    <div className="mx-auto w-full max-w-5xl flex-1 px-6 py-10">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <Link
            href="/dashboard"
            className="mb-2 inline-block text-sm text-zinc-500 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-200"
          >
            ← Назад
          </Link>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-zinc-50">
            {device.device_name || device.account} (№{device.account})
          </h1>
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            {device.status ? "активно" : "неактивно"}
          </p>
        </div>
      </div>

      <div className="mb-6 flex items-center gap-2 rounded-xl border border-black/[.08] bg-white p-3 shadow-sm dark:border-white/[.145] dark:bg-zinc-900">
        <CalendarIcon />
        <input
          type="date"
          value={dateFrom}
          onChange={(e) => setDateFrom(e.target.value)}
          className="rounded-md border border-black/[.08] bg-transparent px-2 py-1 text-sm text-zinc-900 dark:border-white/[.145] dark:text-zinc-50"
        />
        <span className="text-sm text-zinc-500 dark:text-zinc-400">—</span>
        <input
          type="date"
          value={dateTo}
          onChange={(e) => setDateTo(e.target.value)}
          className="rounded-md border border-black/[.08] bg-transparent px-2 py-1 text-sm text-zinc-900 dark:border-white/[.145] dark:text-zinc-50"
        />
      </div>

      {data.error && (
        <p className="mb-4 text-sm text-red-600 dark:text-red-400">
          {data.error}
        </p>
      )}

      <div className="mb-6 flex items-center justify-between rounded-xl border border-black/[.08] bg-white p-5 text-lg font-semibold text-zinc-900 shadow-sm dark:border-white/[.145] dark:bg-zinc-900 dark:text-zinc-50">
        <span>Итог</span>
        <span>{data.loading ? "…" : `${formatMoney(total)} тг`}</span>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <HistoryColumn
          title="Купюры"
          loading={data.loading}
          rows={filteredMoney.map((m) => ({
            id: m.id,
            date: formatDate(m.created_at),
            amount: m.pay_money,
          }))}
        />
        <HistoryColumn
          title="Монеты"
          loading={data.loading}
          rows={filteredCoin.map((c) => ({
            id: c.id,
            date: formatDate(c.created_at),
            amount: c.pay_coin,
          }))}
        />
        <HistoryColumn
          title="Платежи"
          loading={data.loading}
          rows={filteredPayments.map((p) => ({
            id: p.id,
            date: formatDate(p.created),
            amount: p.sum,
          }))}
        />
      </div>
    </div>
  );
}

function CalendarIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="h-4 w-4 shrink-0 text-zinc-400 dark:text-zinc-500"
      fill="currentColor"
    >
      <path
        fillRule="evenodd"
        d="M6 1.75a.75.75 0 0 1 .75.75V3h6.5v-.5a.75.75 0 0 1 1.5 0V3h.75A2.25 2.25 0 0 1 17 5.25v9.5A2.25 2.25 0 0 1 14.75 17H5.25A2.25 2.25 0 0 1 3 14.75v-9.5A2.25 2.25 0 0 1 5.25 3H6v-.5A.75.75 0 0 1 6 1.75ZM4.5 8v6.75c0 .414.336.75.75.75h9.5a.75.75 0 0 0 .75-.75V8h-11Z"
        clipRule="evenodd"
      />
    </svg>
  );
}

function HistoryColumn({
  title,
  rows,
  loading,
}: {
  title: string;
  rows: { id: number; date: string; amount: number }[];
  loading: boolean;
}) {
  return (
    <div className="rounded-xl border border-black/[.08] bg-white p-5 shadow-sm dark:border-white/[.145] dark:bg-zinc-900">
      <h3 className="mb-3 text-sm font-medium text-zinc-600 dark:text-zinc-400">
        {title}
      </h3>

      <div className="max-h-[28rem] space-y-1 overflow-y-auto text-sm">
        {loading && (
          <p className="text-zinc-400 dark:text-zinc-500">Загрузка...</p>
        )}
        {!loading && rows.length === 0 && (
          <p className="text-zinc-400 dark:text-zinc-500">Нет записей</p>
        )}
        {!loading &&
          rows.map((row) => (
            <div
              key={row.id}
              className="flex items-center justify-between border-b border-black/[.04] py-1.5 last:border-0 dark:border-white/[.06]"
            >
              <span className="text-zinc-500 dark:text-zinc-400">
                {row.date}
              </span>
              <span className="font-medium text-zinc-900 dark:text-zinc-50">
                {formatMoney(row.amount)} тг
              </span>
            </div>
          ))}
      </div>
    </div>
  );
}
