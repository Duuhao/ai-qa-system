"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";

type ChatMessage = {
  id: string;
  role: "user" | "assistant";
  content: string;
};

export default function ChatPage() {
  const { user, isAuthenticated, logout } = useAuth();
  const router = useRouter();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);

  function generateId(): string {
    // 优先用浏览器的 crypto.randomUUID（无 any/ts-ignore）
    const g: unknown = globalThis;
    const isObject = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null;
    if (isObject(g)) {
      const maybeCrypto = g["crypto"];
      if (isObject(maybeCrypto)) {
        const ru = (maybeCrypto as Record<string, unknown>)["randomUUID"];
        if (typeof ru === "function") {
          return (ru as () => string)();
        }
      }
    }
    // 兜底：时间戳+随机串
    return `id_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  }

  useEffect(() => {
    if (!isAuthenticated) {
      router.push("/login");
    }
  }, [isAuthenticated, router]);

  async function sendMessage() {
    const text = input.trim();
    if (!text || loading) return;
    setInput("");
    const userMsg: ChatMessage = {
      id: generateId(),
      role: "user",
      content: text,
    };
    setMessages((prev) => [...prev, userMsg]);
    setLoading(true);
    try {
      // 便于排查：控制台打印一次
      console.log("send /api/qa/ask", { question: text, userId: user?.username || "1" });
      const res = await fetch("/api/qa/ask", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ 
          question: text,
          userId: user?.username || "1"
        }),
      });
      if (!res.ok) {
        const errText = await res.text();
        throw new Error(errText || "请求失败");
      }
      const data = (await res.json()) as { answer?: string; error?: string };
      const assistantMsg: ChatMessage = {
        id: generateId(),
        role: "assistant",
        content: data.answer ?? data.error ?? "",
      };
      setMessages((prev) => [...prev, assistantMsg]);
    } catch (e) {
      const assistantMsg: ChatMessage = {
        id: generateId(),
        role: "assistant",
        content: (e as Error).message,
      };
      setMessages((prev) => [...prev, assistantMsg]);
    } finally {
      setLoading(false);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      e.preventDefault();
      void sendMessage();
    }
  }

  if (!isAuthenticated) {
    return null; // 或者显示加载状态
  }

  return (
    <div className="flex flex-col mx-auto w-full max-w-3xl min-h-[100vh] p-4 gap-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-semibold">AI Chatbot</h1>
        <div className="flex items-center gap-4">
          <span className="text-sm text-gray-600 dark:text-gray-400">
            欢迎，{user?.username}
          </span>
          <button
            onClick={() => {
              logout();
              router.push("/login");
            }}
            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
          >
            退出登录
          </button>
        </div>
      </div>
      <div className="flex-1 border rounded-lg p-4 overflow-y-auto bg-white/50 dark:bg-black/20">
        {messages.length === 0 ? (
          <div className="text-sm text-gray-500">开始对话吧～</div>
        ) : (
          <ul className="space-y-3">
            {messages.map((m) => (
              <li key={m.id} className="flex gap-2">
                <span className="shrink-0 select-none text-xs px-2 py-1 rounded bg-gray-200 dark:bg-gray-700">
                  {m.role === "user" ? "你" : "AI"}
                </span>
                <p className="whitespace-pre-wrap break-words">{m.content}</p>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="flex gap-2">
        <input
          className="flex-1 border rounded px-3 py-2"
          placeholder="说点什么..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={loading}
        />
        <button
          onClick={() => void sendMessage()}
          disabled={loading || !input.trim()}
          className="px-4 py-2 rounded bg-black text-white disabled:opacity-50"
        >
          {loading ? "发送中..." : "发送"}
        </button>
      </div>
    </div>
  );
}


