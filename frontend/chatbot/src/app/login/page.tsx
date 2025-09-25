"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";

export default function LoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const router = useRouter();
  const { login } = useAuth();

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setError("请输入用户名和密码");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const response = await fetch("/api/user/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ username, password }),
      });

      const contentType = response.headers.get("content-type") || "";
      type LoginSuccessA = { token: string; user: { username: string } };
      type LoginSuccessB = { token: string; userInfo: { username: string } };
      type LoginSuccess = LoginSuccessA | LoginSuccessB;
      type LoginError = { error?: string; message?: string };
      type LoginPayload = LoginSuccess | LoginError;
      const isLoginSuccess = (p: unknown): p is LoginSuccess => {
        if (!p || typeof p !== "object") return false;
        const obj = p as Record<string, unknown>;
        const hasToken = "token" in obj;
        const hasUser = "user" in obj && typeof (obj as any).user === "object";
        const hasUserInfo = "userInfo" in obj && typeof (obj as any).userInfo === "object";
        return !!(hasToken && (hasUser || hasUserInfo));
      };
      let payload: LoginPayload | null = null;
      if (contentType.includes("application/json")) {
        payload = await response.json();
      } else {
        const text = await response.text();
        if (!response.ok) {
          throw new Error(text || `登录失败 (HTTP ${response.status})`);
        }
        throw new Error(text || "登录失败");
      }

      if (!response.ok) {
        let msg = `登录失败 (HTTP ${response.status})`;
        if (payload && typeof payload === 'object' && 'error' in payload && (payload as LoginError).error) {
          msg = (payload as LoginError).error as string;
        } else if (payload && typeof payload === 'object' && 'message' in payload && (payload as LoginError).message) {
          msg = (payload as LoginError).message as string;
        }
        throw new Error(msg);
      }

      // 使用 AuthContext 的 login 方法更新认证状态
      // 类型收窄
      if (!isLoginSuccess(payload)) {
        throw new Error('登录响应格式不正确');
      }
      const userObj = 'user' in payload ? payload.user : (payload as LoginSuccessB).userInfo;
      login(payload.token, { username: userObj.username });

      // 跳转到聊天页面
      router.push("/chat");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
      <div className="max-w-md w-full space-y-8 p-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900 dark:text-white">
            登录到 AI Chatbot
          </h2>
        </div>
        <form className="mt-8 space-y-6" onSubmit={handleLogin}>
          <div className="space-y-4">
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                用户名
              </label>
              <input
                id="username"
                name="username"
                type="text"
                required
                className="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-800 dark:text-white"
                placeholder="请输入用户名"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                disabled={loading}
              />
            </div>
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                密码
              </label>
              <input
                id="password"
                name="password"
                type="password"
                required
                className="mt-1 block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-800 dark:text-white"
                placeholder="请输入密码"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={loading}
              />
            </div>
          </div>

          {error && (
            <div className="text-red-600 text-sm text-center">{error}</div>
          )}

          <div>
            <button
              type="submit"
              disabled={loading}
              className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "登录中..." : "登录"}
            </button>
          </div>

          <div className="text-center">
            <a
              href="/register"
              className="text-blue-600 hover:text-blue-500 text-sm"
            >
              还没有账号？立即注册
            </a>
          </div>
        </form>
      </div>
    </div>
  );
}

