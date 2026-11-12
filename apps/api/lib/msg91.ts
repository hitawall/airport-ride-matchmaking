import { env } from "./env";

const MSG91_BASE_URL = "https://control.msg91.com/api/v5";

export async function sendOtp(phone: string): Promise<{ requestId: string }> {
  const res = await fetch(`${MSG91_BASE_URL}/otp`, {
    method: "POST",
    headers: { authkey: env.msg91AuthKey, "Content-Type": "application/json" },
    body: JSON.stringify({ template_id: env.msg91TemplateId, mobile: phone }),
  });
  if (!res.ok) throw new Error(`MSG91 send-OTP failed: ${res.status}`);
  const data = (await res.json()) as { request_id?: string; requestId?: string };
  return { requestId: (data.request_id ?? data.requestId)! };
}

export async function verifyOtp(phone: string, code: string): Promise<boolean> {
  const url = new URL(`${MSG91_BASE_URL}/otp/verify`);
  url.searchParams.set("otp", code);
  url.searchParams.set("mobile", phone);
  const res = await fetch(url, {
    method: "GET",
    headers: { authkey: env.msg91AuthKey },
  });
  if (!res.ok) return false;
  const data = (await res.json()) as { type?: string };
  return data.type === "success";
}
