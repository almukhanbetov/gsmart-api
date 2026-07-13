"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { login } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const data = await login(phone, password);
      sessionStorage.setItem("session", JSON.stringify(data));
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Ошибка авторизации");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex flex-1 items-center justify-center bg-zinc-50 dark:bg-black">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-xl border border-black/[.08] bg-white p-8 shadow-sm dark:border-white/[.145] dark:bg-zinc-900"
      >
        <h1 className="mb-6 text-xl font-semibold text-zinc-900 dark:text-zinc-50">
          Smart24 — Вход
        </h1>

        <label className="mb-1 block text-sm text-zinc-600 dark:text-zinc-400">
          Телефон
        </label>
        <input
          className="mb-4 w-full rounded-md border border-black/[.08] bg-transparent px-3 py-2 text-zinc-900 outline-none focus:border-zinc-400 dark:border-white/[.145] dark:text-zinc-50"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="87013536087"
          required
        />

        <label className="mb-1 block text-sm text-zinc-600 dark:text-zinc-400">
          Пароль
        </label>
        <input
          type="password"
          className="mb-6 w-full rounded-md border border-black/[.08] bg-transparent px-3 py-2 text-zinc-900 outline-none focus:border-zinc-400 dark:border-white/[.145] dark:text-zinc-50"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />

        {error && (
          <p className="mb-4 text-sm text-red-600 dark:text-red-400">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-full bg-foreground px-5 py-2.5 text-sm font-medium text-background transition-colors hover:bg-[#383838] disabled:opacity-50 dark:hover:bg-[#ccc]"
        >
          {loading ? "Вход..." : "Войти"}
        </button>
      </form>
    </div>
  );
}
