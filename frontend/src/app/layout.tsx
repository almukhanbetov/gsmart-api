import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import DbStatusBanner from "@/components/DbStatusBanner";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Smart24",
  description: "Личный кабинет Smart24: пополнения и платежи",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body
        className="min-h-full flex flex-col"
        suppressHydrationWarning
      >
        <DbStatusBanner />
        {children}
      </body>
    </html>
  );
}
