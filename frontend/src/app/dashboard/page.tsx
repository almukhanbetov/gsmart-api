"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getCoin, getMoney, getPayments } from "@/lib/api";
import type { Device, LoginResponse, User } from "@/lib/types";

function formatMoney(value: number) {
  return new Intl.NumberFormat("ru-RU").format(value);
}

function signalQuality(raw: string): number | null {
  const dbm = Number(raw);
  if (Number.isNaN(dbm)) return null;
  if (dbm <= -100) return 0;
  if (dbm >= -50) return 100;
  return Math.round(2 * (dbm + 100));
}

function isToday(value: string | null) {
  if (!value) return false;

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return false;

  const now = new Date();
  return (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  );
}

interface DeviceData {
  payMoneyTotal: number;
  payCoinTotal: number;
  sumTotal: number;
  loading: boolean;
  error: string | null;
}

export default function DashboardPage() {
  const router = useRouter();

  const [user, setUser] = useState<User | null>(null);
  const [devices, setDevices] = useState<Device[]>([]);
  const [dataByAccount, setDataByAccount] = useState<
    Record<string, DeviceData>
  >({});

  useEffect(() => {
    const raw = sessionStorage.getItem("session");
    if (!raw) {
      router.replace("/");
      return;
    }

    const session = JSON.parse(raw) as LoginResponse;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- syncing from sessionStorage on mount
    setUser(session.user);
    setDevices(session.devices);
  }, [router]);

  useEffect(() => {
    devices.forEach((device) => {
      const account = device.account;

      setDataByAccount((prev) => ({
        ...prev,
        [account]: {
          payMoneyTotal: prev[account]?.payMoneyTotal ?? 0,
          payCoinTotal: prev[account]?.payCoinTotal ?? 0,
          sumTotal: prev[account]?.sumTotal ?? 0,
          loading: true,
          error: null,
        },
      }));

      Promise.all([getMoney(account), getCoin(account), getPayments(account)])
        .then(([moneyRes, coinRes, paymentsRes]) => {
          const payMoneyTotal = moneyRes.money
            .filter((m) => isToday(m.created_at))
            .reduce((sum, m) => sum + m.pay_money, 0);
          const payCoinTotal = coinRes.coin
            .filter((c) => isToday(c.created_at))
            .reduce((sum, c) => sum + c.pay_coin, 0);
          const sumTotal = paymentsRes.payments
            .filter((p) => isToday(p.created))
            .reduce((sum, p) => sum + p.sum, 0);

          setDataByAccount((prev) => ({
            ...prev,
            [account]: {
              payMoneyTotal,
              payCoinTotal,
              sumTotal,
              loading: false,
              error: null,
            },
          }));
        })
        .catch((err) => {
          setDataByAccount((prev) => ({
            ...prev,
            [account]: {
              ...prev[account],
              loading: false,
              error:
                err instanceof Error ? err.message : "Ошибка загрузки данных",
            },
          }));
        });
    });
  }, [devices]);

  function handleLogout() {
    sessionStorage.removeItem("session");
    router.replace("/");
  }

  if (!user) return null;

  return (
    <div className="mx-auto w-full max-w-5xl flex-1 px-6 py-10">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-zinc-50">
            {user.fullname || user.phone}
          </h1>
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Код: {user.user_code} {user.bin && `· БИН: ${user.bin}`}
          </p>
        </div>
        <button
          onClick={handleLogout}
          className="rounded-full border border-black/[.08] px-4 py-2 text-sm text-zinc-700 hover:bg-black/[.04] dark:border-white/[.145] dark:text-zinc-200 dark:hover:bg-[#1a1a1a]"
        >
          Выйти
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {devices.map((device) => (
          <DeviceCard
            key={device.id}
            device={device}
            data={dataByAccount[device.account]}
          />
        ))}
      </div>
    </div>
  );
}

function SignalIcon({ quality }: { quality: number }) {
  const bars = [4, 8, 12, 16];
  const activeBars = Math.ceil((quality / 100) * bars.length);

  return (
    <svg viewBox="0 0 24 16" className="h-4 w-6">
      {bars.map((height, i) => (
        <rect
          key={i}
          x={i * 6}
          y={16 - height}
          width={4}
          height={height}
          rx={1}
          className={
            i < activeBars
              ? "fill-emerald-500"
              : "fill-zinc-300 dark:fill-zinc-700"
          }
        />
      ))}
    </svg>
  );
}

function DeviceCard({
  device,
  data,
}: {
  device: Device;
  data: DeviceData | undefined;
}) {
  const loading = data?.loading ?? true;
  const quality = signalQuality(device.signal_wifi);

  const total =
    (data?.payMoneyTotal ?? 0) +
    (data?.payCoinTotal ?? 0) +
    (data?.sumTotal ?? 0);

  return (
    <Link
      href={`/dashboard/${encodeURIComponent(device.account)}`}
      className="block rounded-xl border border-black/[.08] bg-white p-5 shadow-sm transition-colors hover:border-black/[.15] dark:border-white/[.145] dark:bg-zinc-900 dark:hover:border-white/[.25]"
    >
      <div className="mb-4 flex items-start justify-between">
        <div>
          <h2 className="text-base font-semibold text-zinc-900 dark:text-zinc-50">
            {device.device_name || device.account} (№{device.account})
          </h2>
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            {device.status ? "активно" : "неактивно"}
          </p>
        </div>

        {quality !== null && (
          <div className="flex items-center gap-1.5">
            <SignalIcon quality={quality} />
            <span className="text-xs text-zinc-500 dark:text-zinc-400">
              {quality}%
            </span>
          </div>
        )}
      </div>

      {data?.error && (
        <p className="mb-4 text-sm text-red-600 dark:text-red-400">
          {data.error}
        </p>
      )}

      <p className="mb-2 text-xs text-zinc-400 dark:text-zinc-500">
        Сегодня
      </p>

      <div className="divide-y divide-black/[.06] text-sm dark:divide-white/[.06]">
        <SummaryRow
          label="Купюры"
          value={data?.payMoneyTotal ?? 0}
          loading={loading}
        />
        <SummaryRow
          label="Монеты"
          value={data?.payCoinTotal ?? 0}
          loading={loading}
        />
        <SummaryRow
          label="QR платежи"
          value={data?.sumTotal ?? 0}
          loading={loading}
        />
      </div>

      <div className="mt-3 flex items-center justify-between border-t border-black/[.08] pt-3 text-base font-semibold text-zinc-900 dark:border-white/[.145] dark:text-zinc-50">
        <span>Итог</span>
        <span>{loading ? "…" : `${formatMoney(total)} тг`}</span>
      </div>
    </Link>
  );
}

function SummaryRow({
  label,
  value,
  loading,
}: {
  label: string;
  value: number;
  loading: boolean;
}) {
  return (
    <div className="flex items-center justify-between py-2">
      <span className="text-zinc-500 dark:text-zinc-400">{label}</span>
      <span className="font-medium text-zinc-900 dark:text-zinc-50">
        {loading ? "…" : `${formatMoney(value)} тг`}
      </span>
    </div>
  );
}
