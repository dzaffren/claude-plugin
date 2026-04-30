export function login(email: string, password: string): { ok: boolean } {
  if (!email.includes("@") || password.length < 8) return { ok: false };
  return { ok: true };
}
