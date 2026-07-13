"use client";

import { useEffect, useState } from "react";
import { getHealth } from "@/lib/api";

const CHECK_INTERVAL_MS = 15000;

export default function DbStatusBanner() {
  const [dbDown, setDbDown] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function check() {
      const health = await getHealth();
      if (!cancelled) {
        setDbDown(!health.db);
      }
    }

    check();
    const timer = setInterval(check, CHECK_INTERVAL_MS);

    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  if (!dbDown) {
    return null;
  }

  return (
    <div className="w-full bg-red-600 px-4 py-2 text-center text-sm font-medium text-white">
      Нет подключения к базе данных. Некоторые функции могут быть недоступны.
    </div>
  );
}
